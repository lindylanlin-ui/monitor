# Docker Compose 監控平台

這個 repo 提供一套可攜式的 `Prometheus + Grafana` 監控環境，目標是讓你用同一份 `docker compose` 設定，在不同主機上快速建立一致的監控平台，同時把敏感資料留在本機、不進 Git。

目前涵蓋：

- Linux 主機監控
- Windows VM 監控
- Synology NAS 與 ER-X Router 的 SNMP 監控
- Docker Compose 容器監控
- HTTP / TCP / ICMP 服務與裝置可用性探測
- Grafana dashboard 自動匯入
- Grafana Alerting + Telegram 通知

目前正式告警流程：

- `Prometheus` 負責抓 metrics
- `Grafana Alerting` 負責告警規則與 Telegram 通知

**文件導覽**
- [文件總覽](./docs/INDEX.md)
  - 從功能或使用情境快速找到該看的檔案與文件
- [詳細建置指南](./docs/SETUP-GUIDE.md)
  - 第一次部署、接入主機與啟動流程
- [設定參考手冊](./docs/CONFIG-REFERENCE.md)
  - 設定檔欄位與監控架構說明
- [擴充與告警設計指南](./docs/EXTENDING.md)
  - 新增指標、面板、PromQL 與告警規則
- [查修手冊](./docs/TROUBLESHOOTING.md)
  - `No data`、target down、Telegram 告警異常查修
- [Grafana Dashboard 說明](./docs/DASHBOARDS.md)
  - 各 dashboard 與面板用途

**快速開始**
1. 建立本機設定檔與資料夾：

```bash
make bootstrap
```

2. 至少調整這些檔案：

- `.env`
- `snmp/auths.local.yml`
- `prometheus/file_sd/windows-hosts.local.yml`
- `prometheus/file_sd/snmp-devices.local.yml`
- `prometheus/file_sd/icmp-services.local.yml`
- `secrets/grafana-alerting/telegram_bot_token`
- `secrets/grafana-alerting/telegram_chat_id`

3. 驗證 compose 設定：

```bash
make validate
```

4. 啟動整套平台：

```bash
make up
```

5. 確認服務狀態：

```bash
make ps
```

**啟動後先看哪裡**
- Prometheus：`http://localhost:9090/targets`
- Grafana：`http://localhost:3000`
- Grafana Alerting：`http://localhost:3000/alerting/list`
- Notification policies：`http://localhost:3000/alerting/notifications`

**你可能先想看這些**
- 想知道某個功能要改哪個檔案：
  - 看 [文件總覽](./docs/INDEX.md)
- 想新增 Linux / Windows / SNMP / HTTP / TCP / ICMP target：
  - 看 [詳細建置指南](./docs/SETUP-GUIDE.md)
- 想新增 dashboard 或調整圖表：
  - 看 [Grafana Dashboard 說明](./docs/DASHBOARDS.md)
- 想新增 PromQL、監控指標或告警規則：
  - 看 [擴充與告警設計指南](./docs/EXTENDING.md)
- 想查某個設定欄位代表什麼：
  - 看 [設定參考手冊](./docs/CONFIG-REFERENCE.md)
- 遇到 `No data`、target down 或 Telegram 沒送：
  - 看 [查修手冊](./docs/TROUBLESHOOTING.md)

**常用指令**

```bash
make bootstrap
make validate
make up
make down
make ps
make logs
docker compose up -d --force-recreate grafana
docker compose up -d prometheus
```

**主要 dashboard**
- `infrastructure-overview`
  - Linux / Windows / probe / 基礎設施總覽
- `docker-compose-overview`
  - 容器 CPU / RAM / Network / uptime
- `network-edge-and-nas`
  - NAS / Router 的 SNMP 指標、容量、磁碟健康、流量尖峰觀察

**目前已提供的告警類型**
- `TargetDown`
- `ServiceProbeFailed`
- `AccessPointPingFailed`
- `LinuxCpuHigh`
- `LinuxMemoryHigh`
- `LinuxRootDiskHigh`
- `WindowsCpuHigh`
- `WindowsMemoryHigh`
- `WindowsDiskHigh`
- `SnmpCpuHigh`
- `SnmpMemoryHigh`
- `NAS 網路流量異常尖峰`
- `Router WAN 流量異常尖峰`
- `Synology 磁碟健康異常`

告警細節與門檻請直接看 [設定參考手冊](./docs/CONFIG-REFERENCE.md) 與 [Grafana Alerting 規則檔](./grafana/provisioning/alerting/rules.yml)。

**安全原則**
- 真實帳密只放本機 `.env` 與 `snmp/auths.local.yml`
- 真實 target 只放本機 `prometheus/file_sd/*.local.yml`
- Telegram token / chat id 只放本機 `secrets/grafana-alerting/`
- Grafana runtime provisioning 只放本機 `grafana/runtime/`
- 執行資料只放本機 `prometheus/data`、`grafana/data`、`grafana/runtime`、`snmp/generated`
