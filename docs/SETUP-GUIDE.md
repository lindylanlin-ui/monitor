# 詳細建置指南

這份文件放「第一次部署」與「設備接入」的實作步驟。

如果你只是想快速知道這個 repo 是做什麼、最常改哪裡，先看 [README.md](../README.md)。

## 1. 部署前你要準備什麼

### 1.1 監控主機需求

- Docker Engine
- Docker Compose Plugin
- 建議至少 `2 CPU / 4 GB RAM`
- 足夠的磁碟空間保存 Prometheus 資料

先確認：

```bash
docker --version
docker compose version
```

### 1.2 網路需求

Prometheus 主機需要能連到：

- Windows VM 的 `9182/tcp`
- SNMP 設備的 `161/udp`
- 你要做 HTTP probe 的 URL
- 你要做 TCP probe 的連接埠

### 1.3 敏感資料原則

本專案刻意把敏感資訊留在本機，不放進 Git：

- `.env`
- `snmp/auths.local.yml`
- `prometheus/file_sd/*.local.yml`
- `secrets/grafana-alerting/*`

## 2. 第一次建置

### 步驟 1：建立本機設定檔

```bash
make bootstrap
```

會建立：

- `.env`
- `snmp/auths.local.yml`
- `prometheus/file_sd/windows-hosts.local.yml`
- `prometheus/file_sd/snmp-devices.local.yml`
- `prometheus/file_sd/icmp-services.local.yml`
- `prometheus/data`
- `grafana/data`
- `grafana/runtime`
- `snmp/generated`
- `secrets/grafana-alerting/telegram_bot_token`
- `secrets/grafana-alerting/telegram_chat_id`

### 步驟 2：設定 `.env`

至少調整：

- `GRAFANA_ADMIN_PASSWORD`
- `PROMETHEUS_EXTERNAL_URL`
- `GRAFANA_ROOT_URL`
- `PROMETHEUS_RETENTION`

如果 port 有衝突，也可調整：

- `PROMETHEUS_PORT`
- `GRAFANA_PORT`

注意：

- `CADVISOR_VERSION` 不要加 `v` 前綴
- `DOCKER_ROOT_DIR` 要指向主機上的 Docker 真實資料目錄

### 步驟 3：設定 Telegram

填入：

- `secrets/grafana-alerting/telegram_bot_token`
- `secrets/grafana-alerting/telegram_chat_id`

如果你還沒確認 bot 與 chat id，細節請看 [查修手冊](./TROUBLESHOOTING.md) 的 Telegram 段落。

## 3. 接入監控目標

### 3.1 Windows VM

1. 安裝 `windows_exporter`
2. 開放 `9182/tcp`
3. 編輯 `prometheus/file_sd/windows-hosts.local.yml`

範例：

```yaml
- targets: ["192.168.1.101:9182"]
  labels:
    device: win10-vm-01
    role: windows-vm
    site: home
```

### 3.2 SNMP 裝置

1. 在設備上啟用 SNMP
2. 編輯 `snmp/auths.local.yml`
3. 編輯 `prometheus/file_sd/snmp-devices.local.yml`

建議優先使用 SNMPv3。

常見欄位：

- `targets`
- `device`
- `site`
- `snmp_auth`
- `snmp_module`

### 3.3 HTTP / TCP / ICMP 服務探測

- HTTP / HTTPS：改 `prometheus/file_sd/http-services.yml`
- TCP：改 `prometheus/file_sd/tcp-services.yml`
- ICMP：改 `prometheus/file_sd/icmp-services.local.yml`

TP-Link Deco X20 這類家用 AP 若沒有提供 SNMP，建議至少先做 ICMP 探測。

範例：

```yaml
- targets: ["192.168.1.50"]
  labels:
    service: tplink-x20-ping
    role: access-point
    site: home
```

如果你想間接看 X20 的 uplink 流量，則改從 `ER-X` 那一側觀察：

1. 打開 `網路與 NAS` dashboard
2. 在 `Router Port` 變數選擇 X20 接到的那個 `ER-X` 介面
3. 觀察 `ER-X AP Uplink 流量` 面板

## 4. 驗證與啟動

### 步驟 1：驗證語法

```bash
make validate
```

這會驗證：

- `docker compose` 設定是否可解析

### 步驟 2：啟動平台

```bash
make up
```

### 步驟 3：確認服務狀態

```bash
make ps
```

### 步驟 4：確認 Prometheus Targets

打開：

- `http://localhost:9090/targets`

確認重要 target 都是 `UP`。

### 步驟 5：確認 Grafana

打開：

- `http://localhost:3000`
- `http://localhost:3000/alerting/list`
- `http://localhost:3000/alerting/notifications`

## 5. 第一次啟動後建議檢查

- Linux / Windows / SNMP target 是否都 `UP`
- Dashboard 是否沒有大面積 `No data`
- Telegram contact point 是否存在
- Grafana Alerting 規則是否已載入

## 6. 之後常用的重載方式

改完 Grafana dashboard 或 alerting：

```bash
docker compose up -d --force-recreate grafana
```

改完 Prometheus target / scrape 設定：

```bash
docker compose up -d prometheus
```

## 7. 你接下來會常看的文件

- 看欄位意思：
  - [CONFIG-REFERENCE.md](./CONFIG-REFERENCE.md)
- 看新增面板 / 新增告警 / PromQL 範例：
  - [EXTENDING.md](./EXTENDING.md)
- 看故障排除：
  - [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
