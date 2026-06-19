# Grafana Dashboard 說明

Grafana dashboard 檔案使用 JSON 格式，而 JSON 本身不支援註解，所以這份文件用來補足各 dashboard 的用途、觀察重點與適用情境。

## `infrastructure-overview.json`

用途：

- 快速總覽 Linux 主機、Windows VM 與服務探測的健康狀態

主要面板：

- Reachable Infrastructure Targets
- Healthy Service Probes
- Linux CPU Usage
- Linux Memory Usage
- Windows CPU Usage
- Windows Memory Usage
- Linux Network Throughput
- HTTP / TCP Probe Success

適合觀察：

- 哪台主機突然失聯
- 哪些服務最近探測失敗
- Linux / Windows CPU 與記憶體是否接近門檻

## `docker-compose-overview.json`

用途：

- 以 docker-compose project / service 為單位觀察容器使用情況

主要面板：

- Observed Containers
- Container CPU Usage
- Container Memory Working Set
- Container Network Throughput
- Container Uptime

適合觀察：

- 哪個 compose service 最吃資源
- 哪個容器是否反覆重啟
- 某個服務是否出現記憶體持續上升

## `network-edge-and-nas.json`

用途：

- 集中觀察 Synology NAS 與 ER-X Router 的 SNMP 指標

主要面板：

- SNMP CPU Load
- SNMP Memory Usage
- SNMP Network Throughput
- Load Average
- Synology Temperature
- Synology Storage Load
- Synology Disk Health

適合觀察：

- NAS / Router 是否長期高負載
- 磁碟健康或溫度是否異常
- 網路流量是否出現異常尖峰
