#!/bin/sh
set -eu

# 依序讀取 secrets，優先使用新的 Grafana Alerting 路徑，
# 若尚未搬移，則相容舊的 Alertmanager 路徑。
read_secret() {
  for path in "$@"; do
    if [ -f "$path" ]; then
      tr -d '\r\n' < "$path"
      return 0
    fi
  done
  return 1
}

is_placeholder_secret() {
  case "$1" in
    ""|replace-me|replace-me-* )
      return 0
      ;;
    * )
      return 1
      ;;
  esac
}

pick_secret() {
  for path in "$@"; do
    if [ -f "$path" ]; then
      value="$(tr -d '\r\n' < "$path")"
      if ! is_placeholder_secret "$value"; then
        printf '%s' "$value"
        return 0
      fi
    fi
  done
  return 1
}

BOT_TOKEN="${GRAFANA_TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${GRAFANA_TELEGRAM_CHAT_ID:-}"
PROVISIONING_SRC="/etc/grafana/provisioning-src"
PROVISIONING_DST="/etc/grafana/provisioning"
CONTACT_TEMPLATE="/etc/grafana/templates/contact-points.yml.tpl"

if [ -z "$BOT_TOKEN" ]; then
  BOT_TOKEN="$(pick_secret \
    /etc/grafana/secrets/grafana-alerting/telegram_bot_token \
    /etc/grafana/secrets/alertmanager/telegram_bot_token || true)"
elif is_placeholder_secret "$BOT_TOKEN"; then
  BOT_TOKEN="$(pick_secret \
    /etc/grafana/secrets/grafana-alerting/telegram_bot_token \
    /etc/grafana/secrets/alertmanager/telegram_bot_token || true)"
fi

if [ -z "$CHAT_ID" ]; then
  CHAT_ID="$(pick_secret \
    /etc/grafana/secrets/grafana-alerting/telegram_chat_id \
    /etc/grafana/secrets/alertmanager/telegram_chat_id || true)"
elif is_placeholder_secret "$CHAT_ID"; then
  CHAT_ID="$(pick_secret \
    /etc/grafana/secrets/grafana-alerting/telegram_chat_id \
    /etc/grafana/secrets/alertmanager/telegram_chat_id || true)"
fi

if [ -z "$BOT_TOKEN" ]; then
  echo "start-grafana-with-secrets.sh: Telegram bot token not found; please set secrets/grafana-alerting/telegram_bot_token." >&2
  exit 1
fi

if [ -z "$CHAT_ID" ]; then
  echo "start-grafana-with-secrets.sh: Telegram chat id not found; please set secrets/grafana-alerting/telegram_chat_id." >&2
  exit 1
fi

# 以 Git 追蹤的 provisioning 模板為基底，建立 Grafana 啟動時真正讀取的 runtime 設定目錄。
mkdir -p "$PROVISIONING_DST"
find "$PROVISIONING_DST" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -R "$PROVISIONING_SRC"/. "$PROVISIONING_DST"/
mkdir -p "$PROVISIONING_DST/alerting" "$PROVISIONING_DST/plugins"

# 用模板檔產生最終 Telegram contact point，確保 chat_id 以字串形式寫入 YAML。
BOT_TOKEN_ESCAPED="$(printf '%s' "$BOT_TOKEN" | sed 's/[&|\\]/\\&/g')"
CHAT_ID_ESCAPED="$(printf '%s' "$CHAT_ID" | sed 's/[&|\\]/\\&/g')"
sed \
  -e "s|__GRAFANA_TELEGRAM_BOT_TOKEN__|$BOT_TOKEN_ESCAPED|g" \
  -e "s|__GRAFANA_TELEGRAM_CHAT_ID__|$CHAT_ID_ESCAPED|g" \
  "$CONTACT_TEMPLATE" > "$PROVISIONING_DST/alerting/contact-points.yml"

exec /run.sh
