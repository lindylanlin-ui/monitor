# Docker Compose 監控平台操作手冊

這個專案會在單一 `docker compose` 內建立一套可攜式監控平台，核心目標是讓你可以在不同主機上快速部署同一套 Prometheus + Grafana 監控環境，同時避免把敏感資訊推上 GitHub。

這套平台目前涵蓋：

- Zorin Linux 實體主機監控
- VMware Workstation Pro 內的 Windows 10 VM 監控
- Synology NAS 的 SNMP 監控
- ER-X Router 的 SNMP 監控
- 多個 Docker Compose 專案的容器監控
- HTTP / TCP 服務可用性探測
- Grafana dashboard 自動匯入
- Prometheus 告警規則
- Alertmanager 告警路由骨架

如果你之後回頭看設定時忘記某個欄位是做什麼用，除了本 README，也可以直接查：

- [設定參考手冊](./docs/CONFIG-REFERENCE.md)
- [Grafana Dashboard 說明](./grafana/dashboards/README.md)

## 1. 架構與用途

本專案內每個元件的用途如下：

- `Prometheus`
  - 定期抓取各 exporter 與設備指標
  - 保存時間序列資料
  - 執行告警規則
- `Grafana`
  - 顯示 dashboard
  - 讓你用圖表觀察趨勢、異常與容量變化
- `Alertmanager`
  - 接收 Prometheus 告警
  - 依條件分組、靜默、轉送通知
- `node-exporter`
  - 監控 Linux 主機 CPU、RAM、Disk、Network、filesystem、systemd
- `cAdvisor`
  - 監控 Docker 容器 CPU、RAM、Network、啟動時間
- `blackbox-exporter`
  - 監控 HTTP / HTTPS / TCP 服務是否可用
- `snmp-exporter`
  - 監控 NAS、Router、交換器等不方便安裝 exporter 的設備

## 2. 專案目錄與設定檔用途

- `docker-compose.yml`
  - 監控平台主堆疊
  - 定義所有服務、port、volume、network 與啟動方式
- `.env.example`
  - 環境變數範本
  - 控制版本、port、Grafana 帳密、Prometheus 保留天數
- `prometheus/prometheus.yml`
  - Prometheus 主設定
  - 決定抓哪些 job、告警送去哪裡
- `prometheus/rules/infrastructure-alerts.yml`
  - 告警規則
  - 監控 CPU、記憶體、磁碟、服務可用性
- `prometheus/file_sd/*.yml`
  - 可擴充的 target 清單
  - 未來新增設備時主要改這裡
- `prometheus/blackbox.yml`
  - Blackbox probe 模組設定
- `alertmanager/alertmanager.yml`
  - 告警路由與 receiver 骨架
- `snmp/auths.example.yml`
  - SNMP 驗證模板
  - 正式用法是複製成 `snmp/auths.local.yml`
- `snmp/modules.yml`
  - 本專案實際會用到的 SNMP 模組集合
- `grafana/provisioning/*`
  - Grafana 自動匯入資料來源與 dashboard 的設定
- `grafana/dashboards/*.json`
  - 實際 Grafana dashboard 定義
- `docs/CONFIG-REFERENCE.md`
  - 設定欄位與維護邏輯查表手冊
- `prometheus/data`、`alertmanager/data`、`grafana/data`、`snmp/generated`
  - 實際執行時的資料目錄，保留在專案內但不進 Git

## 3. 部署前你要準備什麼

### 3.1 監控主機需求

建議你在要執行這套監控平台的主機上先準備：

- Docker Engine
- Docker Compose Plugin
- 至少 2 CPU / 4 GB RAM
- 足夠的磁碟空間保存 Prometheus 資料

建議先確認：

```bash
docker --version
docker compose version
```

### 3.2 網路需求

Prometheus 主機需要能連到：

- Windows VM 的 `9182/tcp`
- SNMP 設備的 `161/udp`
- 你要做 HTTP probe 的 URL
- 你要做 TCP probe 的連接埠

### 3.3 安全原則

這個專案刻意把敏感資訊留在本機，不放進 Git：

- `.env`
- `snmp/auths.local.yml`
- 任何本機私密 `*.local.yml`
- `需求說明.txt`

## 4. 第一次建置與設定的完整步驟

### 步驟 1：建立本機設定檔

在專案根目錄執行：

```bash
make bootstrap
```

這個動作會建立：

- `.env`
- `snmp/auths.local.yml`
- `prometheus/file_sd/windows-hosts.local.yml`
- `prometheus/file_sd/snmp-devices.local.yml`
- `prometheus/data`
- `alertmanager/data`
- `grafana/data`
- `snmp/generated`
- `secrets/alertmanager/telegram_bot_token`
- `secrets/alertmanager/telegram_chat_id`

### 步驟 1-1：資料目錄現在會放在專案內

本專案目前使用 bind mount，把執行資料直接存到專案目錄：

- `prometheus/data`
- `alertmanager/data`
- `grafana/data`
- `snmp/generated`

這些資料夾會保留容器執行資料，但已加入 `.gitignore`，不會被推上 GitHub。

如果你之前已經用過舊版 named volume，注意：

- 舊資料不會自動搬到這些新資料夾
- 這次改動後若要延續舊資料，需自行從原本 Docker volume 匯出或複製

### 步驟 2：設定 Grafana 與 Prometheus 基本參數

打開 `.env`，至少調整以下內容：

- `GRAFANA_ADMIN_PASSWORD`
  - Grafana 管理員密碼
- `PROMETHEUS_EXTERNAL_URL`
  - 如果有反向代理或固定網域，改成實際網址
- `GRAFANA_ROOT_URL`
  - 如果有反向代理或固定網域，改成實際網址
- `PROMETHEUS_RETENTION`
  - 歷史資料保留時間，例如 `30d`、`90d`

如果主機已有 port 衝突，也可以改：

- `PROMETHEUS_PORT`
- `ALERTMANAGER_PORT`
- `GRAFANA_PORT`

注意：

- `CADVISOR_VERSION` 在目前官方映像來源使用 `ghcr.io/google/cadvisor`
- 該映像 tag 不使用 `v` 前綴，因此應類似 `0.57.0`，不要寫成 `v0.57.0`
- `DOCKER_ROOT_DIR` 要指向主機上 Docker 的真實資料目錄
  - 一般 apt 安裝常見：`/var/lib/docker`
  - `snap` 安裝常見：`/var/snap/docker/common/var-lib-docker`

### 步驟 3：設定 SNMP 驗證

打開 `snmp/auths.local.yml`，填入真實驗證資料。

你會用到的名稱要和 `prometheus/file_sd/snmp-devices.yml` 內的 `snmp_auth` 一致，例如：

- `synology_v3`
- `router_v3`

建議優先使用 SNMPv3。

### 步驟 4：設定 Windows VM Targets

打開 `prometheus/file_sd/windows-hosts.local.yml`，把你的實際主機名稱或 IP 填進去。

例如：

```yaml
- targets: ["192.168.1.101:9182"]
  labels:
    device: win10-vm-01
    role: windows-vm
    site: home
```

### 步驟 5：設定 NAS 與 Router Targets

打開 `prometheus/file_sd/snmp-devices.local.yml`，把：

- `targets`
- `device`
- `site`
- `snmp_auth`
- `snmp_module`

調整成你的環境。

### 步驟 6：設定要探測的服務

如果你想監控服務是否能連線：

- HTTP / HTTPS 服務，編輯 `prometheus/file_sd/http-services.yml`
- TCP 服務，編輯 `prometheus/file_sd/tcp-services.yml`

### 步驟 7：設定告警通知

打開 `alertmanager/alertmanager.yml`。

目前專案已經預設把 `critical` 等級告警送往 Telegram，但真正會不會送出，取決於你是否正確填入本機 secrets 檔案：

- `secrets/alertmanager/telegram_bot_token`
- `secrets/alertmanager/telegram_chat_id`

### 步驟 7-1：用 BotFather 建立 Telegram Bot

根據 Telegram 官方 Bot 教學，先在 Telegram 裡打開 `@BotFather` 建立 bot。

建議流程：

1. 在 Telegram 搜尋 `@BotFather`
2. 傳送 `/newbot`
3. 依提示輸入：
   - Bot 顯示名稱
   - Bot username
4. 完成後，BotFather 會提供一組 bot token

把這組 token 寫入本機檔案：

```bash
printf '%s\n' '你的_bot_token' > secrets/alertmanager/telegram_bot_token
```

### 步驟 7-2：決定通知對象是私人聊天還是群組

你可以把通知送到：

- 私人聊天
  - 直接打開你的 bot，按 `Start`
- 群組
  - 把 bot 加進群組
  - 在群組中先送一則訊息給它看得到

如果是群組，`chat_id` 很常會是負數，這是正常的。

### 步驟 7-3：取得 Telegram `chat_id`

依 Telegram Bot API 的一般做法，先讓 bot 收到一則訊息，再用 `getUpdates` 查出 `chat_id`。

先對 bot 或群組送一則訊息，例如：

- 私訊 bot：`test`
- 群組中：`@你的bot test`

然後執行：

```bash
TOKEN="$(cat secrets/alertmanager/telegram_bot_token)"
curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates" | jq
```

在輸出中找：

- `message.chat.id`

把找到的數值寫入本機檔案：

```bash
printf '%s\n' '你的_chat_id' > secrets/alertmanager/telegram_chat_id
```

### 步驟 7-4：先直接測試 Telegram API

在測 Alertmanager 前，建議先直接用 Telegram API 發一則測試訊息：

```bash
TOKEN="$(cat secrets/alertmanager/telegram_bot_token)"
CHAT_ID="$(cat secrets/alertmanager/telegram_chat_id)"
curl -s "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=Alertmanager Telegram 測試訊息"
```

如果你收得到訊息，代表：

- bot token 正確
- chat id 正確
- bot 對目標聊天有發送權限

### 步驟 7-5：套用 Alertmanager 設定

完成 secrets 設定後，重新啟動 Alertmanager：

```bash
docker compose up -d alertmanager
```

如果整套系統還沒啟動，也可以直接：

```bash
make up
```

### 步驟 7-6：驗證 Alertmanager 設定

執行：

```bash
docker run --rm --entrypoint amtool \
  -v "$PWD/alertmanager:/etc/alertmanager" \
  prom/alertmanager:v0.33.0 \
  check-config /etc/alertmanager/alertmanager.yml
```

再確認本機 secrets 檔案存在：

```bash
ls -l secrets/alertmanager
```

### 步驟 7-7：實際測試告警是否真的會送到 Telegram

建議用低風險方式測試，不要直接破壞正式服務。

可以暫時在 `prometheus/file_sd/tcp-services.yml` 新增一個不存在的 TCP 目標：

```yaml
- targets: ["127.0.0.1:65534"]
  labels:
    service: telegram-alert-test
    role: test
```

然後重新啟動 Prometheus：

```bash
docker compose up -d prometheus
```

等待 2 分鐘以上後，應可在 Telegram 收到 `ServiceProbeFailed` 告警。

測試完成後，再把這筆測試 target 移除。

### 步驟 8：驗證語法

執行：

```bash
make validate
```

這會驗證：

- `docker compose` 設定是否可解析

### 步驟 9：啟動整套平台

執行：

```bash
make up
```

### 步驟 10：確認服務狀態

執行：

```bash
make ps
```

如果要看即時 log：

```bash
make logs
```

## 5. 每台設備要怎麼建置與設定

### 5.1 Zorin Linux 實體主機

本機主機已經由 compose 內建：

- `node-exporter`
- `cadvisor`

你不需要額外安裝 exporter。

你主要要觀察：

- CPU 使用率
  - 指標例：`node_cpu_seconds_total`
- 記憶體使用率
  - 指標例：`node_memory_MemAvailable_bytes`
  - 指標例：`node_memory_MemTotal_bytes`
- 磁碟使用率
  - 指標例：`node_filesystem_avail_bytes`
  - 指標例：`node_filesystem_size_bytes`
- 網路流量
  - 指標例：`node_network_receive_bytes_total`
  - 指標例：`node_network_transmit_bytes_total`
- Docker 容器使用量
  - 指標例：`container_cpu_usage_seconds_total`
  - 指標例：`container_memory_working_set_bytes`

### 5.2 Windows 10 VM

每台 Windows VM 都需要安裝 `windows_exporter`。

建議至少啟用這些 collectors：

- `cpu`
- `cs`
- `logical_disk`
- `net`
- `os`
- `service`
- `system`

官方 MSI 安裝範例：

```powershell
msiexec /i windows_exporter-0.31.7-amd64.msi --% ENABLED_COLLECTORS=cpu,cs,logical_disk,net,os,service,system LISTEN_PORT=9182
```

安裝完成後要確認：

- `http://<windows-ip>:9182/metrics` 可從 Prometheus 主機連到
- Windows 防火牆允許 `9182/tcp`
- `prometheus/file_sd/windows-hosts.local.yml` 已填入正確位址

建議先做兩層測試：

1. 在 Windows VM 本機測試：

```powershell
curl http://localhost:9182/metrics
```

2. 在 Zorin 監控主機測試：

```bash
curl http://<windows-ip>:9182/metrics
```

如果第二步失敗，通常優先檢查：

- Windows 防火牆是否放行 `9182/tcp`
- VMware 網路模式是否讓 Zorin 可直連該 VM
- `windows_exporter` 服務是否真的有啟動

你主要要觀察：

- CPU 使用率
  - `windows_cpu_time_total`
- 記憶體使用率
  - `windows_os_physical_memory_free_bytes`
  - `windows_cs_physical_memory_bytes`
- 磁碟容量
  - `windows_logical_disk_free_bytes`
  - `windows_logical_disk_size_bytes`
- 服務狀態
  - `windows_service_state`
- 網路流量
  - 視 collector 暴露的 `windows_net_*` 指標

### 5.3 Synology NAS

請在 DSM 啟用 SNMP。

建議設定：

- 優先使用 SNMPv3
- 建立專用唯讀帳號
- 限制來源 IP 為 Prometheus 主機

完成後要更新：

- `snmp/auths.local.yml`
- `prometheus/file_sd/snmp-devices.local.yml`

`snmp/auths.local.yml` 內的 `synology_v3` 要和 DSM 的 SNMPv3 設定完全一致。

如果密碼剛好以特殊字元開頭，例如 `!`、`#`、`&`，建議在 YAML 內加上雙引號，避免被 YAML 當成特殊語法。

範例：

```yaml
password: "!examplePassword"
priv_password: "!examplePassword"
```

建議用以下方式先驗證 NAS 的 SNMPv3 是否真的可用：

```bash
snmpwalk -v3 -l authPriv -u <username> -a SHA -A '<auth_password>' -x AES -X '<priv_password>' <NAS_IP> 1.3.6.1.2.1.1.1.0
```

如果成功，通常會回傳 `sysDescr` 類型的字串。

你主要要觀察：

- CPU 載入
  - `hrProcessorLoad`
- 記憶體使用率
  - `memAvailReal`
  - `memTotalReal`
- 網路流量
  - `ifHCInOctets`
  - `ifHCOutOctets`
- 儲存負載
  - `storageIOLA`
- 磁碟溫度
  - `diskTemperature`
- 磁碟健康
  - `diskHealthStatus`
- 系統溫度
  - `temperature`

### 5.4 ER-X Router

請在 ER-X 啟用 SNMP。

建議設定：

- 使用唯讀模式
- 限定來源 IP 或來源網段
- 確認 Prometheus 主機可達 `161/udp`

如果你的 ER-X Web UI 看得到 `SNMP Agent` 頁面，通常可以直接用 GUI 設定：

- `Enable`
  - 開啟
- `SNMP community`
  - 例如 `monitor`
- `Contact`
  - 管理者名稱或用途說明
- `Location`
  - 例如 `home`

這種 GUI 設法通常對應的是 `SNMPv2c`，因此在本專案中請把它對應到：

```yaml
auths:
  legacy_v2:
    version: 2
    community: monitor
```

並在 `prometheus/file_sd/snmp-devices.local.yml` 的 ER-X target 使用：

```yaml
snmp_auth: legacy_v2
```

建議用以下方式先驗證 ER-X 是否真的有回應：

```bash
snmpwalk -v2c -c <community> <ER-X_IP> 1.3.6.1.2.1.1.1.0
```

如果成功，通常會回傳 `EdgeOS` 的版本字串。

主要要觀察：

- CPU 載入
  - `hrProcessorLoad`
- 記憶體使用率
  - `memAvailReal`
  - `memTotalReal`
- 網路流量
  - `ifHCInOctets`
  - `ifHCOutOctets`
- Load Average
  - `laLoadFloat`
- 系統運作時間
  - `hrSystemUptime`

### 5.5 多個 Docker Compose 專案

本機 Docker 容器會由 `cAdvisor` 自動抓取。

如果你的容器是用 Docker Compose 啟動，Grafana dashboard 可以直接依：

- `container_label_com_docker_compose_project`
- `container_label_com_docker_compose_service`

來分組。

主要要觀察：

- 哪個 compose project 的容器最多
- 哪個 service CPU 長期偏高
- 哪個 service 記憶體長期攀升
- 哪些容器最近頻繁重啟
- 某個容器是否有異常高網路流量

## 6. Telegram 告警的設定原理

這個專案的 Telegram 告警採用「本機 secrets 檔案」設計：

- repo 內保存可公開的 Alertmanager 設定
- 真正敏感的 bot token / chat id 只放在本機 `secrets/alertmanager/`
- `docker-compose.yml` 會把本機 `secrets/alertmanager` 掛進 Alertmanager 容器
- `alertmanager.yml` 透過 `bot_token_file` 與 `chat_id_file` 讀取內容

這樣的好處是：

- 可以安全推上 GitHub
- 換主機部署時只要重建本機 secrets
- 不會把 Telegram 憑證寫死在版本控制內

## 7. 啟動後第一輪驗證要看什麼

### 6.1 Prometheus Targets 頁面

打開：

- `http://localhost:9090/targets`

確認以下 job 是否為 `UP`：

- `prometheus`
- `alertmanager`
- `node-exporter`
- `cadvisor`
- `windows-exporter`
- `snmp`
- `blackbox-http`
- `blackbox-tcp`

如果 `DOWN`，先檢查：

- 主機名或 IP 是否正確
- 防火牆是否開放
- SNMP 驗證是否正確
- exporter 是否真的有啟動

### 6.2 Grafana Dashboard

打開：

- `http://localhost:3000`

預設 dashboard 有三個：

- `Infrastructure Overview`
- `Docker Compose Overview`
- `Network Edge & NAS`

### 6.3 Alertmanager

打開：

- `http://localhost:9093`

主要檢查：

- 路由是否正常
- 告警是否有進來
- 是否需要新增 silence 或分流規則

## 8. 每個 Dashboard 的用途與觀察重點

### 7.1 Infrastructure Overview

用途：

- 快速總覽 Linux、Windows、Probe 類監控是否健康

重點觀察：

- 有多少基礎設施 target 目前可抓取
- 有多少 HTTP / TCP 服務目前探測成功
- Linux CPU / RAM 是否持續偏高
- Windows CPU / RAM 是否持續偏高
- Linux 網路流量是否異常突然升高
- 某些服務 probe 是否間歇性失敗

### 7.2 Docker Compose Overview

用途：

- 按 compose project / service 觀察容器負載

重點觀察：

- 哪個 compose project 的 service 最吃 CPU
- 哪個 service 記憶體逐步增加，可能有 memory leak
- 哪個 service 網路流量特別高
- 某些容器啟動時間是否頻繁重置，代表可能在重啟

### 7.3 Network Edge & NAS

用途：

- 集中查看 NAS 與 Router 的 SNMP 指標

重點觀察：

- CPU 是否長時間高檔
- 記憶體是否逼近上限
- 網路流量是否出現尖峰
- Synology 磁碟溫度是否過高
- Synology 磁碟健康是否異常
- 儲存裝置負載是否持續高檔

## 9. 已提供的告警規則與代表意義

- `TargetDown`
  - 某個 exporter 或 SNMP 目標抓不到
- `ServiceProbeFailed`
  - 某個 HTTP / TCP 服務連不上
- `LinuxCpuHigh`
  - Linux CPU 連續高於門檻
- `LinuxMemoryHigh`
  - Linux 記憶體長時間過高
- `LinuxRootDiskHigh`
  - Linux 根目錄容量不足
- `WindowsCpuHigh`
  - Windows CPU 連續高於門檻
- `WindowsMemoryHigh`
  - Windows 記憶體長時間過高
- `WindowsDiskHigh`
  - Windows 磁碟空間不足
- `SnmpCpuHigh`
  - Router / NAS CPU 長時間過高
- `SnmpMemoryHigh`
  - Router / NAS 記憶體長時間過高
- `SynologyDiskHealthProblem`
  - Synology 回報磁碟健康異常

## 10. 日常維運時建議固定觀察的指標

### 每天看一次

- 所有重要 targets 是否都是 `UP`
- 是否有服務 probe 失敗
- Grafana / Prometheus / Alertmanager 本身是否正常

### 每週看一次

- Linux 與 Windows 的 CPU / RAM 趨勢
- Docker Compose 各服務資源消耗排行
- NAS / Router 的平均流量與尖峰
- Prometheus 資料保存量是否成長過快

### 每月看一次

- 哪些告警門檻太敏感或太鬆
- 是否需要拆更多 dashboard
- 是否要調整 `PROMETHEUS_RETENTION`
- 是否要新增更多設備或服務 target

## 11. 新增設備或服務的標準流程

### 新增 Linux 主機

1. 在該主機安裝 `node_exporter`
2. 把 target 加進 `prometheus/file_sd/linux-hosts.yml`
3. `make validate`
4. `docker compose up -d`
5. 到 Prometheus Targets 頁面確認 `UP`

### 新增 Windows 主機

1. 安裝 `windows_exporter`
2. 開放 `9182/tcp`
3. 把 target 加進 `prometheus/file_sd/windows-hosts.local.yml`
4. 驗證與觀察 dashboard

### 新增 NAS / Router / Switch

1. 啟用 SNMP
2. 在 `snmp/auths.local.yml` 新增驗證名稱
3. 在 `prometheus/file_sd/snmp-devices.local.yml` 新增 target
4. 確認模組是否適合
5. 重新載入或重啟堆疊

### 新增應用程式服務探測

1. HTTP 服務加到 `http-services.yml`
2. TCP 服務加到 `tcp-services.yml`
3. 到 Grafana 確認 `probe_success`

## 12. 常見排錯方向

### Prometheus 抓不到 Windows VM

先檢查：

- `windows_exporter` 是否真的在跑
- 防火牆有沒有擋 `9182/tcp`
- `targets` 寫的是不是正確 IP / DNS

### SNMP 裝置一直 DOWN

先檢查：

- `snmp_auth` 名稱是否對應到 `auths.local.yml`
- SNMPv3 帳密與協定是否正確
- SNMPv2c 的 `community` 是否與設備設定一致
- Prometheus 主機能否打到設備 `161/udp`
- 裝置是否真的支援你指定的模組

### Telegram 沒收到通知

先檢查：

- `secrets/alertmanager/telegram_bot_token` 是否為真實 token
- `secrets/alertmanager/telegram_chat_id` 是否為正確 chat id
- 你是否有先對 bot 私訊 `/start` 或把 bot 加到群組
- 你是否能用 `sendMessage` API 直接送出測試訊息
- Alertmanager log 是否有 Telegram API 錯誤

看 Alertmanager log：

```bash
docker compose logs -f alertmanager
```

### Grafana 有 Dashboard 但沒資料

先檢查：

- Prometheus Targets 是否 `UP`
- Grafana Data Source 是否連得上 Prometheus
- Dashboard 變數是否選到錯誤 target

### 容器監控沒有資料

先檢查：

- `cadvisor` 是否有正常啟動
- Docker 容器是否真的在同一台主機
- Compose 容器是否有正確標籤

## 13. 安全與 Git 策略

- 這個 repo 適合推上 GitHub
- 真實帳密只放本機 `.env` 與 `snmp/auths.local.yml`
- 真實設備 IP / 主機名只放本機 `prometheus/file_sd/*.local.yml`
- Telegram bot token 與 chat id 只放本機 `secrets/alertmanager/`
- 監控執行資料只放本機 `prometheus/data`、`alertmanager/data`、`grafana/data`、`snmp/generated`
- 需求說明只留在本機
- 建議 SNMP 使用 v3，不要長期依賴 v2 community
- 若未來要對外開放 Grafana / Prometheus / Alertmanager，建議加：
  - 反向代理
  - TLS
  - 基本身分驗證或 SSO
  - IP 限制

## 14. 目前建議的操作順序摘要

第一次部署時，照這個順序做最穩：

1. `make bootstrap`
2. 改 `.env`
3. 改 `snmp/auths.local.yml`
4. 改 `prometheus/file_sd/*.yml`
5. 填 `secrets/alertmanager/telegram_*`
6. `make validate`
7. `make up`
8. 檢查 Prometheus Targets
9. 檢查 Grafana Dashboards
10. 測試告警通知是否真的能收到
