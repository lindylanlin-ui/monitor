# 文件總覽

這份目錄頁用來快速帶你找到正確的文件。

## 建議閱讀順序

1. [README.md](/home/tuffy/project/monitor/README.md:1)
2. [SETUP-GUIDE.md](/home/tuffy/project/monitor/docs/SETUP-GUIDE.md:1)
3. [CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1)
4. [EXTENDING.md](/home/tuffy/project/monitor/docs/EXTENDING.md:1)
5. [TROUBLESHOOTING.md](/home/tuffy/project/monitor/docs/TROUBLESHOOTING.md:1)
6. [DASHBOARDS.md](/home/tuffy/project/monitor/docs/DASHBOARDS.md:1)

## 文件用途

- [SETUP-GUIDE.md](/home/tuffy/project/monitor/docs/SETUP-GUIDE.md:1)
  - 第一次部署、接入設備、啟動與驗證流程

- [CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1)
  - 設定檔欄位說明、Prometheus / Grafana Alerting / SNMP 設定查表

- [EXTENDING.md](/home/tuffy/project/monitor/docs/EXTENDING.md:1)
  - 新增監控指標、面板、告警與 PromQL / alert 設計範例

- [TROUBLESHOOTING.md](/home/tuffy/project/monitor/docs/TROUBLESHOOTING.md:1)
  - `No data`、target down、SNMP、Telegram 告警等查修流程

- [DASHBOARDS.md](/home/tuffy/project/monitor/docs/DASHBOARDS.md:1)
  - 各 dashboard 的用途、面板重點與判讀方式

## 功能與檔案速查

- Linux 主機監控
  - 先看 `prometheus/prometheus.yml`
  - target 清單通常看 `prometheus/file_sd/linux-hosts.local.yml`
  - dashboard 看 `grafana/dashboards/infrastructure-overview.json`
  - 文件看 [SETUP-GUIDE.md](/home/tuffy/project/monitor/docs/SETUP-GUIDE.md:1) 與 [CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1)

- Windows VM 監控
  - 先看 `prometheus/file_sd/windows-hosts.local.yml`
  - Prometheus job 看 `prometheus/prometheus.yml`
  - dashboard 看 `grafana/dashboards/infrastructure-overview.json`
  - 文件看 [SETUP-GUIDE.md](/home/tuffy/project/monitor/docs/SETUP-GUIDE.md:1) 與 [CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1)

- Synology NAS 與 ER-X Router 的 SNMP 監控
  - 裝置清單看 `prometheus/file_sd/snmp-devices.local.yml`
  - SNMP 認證看 `snmp/auths.local.yml`
  - SNMP 模組看 `snmp/modules.yml`
  - dashboard 看 `grafana/dashboards/network-edge-and-nas.json`
  - 文件看 [SETUP-GUIDE.md](/home/tuffy/project/monitor/docs/SETUP-GUIDE.md:1)、[CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1) 與 [DASHBOARDS.md](/home/tuffy/project/monitor/docs/DASHBOARDS.md:1)

- Docker Compose 容器監控
  - 先看 `prometheus/prometheus.yml`
  - dashboard 看 `grafana/dashboards/docker-compose-overview.json`
  - 文件看 [CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1)

- HTTP / TCP 服務可用性探測
  - HTTP target 看 `prometheus/file_sd/probe-http.local.yml`
  - TCP target 看 `prometheus/file_sd/probe-tcp.local.yml`
  - Prometheus job 看 `prometheus/prometheus.yml`
  - dashboard 看 `grafana/dashboards/infrastructure-overview.json`
  - 文件看 [SETUP-GUIDE.md](/home/tuffy/project/monitor/docs/SETUP-GUIDE.md:1) 與 [CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1)

- Grafana dashboard 自動匯入
  - provisioning 設定看 `grafana/provisioning/dashboards/dashboards.yml`
  - 掛載路徑看 `docker-compose.yml`
  - 實際 dashboard 檔案看 `grafana/dashboards/*.json`
  - 文件看 [DASHBOARDS.md](/home/tuffy/project/monitor/docs/DASHBOARDS.md:1)

- Grafana Alerting + Telegram 通知
  - 告警規則看 `grafana/provisioning/alerting/rules.yml`
  - 通知模板看 `grafana/provisioning/alerting/templates.yml`
  - provisioning 設定看 `grafana/provisioning/alerting/`
  - Telegram secrets 看 `secrets/grafana-alerting/`
  - 文件看 [EXTENDING.md](/home/tuffy/project/monitor/docs/EXTENDING.md:1)、[CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1) 與 [TROUBLESHOOTING.md](/home/tuffy/project/monitor/docs/TROUBLESHOOTING.md:1)

## 依情境找文件

- 我想第一次部署或把新主機接進來
  - 先看 [SETUP-GUIDE.md](/home/tuffy/project/monitor/docs/SETUP-GUIDE.md:1)
  - 再對照 `prometheus/file_sd/*.local.yml`、`snmp/auths.local.yml`、`.env`

- 我想知道某個監控功能到底改哪個檔案
  - 先看這份文件上面的「功能與檔案速查」
  - 再看 [CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1)

- 我想新增一個 dashboard 或調整現有面板
  - 先看 `grafana/dashboards/*.json`
  - 再看 [DASHBOARDS.md](/home/tuffy/project/monitor/docs/DASHBOARDS.md:1)
  - 如果涉及自動匯入，再看 `grafana/provisioning/dashboards/dashboards.yml`

- 我想新增監控指標、PromQL 或告警規則
  - 先看 [EXTENDING.md](/home/tuffy/project/monitor/docs/EXTENDING.md:1)
  - 再看 `prometheus/prometheus.yml` 與 `grafana/provisioning/alerting/rules.yml`

- 我想調整 Telegram 告警訊息內容
  - 先看 `grafana/provisioning/alerting/templates.yml`
  - 再看 [CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1)

- 我看到 `No data`、target down 或告警行為怪怪的
  - 先看 [TROUBLESHOOTING.md](/home/tuffy/project/monitor/docs/TROUBLESHOOTING.md:1)
  - 再檢查 `prometheus/prometheus.yml`、`prometheus/file_sd/*.local.yml`、`grafana/provisioning/alerting/rules.yml`

- 我想看懂某張圖表代表什麼
  - 先看 [DASHBOARDS.md](/home/tuffy/project/monitor/docs/DASHBOARDS.md:1)
  - 再對照對應的 `grafana/dashboards/*.json`

## 常見需求快速對照

- 想部署整套平台
  - 看 [SETUP-GUIDE.md](/home/tuffy/project/monitor/docs/SETUP-GUIDE.md:1)

- 想知道某個設定欄位是做什麼
  - 看 [CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1)

- 想新增指標、面板或告警
  - 看 [EXTENDING.md](/home/tuffy/project/monitor/docs/EXTENDING.md:1)

- Grafana 顯示 `No data` 或告警沒送出
  - 看 [TROUBLESHOOTING.md](/home/tuffy/project/monitor/docs/TROUBLESHOOTING.md:1)

- 看不懂 dashboard 的圖表內容
  - 看 [DASHBOARDS.md](/home/tuffy/project/monitor/docs/DASHBOARDS.md:1)
