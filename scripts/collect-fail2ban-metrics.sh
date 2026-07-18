#!/bin/sh
# 將 Fail2ban、SSH 與 Nginx /file/ 登入失敗資料轉成 Prometheus textfile metrics。
# 預期由 systemd 以 root 執行；不會輸出或保存 IP、帳密與日誌原文。

set -eu

FAIL2BAN_CLIENT=${FAIL2BAN_CLIENT:-fail2ban-client}
LOOKBACK_DAYS=${LOOKBACK_DAYS:-7}
NGINX_LOG_DIR=${NGINX_LOG_DIR:-/var/log/nginx}
NGINX_LOG_BASENAME=${NGINX_LOG_BASENAME:-nginx.log}
FAIL2BAN_METRICS_FILE=${FAIL2BAN_METRICS_FILE:-/var/lib/node_exporter/textfile_collector/fail2ban.prom}

case "$LOOKBACK_DAYS" in
    ''|*[!0-9]*|0)
        echo "LOOKBACK_DAYS 必須是正整數。" >&2
        exit 1
        ;;
esac

if ! command -v "$FAIL2BAN_CLIENT" >/dev/null 2>&1; then
    echo "找不到 fail2ban-client。" >&2
    exit 1
fi

if ! overall_status=$("$FAIL2BAN_CLIENT" status); then
    echo "無法讀取 Fail2ban 狀態；請確認服務正在執行。" >&2
    exit 1
fi

jails=$(printf '%s\n' "$overall_status" \
    | sed -n 's/^[[:space:]]*`- Jail list:[[:space:]]*//p' \
    | tr ',' '\n' \
    | sed '/^[[:space:]]*$/d; s/^[[:space:]]*//; s/[[:space:]]*$//')

metrics_dir=$(dirname -- "$FAIL2BAN_METRICS_FILE")
mkdir -p -- "$metrics_dir"
temporary_file=$(mktemp "$metrics_dir/.fail2ban.prom.XXXXXX")
trap 'rm -f -- "$temporary_file"' EXIT HUP INT TERM

metric_value() {
    # Fail2ban 正常會輸出整數；非整數時保守以 0 輸出，維持 exposition 格式有效。
    case "$1" in
        ''|*[!0-9]*) printf '%s\n' 0 ;;
        *) printf '%s\n' "$1" ;;
    esac
}

metric_label() {
    # jail 名稱通常是簡單識別字，但仍轉義 Prometheus label 必要字元。
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

nginx_logs() {
    for log_file in "$NGINX_LOG_DIR"/"$NGINX_LOG_BASENAME"*; do
        [ -f "$log_file" ] || continue
        case "$log_file" in
            *.gz) gzip -cd -- "$log_file" ;;
            *) cat -- "$log_file" ;;
        esac
    done
}

ssh_events() {
    journalctl SYSLOG_IDENTIFIER=sshd \
        --since "$LOOKBACK_DAYS days ago" --no-pager
}

password_attempts=$(ssh_events \
    | awk '/Failed password|authentication failure/ { count++ } END { print count + 0 }')
invalid_user_attempts=$(ssh_events \
    | awk '/Invalid user .* from [0-9A-Fa-f:.]+ port / { count++ } END { print count + 0 }')
file_login_failures=$(nginx_logs \
    | awk '/"POST \/file\/__login(\?[^ ]*)? HTTP\/[0-9.]+" 401/ { count++ } END { print count + 0 }')
file_login_sources=$(nginx_logs \
    | awk '/"POST \/file\/__login(\?[^ ]*)? HTTP\/[0-9.]+" 401/ { print $1 }' \
    | sort -u \
    | awk 'END { print NR + 0 }')

{
    echo '# HELP fail2ban_jail_current_failed 目前仍在 Fail2ban 視窗內的失敗次數。'
    echo '# TYPE fail2ban_jail_current_failed gauge'
    echo '# HELP fail2ban_jail_failures_total Fail2ban 啟動後累計失敗次數；服務重啟時會歸零。'
    echo '# TYPE fail2ban_jail_failures_total counter'
    echo '# HELP fail2ban_jail_current_banned 目前有效封鎖的 IP 數量。'
    echo '# TYPE fail2ban_jail_current_banned gauge'
    echo '# HELP fail2ban_jail_bans_total Fail2ban 啟動後累計封鎖次數；服務重啟時會歸零。'
    echo '# TYPE fail2ban_jail_bans_total counter'

    if [ -n "$jails" ]; then
        while IFS= read -r jail; do
            jail_status=$("$FAIL2BAN_CLIENT" status "$jail")
            jail_label=$(metric_label "$jail")
            current_failed=$(printf '%s\n' "$jail_status" | sed -n 's/.*Currently failed:[[:space:]]*//p')
            total_failed=$(printf '%s\n' "$jail_status" | sed -n 's/.*Total failed:[[:space:]]*//p')
            current_banned=$(printf '%s\n' "$jail_status" | sed -n 's/.*Currently banned:[[:space:]]*//p')
            total_banned=$(printf '%s\n' "$jail_status" | sed -n 's/.*Total banned:[[:space:]]*//p')

            printf 'fail2ban_jail_current_failed{jail="%s"} %s\n' "$jail_label" "$(metric_value "$current_failed")"
            printf 'fail2ban_jail_failures_total{jail="%s"} %s\n' "$jail_label" "$(metric_value "$total_failed")"
            printf 'fail2ban_jail_current_banned{jail="%s"} %s\n' "$jail_label" "$(metric_value "$current_banned")"
            printf 'fail2ban_jail_bans_total{jail="%s"} %s\n' "$jail_label" "$(metric_value "$total_banned")"
        done <<EOF
$jails
EOF
    fi

    echo '# HELP fail2ban_ssh_password_failures 最近設定天數內的 SSH 密碼驗證失敗數。'
    echo '# TYPE fail2ban_ssh_password_failures gauge'
    printf 'fail2ban_ssh_password_failures{window_days="%s"} %s\n' \
        "$LOOKBACK_DAYS" "$(metric_value "$password_attempts")"
    echo '# HELP fail2ban_ssh_invalid_user_attempts 最近設定天數內的 SSH 不存在帳號嘗試數。'
    echo '# TYPE fail2ban_ssh_invalid_user_attempts gauge'
    printf 'fail2ban_ssh_invalid_user_attempts{window_days="%s"} %s\n' \
        "$LOOKBACK_DAYS" "$(metric_value "$invalid_user_attempts")"
    echo '# HELP fail2ban_file_login_failures_retained_nginx_logs 保留 Nginx 日誌中的 /file/ 登入失敗數。'
    echo '# TYPE fail2ban_file_login_failures_retained_nginx_logs gauge'
    printf 'fail2ban_file_login_failures_retained_nginx_logs %s\n' "$(metric_value "$file_login_failures")"
    echo '# HELP fail2ban_file_login_failure_sources_retained_nginx_logs 保留 Nginx 日誌中 /file/ 登入失敗的不重複來源數。'
    echo '# TYPE fail2ban_file_login_failure_sources_retained_nginx_logs gauge'
    printf 'fail2ban_file_login_failure_sources_retained_nginx_logs %s\n' "$(metric_value "$file_login_sources")"
    echo '# HELP fail2ban_metrics_last_success_unixtime 此 collector 最近成功完成的 Unix 時間。'
    echo '# TYPE fail2ban_metrics_last_success_unixtime gauge'
    printf 'fail2ban_metrics_last_success_unixtime %s\n' "$(date +%s)"
} >"$temporary_file"

chmod 0644 "$temporary_file"
mv -f -- "$temporary_file" "$FAIL2BAN_METRICS_FILE"
trap - EXIT HUP INT TERM
