# Dashboard 說明

Grafana dashboard 檔案使用 JSON 格式，而 JSON 本身不支援註解，所以這份文件用來補足各 dashboard 的用途、觀察重點與適用情境。

## `infrastructure-overview.json`

用途：

- 快速總覽 Linux 主機、Windows VM 與服務探測的健康狀態

主要面板：

- 可連線的基礎設施目標
- 健康的服務探測
- Linux CPU 使用率
- Linux 記憶體使用率
- Windows CPU 使用率
- Windows 記憶體使用率
- 硬碟使用率
- Linux 網路吞吐量
- HTTP / TCP / ICMP 探測成功率

適合觀察：

- 哪台主機突然失聯
- 哪些服務最近探測失敗
- Linux / Windows CPU 與記憶體是否接近門檻
- Linux / Windows 硬碟使用率是否持續升高

## `docker-compose-overview.json`

用途：

- 以 docker-compose project / service 為單位觀察容器使用情況

主要面板：

- 已觀測容器數
- 容器 CPU 使用率
- 容器記憶體使用量
- 容器網路吞吐量
- 容器運行時間

適合觀察：

- 哪個 compose service 最吃資源
- 哪個容器是否反覆重啟
- 某個服務是否出現記憶體持續上升

## `network-edge-and-nas.json`

用途：

- 集中觀察 Synology NAS 與 ER-X Router 的 SNMP 指標

主要面板：

- SNMP CPU 負載
- SNMP 記憶體使用率
- Synology 網路吞吐量
- ER-X WAN 流量
- ER-X LAN/AP 流量(eth1~eth4 加總)
- 平均負載
- Synology 溫度
- Synology 儲存負載
- Synology 儲存空間使用率
- Synology 容量摘要
- Synology 磁碟健康狀態
- ER-X AP Uplink 流量
- TP-Link AP 固定 Port 流量
- TP-Link AP 在線狀態

適合觀察：

- NAS / Router 是否長期高負載
- 磁碟健康或溫度是否異常
- 網路流量是否出現異常尖峰
- WAN 與 LAN/AP 流量是否被分開看清楚

補充判讀：

- `SNMP 記憶體使用率` 目前以 `memTotalReal - memAvailReal - memCached - memBuffer` 計算，較接近 DSM 顯示的實際記憶體占用
- `Synology 網路吞吐量` 只看 `synology-nas` 的實體網卡流量
- `ER-X WAN 流量` 只看 `pppoe0`，比較接近你實際對外上網流量
- `ER-X LAN/AP 流量(eth1~eth4 加總)` 會把 `eth1` 到 `eth4` 視為 LAN/AP 側流量加總
- `Synology 儲存空間使用率` 只顯示資料卷，例如 `/volume1`，不顯示系統分割區 `/`
- `Synology 容量摘要` 直接顯示使用率、已用、可用、總容量，比時間線更適合判讀 NAS 容量
- `Synology 磁碟健康狀態` 面板內 `Value = 1` 代表正常
- `Value != 1` 代表非健康狀態，Grafana 會顯示為 `異常`
- `ER-X AP Uplink 流量` 會用 `Router Port` 變數挑選 `ER-X` 上對應的實體介面，用來間接觀察像 `TP-Link Deco X20` 這類 AP 的 uplink 流量
- `TP-Link AP 固定 Port 流量` 會直接固定觀察 `eth1`、`eth2`、`eth4`，對應 `living-room-ap-ping`、`study-room-ap-ping`、`guest-room-ap-ping`
- `TP-Link AP 在線狀態` 會直接顯示所有 `role=access-point` 的 ICMP probe 結果；像 `study-room-ap-ping` 這種暫時未接線的設備，也能顯示離線但不一定需要告警
