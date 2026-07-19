# 網站服務監控維護指南

本文件說明如何維護「網站服務監控」：新增公開網站服務、調整既有面板、建立新面板、調整告警，以及驗證與套用變更。這個 dashboard 會顯示 service 名稱，只供內部使用，**不要建立公開分享連結**。

## 架構與責任範圍

| 用途 | 來源檔 |
| --- | --- |
| 站點專屬 URL 與 service label | `prometheus/file_sd/http-services.local.yml`（被 Git 忽略） |
| 可分享的 target 範本 | `prometheus/file_sd/http-services.local.example.yml` |
| HTTP probe job 與 local target 載入 | `prometheus/prometheus.yml` |
| Blackbox HTTP 探測模組 | `prometheus/blackbox.yml` 的 `http_2xx` |
| Grafana dashboard 來源 | `grafana/dashboards/website-service-overview.json` |
| 告警規則 | `grafana/provisioning/alerting/rules.yml` |
| 告警調整細節 | [ALERTS.md](./ALERTS.md) |

Blackbox Exporter 每 30 秒以 HTTP `GET` 探測 target。`http_2xx` 模組以 HTTP 成功回應為基本健康條件；主要指標如下：

- `probe_success`：`1` 代表探測成功，`0` 代表失敗。
- `probe_http_status_code`：最近一次 HTTP 狀態碼。
- `probe_duration_seconds`：完整探測耗時。
- `probe_ssl_earliest_cert_expiry`：最早到期的 TLS 憑證時間；僅 HTTPS target 有資料。

所有網站服務都必須使用 `role: public-web`。Dashboard、慢回應與 TLS 告警皆以此 label 篩選。

## 新增網站服務

1. 編輯本機檔案 `prometheus/file_sd/http-services.local.yml`。實際 URL 不要放進可提交的 `http-services.yml`。
2. 新增一筆 target，`service` 使用唯一、穩定的小寫 kebab-case 名稱：

   ```yaml
   - targets: ["https://www.example.com/path/"]
     labels:
       service: example-feature
       role: public-web
   ```

3. 確保檔案可被 Prometheus 容器讀取，再重新載入設定：

   ```bash
   chmod 0644 prometheus/file_sd/http-services.local.yml
   curl -fsS -X POST http://127.0.0.1:9090/-/reload
   ```

4. 等待最多一個 `30s` scrape interval，確認 target 與指標：

   ```bash
   curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
     --data-urlencode 'query=probe_success{job="blackbox-http",role="public-web",instance="example-feature"}' | jq
   ```

5. 重新整理 Grafana 的「網站服務監控」。服務下拉選單會自動出現新 service，現有面板與既有 `ServiceProbeFailed` 告警也會自動納入。

若 target 回傳成功狀態碼但內容錯誤，才需要新增專用 Blackbox module 的內容比對條件。不要直接改動共用的 `http_2xx` 模組，避免影響其他 HTTP probe；先確認可長期維持的頁面識別字串，再新增 module、對應 job 與文件。

## 調整既有面板

Dashboard 的固定 UID 是 `website-service-overview`，datasource UID 是 `prometheus`。保留兩者，並保留未涉及的 panel ID，避免 Grafana 連結與告警引用失效。

| Panel ID | 面板 | 主要指標 |
| --- | --- | --- |
| 1–4 | 服務數、目前狀態與 24 小時可用性摘要 | `probe_success` |
| 5 | 服務目前狀態 | `probe_success` |
| 6 | 目前 HTTP 狀態碼 | `probe_http_status_code` |
| 7 | 服務可用性趨勢 | `avg_over_time(probe_success[5m])` |
| 8 | 服務回應時間 | `probe_duration_seconds` |
| 9 | 服務回應狀態時間線 | `probe_success`；`1` 顯示為「正常」、`0` 顯示為「異常」。 |
| 10 | TLS 憑證到期清單 | `probe_ssl_earliest_cert_expiry`；顯示剩餘天數與到期日期。 |
| 11 | 最快到期憑證 | 所有顯示 HTTPS 服務的最小剩餘天數。 |
| 12 | 21 天內到期服務 | 剩餘少於 21 天的 HTTPS 服務數。 |

要調整既有面板：

1. 修改 `grafana/dashboards/website-service-overview.json`。
2. 對個別服務面板保留下列 label 條件與篩選變數，避免混入一般 HTTP probe：

   ```promql
   {job="blackbox-http", role="public-web", instance=~"$service"}
   ```

3. 變更面板行為時，同步更新 [DASHBOARDS.md](./DASHBOARDS.md) 與本文件的面板表。

## 建立新面板

1. 先選擇適合的面板型態：
   - `stat`：單一最新摘要，例如正常服務數。
   - `bargauge`：各 service 的即時比較，例如狀態碼或憑證剩餘天數。
   - `timeseries`：可用性或回應時間趨勢。
   - `state-timeline`：正常／異常區間。
2. 從相近的既有 panel 複製 JSON，指定尚未使用的 `id` 與不重疊的 `gridPos`。
3. datasource 固定為 `prometheus`，查詢必須加上 `job="blackbox-http", role="public-web"`；要支援篩選時加入 `instance=~"$service"`。
4. 為面板設定正確 unit，例如回應時間使用 `ms`、可用性使用 `percent`；TLS 剩餘日數使用自訂後綴 `suffix: days`，確保畫面直接顯示 `days`。
5. 若新面板會被告警規則引用，先保留 panel ID，之後才在 `rules.yml` 填入對應的 `dashboardUid` 與 `panelId`。

## 調整或新增告警

目前公開網站的專用規則為：

- `public_web_slow_response`：回應時間超過 2 秒持續 5 分鐘。
- `public_web_tls_certificate_expiring`：TLS 憑證剩餘少於 21 天持續 1 小時。

既有 `service_probe_failed` 也會監控所有 HTTP/TCP probe，包含 `public-web` 服務。若要建立更嚴格的網站專屬可用性告警，請新增規則而非修改既有通用規則。

調整規則時保留 UID，並同步調整中文 `title`、`annotations`、`params`、`for` 與對應 panel。完整規則欄位與套用方式請看 [ALERTS.md](./ALERTS.md)。

## 驗證與套用

```bash
# Dashboard JSON
jq empty grafana/dashboards/website-service-overview.json

# Prometheus 與 alerting YAML
yq eval '.' prometheus/prometheus.yml >/dev/null
yq eval '.' grafana/provisioning/alerting/rules.yml >/dev/null

# 避免 dashboard 內容與設定檔格式問題
git diff --check
```

Dashboard JSON 必須可被 Grafana 容器讀取；建議權限為 `0644`。`docker-compose.yml` 中必須先掛載 `./grafana/data:/var/lib/grafana`，再掛載 `./grafana/dashboards:/var/lib/grafana/dashboards:ro`，否則父目錄會覆蓋 dashboard 掛載。

套用 dashboard 或 Grafana Alerting 變更時，僅重建 Grafana：

```bash
docker compose up -d --force-recreate grafana
```

套用 target 或 Prometheus 設定變更時，優先使用 Prometheus reload；只有無法 reload 的 Compose／服務變更才重建 Prometheus。

## 常見問題

- Grafana 顯示 `No data`：確認 `http-services.local.yml` 權限為 `0644`、Prometheus target 已 `UP`，並查詢 `probe_success{job="blackbox-http",role="public-web"}`。
- 新 dashboard 沒出現：確認 JSON、檔案權限與 Compose 掛載順序，再重建 Grafana。
- 新服務沒有出現在下拉選單：確認 label 是 `role: public-web`，並等待下一次 scrape。
- HTTPS 憑證面板沒有資料：確認 target 使用 HTTPS，且 Blackbox probe 成功完成 TLS 交握。

更完整的故障排除步驟請看 [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)。
