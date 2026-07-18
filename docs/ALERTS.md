# Grafana 告警維護指南

Grafana 顯示的告警資料夾為「基礎設施告警」。告警規則的可讀名稱已使用繁體中文；技術 UID 維持英文，供 provisioning 穩定辨識，**不要變更既有 UID**。

告警來源檔為 `grafana/provisioning/alerting/rules.yml`。不要直接修改 `grafana/runtime/` 內的檔案，該目錄是啟動時產生的 runtime 設定。

## 名稱對照

| Grafana 顯示名稱 | UID |
| --- | --- |
| 監控目標離線 | `target_down` |
| 服務探測失敗 | `service_probe_failed` |
| 無線基地台 Ping 失敗 | `access_point_ping_failed` |
| 公開網站回應過慢 | `public_web_slow_response` |
| 公開網站 TLS 憑證即將到期 | `public_web_tls_certificate_expiring` |
| Linux CPU 使用率過高 | `linux_cpu_high` |
| Linux 記憶體使用率過高 | `linux_memory_high` |
| Linux 根目錄磁碟使用率過高 | `linux_root_disk_high` |
| Windows CPU 使用率過高 | `windows_cpu_high` |
| Windows 記憶體使用率過高 | `windows_memory_high` |
| Windows 磁碟使用率過高 | `windows_disk_high` |
| SMART 磁碟健康異常 | `smart_disk_health_failed` |
| SSD 剩餘壽命過低 | `ssd_remaining_life_low` |
| 磁碟溫度過高 | `disk_temperature_high` |
| NVMe 控制器嚴重警告 | `nvme_critical_warning` |
| NVIDIA GPU 溫度過高 | `nvidia_gpu_temperature_high` |
| SNMP CPU 使用率過高 | `snmp_cpu_high` |
| SNMP 記憶體使用率過高 | `snmp_memory_high` |
| NAS 網路流量異常尖峰 | `nas_traffic_spike` |
| 路由器 WAN 流量異常尖峰 | `router_wan_traffic_spike` |
| Synology 磁碟健康異常 | `synology_disk_health_problem` |

## 日後如何調整

每條規則都在 `rules.yml` 的 `groups[].rules[]` 中。通常只需要修改下列欄位：

- `title`：Grafana 與通知顯示的繁體中文名稱。
- `expr`：PromQL 告警條件的資料來源；先在 Prometheus 查詢頁確認有預期結果。
- `params`：門檻值，例如 `85`、`2000` 或 `21`。
- `for`：條件必須持續多久才觸發，例如 `5m`。
- `labels.severity`：告警等級，使用 `warning` 或 `critical`。
- `annotations.summary`／`annotations.description`：Grafana 與 Telegram 的可讀訊息。
- `notification_settings`：接收者與通知分組、重複通知間隔。

變更資料夾名稱時，統一調整各群組的 `folder`；變更群組名稱時，調整 `name`。這些名稱會在 Grafana Alerting 中顯示。

## 安全調整流程

1. 先在 Prometheus 驗證新的 PromQL 與 label。
2. 修改 `grafana/provisioning/alerting/rules.yml`，保留既有 `uid`、`dashboardUid` 與 `panelId`。
3. 執行 YAML 與 diff 檢查：

   ```bash
   yq eval '.' grafana/provisioning/alerting/rules.yml >/dev/null
   git diff --check
   ```

4. 套用 provisioning 時只重建 Grafana：

   ```bash
   docker compose up -d --force-recreate grafana
   ```

5. 在 Grafana 的「基礎設施告警」確認規則、門檻、資料來源與 Telegram 訊息。

不要只為驗證而執行 `docker compose down` 或刪除 Grafana／Prometheus data。
