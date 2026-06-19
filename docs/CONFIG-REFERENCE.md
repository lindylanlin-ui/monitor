# 設定參考手冊

這份文件不是教你第一次部署，而是給你未來回頭維護時快速查閱：

- 每個設定檔在做什麼
- 常見欄位代表什麼
- 什麼情況應該改哪個檔案
- 告警規則與監控邏輯怎麼看

如果你是第一次部署，先看 [README.md](/home/tuffy/project/monitor/README.md:1)。

## 1. 設定檔總覽

### `docker-compose.yml`

用途：

- 定義整套監控平台有哪些服務
- 定義每個服務的 image、port、volume、network、啟動參數

你通常會在這裡調整：

- 哪些服務要啟動
- 容器對外 port
- volume 掛載
- 某些服務的啟動參數

你通常不需要常改：

- 服務之間的 network 名稱
- exporter 基本 image 名稱

### `.env` / `.env.example`

用途：

- 集中管理版本、port、Grafana 管理員帳密、保留天數等環境參數

常見欄位：

- `PROMETHEUS_VERSION`
  - Prometheus 映像版本
- `PROMETHEUS_PORT`
  - Prometheus 對外 port
- `PROMETHEUS_RETENTION`
  - Prometheus 保存多久資料
- `GRAFANA_PORT`
  - Grafana 對外 port
- `GRAFANA_ADMIN_USER`
  - Grafana 管理帳號
- `GRAFANA_ADMIN_PASSWORD`
  - Grafana 管理密碼

### `prometheus/prometheus.yml`

用途：

- 這是 Prometheus 主設定檔
- 決定 Prometheus 要抓哪些 targets、載入哪些規則、把告警送去哪裡

這份檔最重要的三個區塊：

- `global`
- `alerting`
- `scrape_configs`

### `prometheus/rules/infrastructure-alerts.yml`

用途：

- 定義何時要觸發告警

組成方式：

- `groups`
  - 把規則分組，方便管理
- `rules`
  - 每條規則包含名稱、條件、持續時間、標籤、說明

### `prometheus/file_sd/*.yml`

用途：

- 用來列出外部 targets
- 讓你不用每次都去改 `prometheus.yml`

你可以把它想成：

- `prometheus.yml` 是監控邏輯
- `file_sd/*.yml` 是設備名單

### `alertmanager/alertmanager.yml`

用途：

- 控制告警怎麼分流、分組、多久重送、送到哪裡

### `snmp/auths.local.yml`

用途：

- 保存 SNMP 認證方式

注意：

- 這是本機私密檔
- 不應推上 GitHub

### `prometheus/file_sd/windows-hosts.local.yml`

用途：

- 保存真實 Windows VM IP 與顯示名稱

### `prometheus/file_sd/snmp-devices.local.yml`

用途：

- 保存真實 NAS / Router IP 與監控模組

## 2. `prometheus.yml` 常見欄位意思

### `global`

例子：

```yaml
global:
  scrape_interval: 30s
  evaluation_interval: 30s
```

意思：

- `scrape_interval`
  - 每隔多久抓一次指標
- `evaluation_interval`
  - 每隔多久評估一次告警規則

如果你調太短：

- 資料更即時
- 但主機負擔更重

### `alerting`

例子：

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093
```

意思：

- Prometheus 觸發告警後，要把事件送到哪個 Alertmanager

### `rule_files`

例子：

```yaml
rule_files:
  - /etc/prometheus/rules/*.yml
```

意思：

- Prometheus 要載入哪些告警規則檔

### `scrape_configs`

這是 Prometheus 最核心的區塊。

每個 `job_name` 代表一類監控來源，例如：

- `node-exporter`
- `windows-exporter`
- `cadvisor`
- `snmp`
- `blackbox-http`
- `blackbox-tcp`

#### `job_name`

例子：

```yaml
- job_name: windows-exporter
```

意思：

- 這一組 targets 會被歸類為 `windows-exporter`
- 之後查詢或告警時可用 `job="windows-exporter"` 篩選

#### `static_configs`

用途：

- 直接把 target 寫死在設定裡

這通常用在：

- 本機服務
- 幾乎不會變的內部服務

#### `file_sd_configs`

用途：

- 從外部 YAML 檔讀 target 名單

這通常用在：

- Windows VM
- NAS
- Router
- 未來新增設備

#### `relabel_configs`

用途：

- 改寫 label
- 把某些 label 轉換成 Prometheus 真正會用的欄位

你在本專案最常看到的是：

```yaml
- source_labels: [device]
  target_label: instance
```

意思：

- 把你自訂的 `device` 名稱拿來當作 `instance`
- 這樣 Grafana 和告警裡顯示的就不是 IP，而是比較好懂的名字

## 3. 本專案每個 `job_name` 在監控什麼

### `prometheus`

用途：

- 監控 Prometheus 自己

主要看：

- `up`
- Prometheus 自身狀態

### `alertmanager`

用途：

- 監控 Alertmanager 自己

### `node-exporter`

用途：

- 監控 Zorin 主機或其他 Linux 主機

主要類型：

- CPU
- 記憶體
- 檔案系統
- 網路介面

### `windows-exporter`

用途：

- 監控 Windows 主機

主要類型：

- CPU
- 記憶體
- 磁碟
- Windows 服務狀態

### `cadvisor`

用途：

- 監控 Docker 容器

主要類型：

- 容器 CPU
- 容器 RAM
- 容器網路
- 容器啟動時間

### `snmp`

用途：

- 監控無法直接安裝 exporter 的設備

像是：

- Synology NAS
- ER-X Router

### `blackbox-http`

用途：

- 檢查網站或 API 是否有 HTTP 回應

### `blackbox-tcp`

用途：

- 檢查 TCP 服務能不能建立連線

## 4. `file_sd` 檔案怎麼看

### 結構

範例：

```yaml
- targets: ["192.168.4.105:9182"]
  labels:
    device: tuffy_pc_vm
    role: windows-vm
    site: home
```

意思：

- `targets`
  - 真正要抓的位址
- `device`
  - 顯示名稱
- `role`
  - 裝置類型
- `site`
  - 所在位置

### `device`

這是人看的名字。

用途：

- Grafana 圖表顯示
- Alertmanager 告警顯示
- 幫你避免只看到 IP

### `role`

這是分類標籤。

用途：

- 讓你之後可以依類型分群
- 例如：
  - `windows-vm`
  - `linux-host`
  - `router`
  - `nas`

### `site`

這是地點標籤。

用途：

- 如果未來有多個地點，可以更容易分群

## 5. `snmp-devices.local.yml` 特有欄位

### `snmp_auth`

用途：

- 指向 `snmp/auths.local.yml` 內的一組認證名稱

例如：

```yaml
snmp_auth: synology_v3
```

意思：

- Prometheus 這筆 target 會用 `synology_v3` 那組帳號資訊

### `snmp_module`

用途：

- 決定這台設備要抓哪些 SNMP 模組

範例：

```yaml
snmp_module: if_mib,hrDevice,hrStorage,hrSystem,ucd_memory,ucd_la_table,synology
```

意思：

- `if_mib`
  - 網路流量
- `hrDevice`
  - CPU / 裝置狀態
- `hrStorage`
  - 儲存空間
- `hrSystem`
  - uptime / process
- `ucd_memory`
  - 記憶體
- `ucd_la_table`
  - load average
- `synology`
  - Synology 專屬指標

## 6. `auths.local.yml` 怎麼看

### SNMPv3 範例

```yaml
synology_v3:
  version: 3
  username: export
  security_level: authPriv
  auth_protocol: SHA
  password: "example"
  priv_protocol: AES
  priv_password: "example"
```

意思：

- `version: 3`
  - 使用 SNMPv3
- `username`
  - SNMP 帳號
- `security_level: authPriv`
  - 有驗證也有加密
- `auth_protocol`
  - 驗證演算法
- `password`
  - 驗證密碼
- `priv_protocol`
  - 加密演算法
- `priv_password`
  - 加密密碼

### SNMPv2c 範例

```yaml
legacy_v2:
  version: 2
  community: monitor
```

意思：

- `community`
  - 相當於共用密碼

## 7. `alertmanager.yml` 怎麼看

### `route`

用途：

- 決定告警送到哪個 receiver

常見欄位：

- `receiver`
  - 預設送去哪
- `group_by`
  - 用哪些欄位來分組
- `group_wait`
  - 新告警先等多久再送第一批
- `group_interval`
  - 同群新告警多久整理一次再送
- `repeat_interval`
  - 同一告警多久重送一次

### `receivers`

用途：

- 定義實際通知方式

本專案現在是：

- `blackhole`
  - 吃掉不想通知的告警
- `default-notify`
  - 送到 Telegram

## 8. `infrastructure-alerts.yml` 怎麼看

每條規則大致長這樣：

```yaml
- alert: LinuxCpuHigh
  expr: ...
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: ...
    description: ...
```

欄位意思：

- `alert`
  - 告警名稱
- `expr`
  - 觸發條件
- `for`
  - 條件連續成立多久才真的告警
- `labels`
  - 附加分類資訊
- `annotations`
  - 人看的說明文字

### 常見查詢邏輯

#### `up == 0`

意思：

- target 抓不到

#### `rate(...[5m])`

意思：

- 取最近 5 分鐘的變化速率

#### `avg by (instance)`

意思：

- 以 `instance` 為單位做平均

這常用在：

- 多核心 CPU 平均使用率

## 9. Docker 監控相關設定怎麼看

### 為什麼 Docker 服務通常不用額外設定 exporter

因為本專案已經有：

- `cadvisor`

只要你的容器是跑在這台 Zorin 主機上，通常 `cadvisor` 就能自動看到：

- `openclaw`
- `openvpn`
- `wireguard`
- 其他 compose 容器

### 什麼情況還要額外設定

- 你要監控的是別台主機上的 Docker
  - 才需要在別台主機也跑 `cadvisor`
- 你要確認服務有沒有回應
  - 才要加 `blackbox-http` 或 `blackbox-tcp`
- 你要監控 VPN 協定層狀態
  - 可能還要補 `OpenVPN` / `WireGuard` 專屬做法

## 10. 常見修改情境對照

### 想改 Grafana 管理密碼

改：

- `.env`

### 想新增一台 Windows VM

改：

- `prometheus/file_sd/windows-hosts.local.yml`

### 想新增一台 NAS 或 Router

改：

- `snmp/auths.local.yml`
- `prometheus/file_sd/snmp-devices.local.yml`

### 想新增一個 HTTP 健康檢查

改：

- `prometheus/file_sd/http-services.yml`

### 想改 Telegram 通知方式

改：

- `alertmanager/alertmanager.yml`
- `alertmanager/templates/default.tmpl`
- `secrets/alertmanager/*`

### 想調整告警門檻

改：

- `prometheus/rules/infrastructure-alerts.yml`

## 11. 未來回頭看時建議先讀哪裡

如果你看到某個問題，不知道要去哪裡改，建議順序：

1. 先看 [README.md](/home/tuffy/project/monitor/README.md:1)
2. 再看本文件
3. 最後才看原始 YAML / JSON

快速對照：

- 看不懂整體流程
  - 先看 `README`
- 看不懂某個欄位
  - 看這份 `CONFIG-REFERENCE`
- 看不懂圖表用途
  - 看 `grafana/dashboards/README.md`
