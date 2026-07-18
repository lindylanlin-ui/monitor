# Fail2ban 安全監控維護指南

本文件說明如何把 Fail2ban、SSH 與 Nginx `/file/` 登入失敗資料匯入 Prometheus，並由 Grafana 的 `fail2ban-security-overview` dashboard 顯示。這是內部維運用途，請勿建立公開分享連結。

## 架構與設計範圍

```text
systemd timer（root，每分鐘）
  -> collect-fail2ban-metrics.sh
  -> node-exporter/textfile/fail2ban.prom
  -> node_exporter textfile collector
  -> Prometheus（node-exporter job）
  -> Grafana「Fail2ban 安全監控」
```

collector 會提供下列資料：

- 每個 Fail2ban jail 的目前失敗、累計失敗、目前封鎖與累計封鎖數。
- 最近 `LOOKBACK_DAYS` 天的 SSH 密碼驗證失敗與不存在帳號嘗試數。
- 目前仍保留的 Nginx log 中 `/file/__login` HTTP 401 總數與不重複來源數。
- collector 最近一次完整成功的時間。

不會把攻擊來源 IP 轉成 Prometheus label 或寫入 dashboard。IP 會快速變動，長期保存會造成 time series/cardinality 累積，且增加內部資訊外洩風險。需要追查 IP 時，仍使用原有 `list-fail2ban-banned-ips.sh` 或查原始日誌。

## Repository 內的檔案責任

| 檔案 | 用途 |
| --- | --- |
| `scripts/collect-fail2ban-metrics.sh` | 主機端 collector；內容完整後才更新 `.prom` 檔，失敗時保留上次成功結果。 |
| `systemd/fail2ban-metrics-collector.service` | 以 root 執行 collector 的 service 範本。 |
| `systemd/fail2ban-metrics-collector.timer` | 每分鐘觸發 service 的 timer 範本。 |
| `node-exporter/textfile/` | 主機端 metrics 輸出目錄；`*.prom` 被 Git 忽略。 |
| `docker-compose.yml` | 對 node_exporter 啟用並唯讀掛載 textfile collector 目錄。 |
| `grafana/dashboards/fail2ban-security-overview.json` | Grafana provisioning 的 dashboard 來源。 |

## 第一次部署

以下步驟假設 Fail2ban、proxy 的 Nginx logs 與此監控 Compose 位於同一台主機。若 proxy 在另一台主機，請看本節最後的「不同主機」說明。

### 1. 建立 Compose 端目錄並套用 node_exporter 設定

```bash
cd /home/tuffy/project/monitor
make bootstrap
make validate
docker compose up -d node-exporter grafana
```

node_exporter 會以唯讀方式讀取 `node-exporter/textfile/`；container 不需要、也不應取得 Fail2ban socket、systemd journal 或 Nginx log 的權限。

### 2. 安裝 collector 與 systemd timer

請依實際路徑調整下列 `/etc/default` 內容。此檔含主機路徑，應留在本機，不要加入版本控制。

```bash
sudo install -m 0755 scripts/collect-fail2ban-metrics.sh /usr/local/sbin/collect-fail2ban-metrics.sh
sudo install -m 0644 systemd/fail2ban-metrics-collector.service /etc/systemd/system/fail2ban-metrics-collector.service
sudo install -m 0644 systemd/fail2ban-metrics-collector.timer /etc/systemd/system/fail2ban-metrics-collector.timer
sudoedit /etc/default/fail2ban-metrics-collector
```

`/etc/default/fail2ban-metrics-collector` 範例：

```sh
# 這些是本機路徑，請依實際部署調整。
FAIL2BAN_METRICS_FILE=/home/tuffy/project/monitor/node-exporter/textfile/fail2ban.prom
NGINX_LOG_DIR=/home/tuffy/project/proxy/logs
NGINX_LOG_BASENAME=nginx.log
LOOKBACK_DAYS=7
```

啟用並立即執行一次：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now fail2ban-metrics-collector.timer
sudo systemctl start fail2ban-metrics-collector.service
sudo systemctl status fail2ban-metrics-collector.service --no-pager
sudo systemctl list-timers fail2ban-metrics-collector.timer
```

### 不同主機時的做法

collector 必須執行在真正持有 Fail2ban、SSH journal 與 Nginx log 的 proxy 主機上。請在該主機啟用 node_exporter textfile collector、讓它讀取本機 `.prom` 檔，接著把該 node_exporter:9100 加到 `prometheus/file_sd/linux-hosts.local.yml`。不要透過 NFS 掛載日誌，也不要把 Fail2ban socket 暴露給 monitoring container。

## 驗證流程

部署或調整後依序確認：

```bash
# 產出必須是合法的 Prometheus exposition 格式，且不應含 IP。
sudo /usr/local/sbin/collect-fail2ban-metrics.sh
sed -n '1,160p' node-exporter/textfile/fail2ban.prom

# 檢查 timer 是否會定期成功執行。
sudo systemctl status fail2ban-metrics-collector.timer --no-pager
sudo journalctl -u fail2ban-metrics-collector.service -n 30 --no-pager

# 驗證 repository 變更。
git diff --check
make validate
jq empty grafana/dashboards/fail2ban-security-overview.json
sh -n scripts/collect-fail2ban-metrics.sh
```

接著到 Prometheus 的 Graph 頁面查詢：

```promql
fail2ban_jail_current_banned
fail2ban_metrics_last_success_unixtime
```

兩者均應有資料後，再開啟 Grafana 的「Fail2ban 安全監控」。Dashboard provider 每 30 秒掃描一次 JSON；若暫時沒有出現，可安全執行：

```bash
docker compose up -d --force-recreate grafana
```

## 現有 dashboard 的面板與 PromQL

| 面板 | 主要查詢 | 用途 |
| --- | --- | --- |
| 目前有效封鎖 IP | `sum(fail2ban_jail_current_banned)` | 快速確認所有 jail 目前仍封鎖多少來源。 |
| 各 jail 目前封鎖數 | `fail2ban_jail_current_banned` | 對照是哪個 jail 受掃描。 |
| 短時間新增封鎖 | `increase(fail2ban_jail_bans_total[$__rate_interval])` | 找出突發攻擊，不以目前封鎖量誤判。 |
| 各 jail 即時與累計計數 | 四個 `fail2ban_jail_*` 指標 | 同時看目前狀態與 Fail2ban 重啟前的累積量。 |
| SSH 與 Nginx 登入失敗趨勢 | `fail2ban_ssh_*`、`fail2ban_file_login_*` | 看登入失敗的變化。 |

`fail2ban_jail_bans_total` 與 `fail2ban_jail_failures_total` 在 Fail2ban 重啟時會重設；這符合 Prometheus counter 的 reset 行為，`increase()` 仍適合分析增量。Nginx 指標只反映目前保留的 log，輪替後降低並非 collector 錯誤。

## 日常維護與查修

1. dashboard 顯示 `No data`：先確認 `fail2ban.prom` 存在，再查 `systemctl status` 與 service journal；最後再查 Prometheus target `node-exporter` 是否 `UP`。
2. `collector 距離上次成功` 持續上升：手動執行 collector，確認 Fail2ban 是否啟動、root 是否可讀 journal 與 Nginx log 路徑是否正確。collector 失敗時會保留舊 `.prom`，避免顯示短暫空白。
3. `/file/` 數值與手動腳本不一致：檢查 `NGINX_LOG_DIR`、`NGINX_LOG_BASENAME` 與 `.gz` 輪替檔案；此數值應以相同保留日誌範圍比較。
4. 修改 `LOOKBACK_DAYS`：更新 `/etc/default/fail2ban-metrics-collector` 後執行 `sudo systemctl restart fail2ban-metrics-collector.timer` 與 `sudo systemctl start fail2ban-metrics-collector.service`。metric 的 `window_days` label 會跟著更新。
5. 不要手改 `node-exporter/textfile/fail2ban.prom`；它是 runtime 產物，下次 timer 執行會覆蓋。

## 新增 Fail2ban 監控區塊

新增內容前，先確認它是適合 Prometheus 的「數值狀態或計數」。例如新 jail 不需要改程式：collector 會從 `fail2ban-client status` 自動列出所有啟用的 jail。若要新增新的日誌類型或總數，依下列流程：

1. 在 `scripts/collect-fail2ban-metrics.sh` 以 `awk` 從可讀取的本機資料計算單一數字。
2. 使用穩定、低基數的 label，例如 `jail`、`service` 或固定觀察期；不要用 IP、帳號、URL、request ID、時間戳作 label。
3. 在輸出區塊補上對應的 `# HELP` 與 `# TYPE`。現在值使用 `gauge`；會自然遞增、重啟時可重設的累計量使用 `_total` 加 `counter`。
4. 用 `sudo /usr/local/sbin/collect-fail2ban-metrics.sh` 產生檔案並確認數值合理，再以 Prometheus 查詢確認已 scrape。
5. 在 dashboard JSON 新增 panel，datasource UID 固定使用 `prometheus`，並在本文件與 `docs/DASHBOARDS.md` 補上用途、PromQL、資料限制。
6. 執行本文件的驗證流程。只有確認有資料與正常基線後，才考慮加告警。

建議的可選告警是「短時間新增封鎖明顯升高」，而不是「目前有 IP 被封鎖」：

```promql
sum by (instance, jail) (increase(fail2ban_jail_bans_total[15m])) > 20
```

先觀察至少一週正常基線，再決定門檻與 `for:`；不同網站的掃描量差異很大。

## 建立全新的 Grafana dashboard

所有 dashboard 都以 JSON 放在 `grafana/dashboards/`，由 provisioning 自動載入 Infrastructure 資料夾。接手人建立全新 dashboard 時，請依序進行：

1. 先定義使用者要回答的問題與已存在的 metric；在 Prometheus Graph 頁面先試出正確 PromQL，不能先從畫面猜 query。
2. 選擇唯一且穩定的 UID，例如 `proxy-security-overview`；新增 `grafana/dashboards/<uid>.json`，title 可用中文但 UID 不應隨意更換。
3. 在 Grafana UI 建立草稿時，資料來源一律選 Prometheus UID `prometheus`。確認 panel 類型：趨勢用 `timeseries`、當前摘要用 `stat`、明細用 `table`。
4. 在 UI 以 **Inspect → Panel JSON** 或 dashboard 的 JSON 匯出功能取得 JSON，整理後寫入 repository。不要把 datasource UID 寫成隨機的 Grafana internal ID。
5. 保留既有 panel 的 `id`；新 dashboard 的 panel ID 從 `1` 起且不重複。加入合理的 dashboard `uid`、`title`、預設時間範圍與僅需要的變數。
6. 執行 `jq empty grafana/dashboards/<uid>.json`、`git diff --check`，然後讓 Grafana provisioning 載入。確認每個 panel 均非 `No data`／`Error`。
7. 在 `docs/DASHBOARDS.md` 新增用途、主要面板、判讀限制與是否能公開分享；再從 `docs/INDEX.md` 或功能文件建立入口。若涉及新的資料蒐集方式，也同步更新 `README.md` 與對應設定文件。

建立 dashboard 後不要只看畫面：請在 Prometheus 逐條驗證同一份 PromQL，並留意 label 基數與公開分享風險。新的 IP、帳號、URL 或 request ID 類 label 在設計階段就應排除。
