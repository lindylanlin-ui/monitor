# Dashboard 說明

Grafana dashboard 檔案使用 JSON 格式，而 JSON 本身不支援註解，所以這份文件用來補足各 dashboard 的用途、觀察重點與適用情境。

## `fail2ban-security-overview.json`

用途：

- 以時間趨勢觀察 Fail2ban jail 的封鎖狀態、SSH 失敗嘗試與 `/file/` 密碼錯誤

主要面板：

- 目前正在封鎖的 IP 數、最近 7 天 SSH 密碼失敗與 `/file/` 密碼錯誤
- 監控資料上次更新距今（以分鐘顯示）
- 哪個防護規則正在封鎖、最近 15 分鐘新增封鎖與防護規則摘要
- 登入失敗變化，以及 dashboard 內的判讀說明

補充判讀：

- 這是內部安全 dashboard，不可建立公開分享連結；雖然不保存 IP label，仍會顯示 jail 與主機名稱。
- `累計` 計數由 Fail2ban 提供，Fail2ban 服務重啟後會歸零；觀察短時間新增封鎖時，請看 `increase(fail2ban_jail_bans_total[...])`。
- `/file/` 指標以目前仍保留的 Nginx log 計算，不代表固定天數的完整歷史資料；日誌輪替或清理後數值下降是預期行為。
- `監控資料上次更新距今` 通常應低於 2 分鐘；超過 5 分鐘時，應先依 [FAIL2BAN-MONITORING.md](./FAIL2BAN-MONITORING.md) 檢查 systemd 與 textfile 檔案。
- dashboard 底部的「這張圖要怎麼看？」會說明建議閱讀順序，以及 `sshd`、`proxy-404-scan` 的用途。

## `infrastructure-overview.json`

用途：

- 快速總覽 Linux 主機、Windows VM 與服務探測的健康狀態

主要面板：

- 基礎設施健康度與異常基礎設施目標數
- 服務探測健康度與異常服務探測數
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

補充判讀：

- `基礎設施健康度` 是 Linux、Windows 與 SNMP exporter target 的正常比例；`異常基礎設施目標 = 0` 才代表全部正常。
- `服務探測健康度` 是 HTTP、TCP 與 ICMP probe 的正常比例；`異常服務探測 = 0` 才代表全部正常。
- Linux 與 Windows 的 CPU、記憶體使用率均採用與 `Linux 網路吞吐量` 相同的時間序列圖表樣式，可對照各主機的趨勢與歷史變化。

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

補充判讀：

- `容器 CPU 使用率` 與 `容器記憶體使用量` 使用與 `容器網路吞吐量` 相同的時間序列圖表樣式，可對照各 service 的趨勢與歷史變化。

## `website-service-overview.json`

用途：

- 監控公開網站服務的 HTTP 可用性、回應時間、狀態碼與 TLS 憑證期限

主要面板：

- 受監測服務數、目前正常／異常服務數與最近 24 小時平均可用性
- 各服務目前狀態與 HTTP 狀態碼
- 服務可用性、回應時間與正常／異常狀態時間線
- TLS 憑證到期清單、最快到期憑證與 21 天內到期服務數

補充判讀：

- Dashboard 只顯示 `role=public-web` 的 HTTP probe；實際 URL 由 `prometheus/file_sd/http-services.local.yml` 維護。
- `服務回應時間` 是每次 HTTP probe 的完整耗時；「公開網站回應過慢」（UID: `public_web_slow_response`）會在回應時間連續 5 分鐘超過 2 秒時告警。
- `TLS 憑證到期清單` 只會顯示 HTTPS 服務，並依剩餘天數由小到大排列；到期日期依 Grafana 的瀏覽器時區顯示。
- `最快到期憑證` 與 `21 天內到期服務` 會跟隨 dashboard 的「服務」篩選；少於 21 天持續 1 小時會觸發告警。
- 此 dashboard 會顯示 service 名稱，供內部使用，不應建立公開分享連結。
- 新增服務、調整或建立面板、告警與驗證流程請看 [WEBSITE-SERVICE-MONITORING.md](./WEBSITE-SERVICE-MONITORING.md)。

## `host-hardware-health.json`

用途：

- 集中觀察監控主機本身的硬體健康狀態，特別是磁碟、SSD 壽命、溫度與 NVIDIA GPU

主要面板：

- 主機磁碟 SMART 健康狀態（裝置、型號與介面）
- NVMe SSD 剩餘壽命、磁碟溫度與 NVMe critical warning
- 實體磁碟忙碌率與所有本機檔案系統使用率
- NVIDIA GPU 使用率、溫度、功耗與已用顯示記憶體
- CPU 封裝／核心與 NVMe Composite 溫度

補充判讀：

- `SMART 健康狀態` 的表格會顯示主機、裝置名稱、型號與介面；`正常` 代表磁碟整體 SMART 測試通過，`異常` 應立即確認備份與安排檢修。
- `NVMe SSD 剩餘壽命` 以裝置回報的 `percentage_used` 反算；僅支援該欄位的 SSD 會顯示資料。
- `NVMe SSD 剩餘壽命` 的名稱會顯示實際裝置與型號，例如 `nvme0 — 型號`；資料來自 SMART exporter 的 `exported_device` 與 `model_name` 標籤，不包含序號。
- `NVMe 控制器警告與媒體錯誤累計` 的媒體錯誤是累積值，重點是觀察是否增加；critical warning 非零則需立即處理。
- `磁碟目前溫度` 與 `實體磁碟忙碌率` 均使用 `裝置 — 型號` 顯示，例如 `nvme0n1 — ADATA SX8200PNP`，可直接對應實體磁碟。
- GPU 面板需要先依 [SETUP-GUIDE.md](./SETUP-GUIDE.md) 啟用 `gpu` profile；未啟用時顯示 `No data` 是預期行為。
- `CPU 與 NVMe 溫度` 只保留 CPU 封裝／核心，以及每顆 NVMe 的 Composite 溫度；重複的 ACPI 與 NVMe 次要感測器不顯示。

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
- Synology SSD 剩餘壽命
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
- `SNMP CPU 負載` 與 `SNMP 記憶體使用率` 使用與網路流量面板相同的時間序列圖表樣式，可對照各裝置的趨勢與歷史變化。
- `Synology 網路吞吐量` 只看 `synology-nas` 的實體網卡流量
- `ER-X WAN 流量` 只看 `pppoe0`，比較接近你實際對外上網流量
- `ER-X LAN/AP 流量(eth1~eth4 加總)` 會把 `eth1` 到 `eth4` 視為 LAN/AP 側流量加總
- `Synology 儲存空間使用率` 只顯示資料卷，例如 `/volume1`，不顯示系統分割區 `/`
- `Synology 容量摘要` 直接顯示使用率、已用、可用、總容量，比時間線更適合判讀 NAS 容量
- `Synology 磁碟健康狀態` 面板內 `Value = 1` 代表正常
- `Value != 1` 代表非健康狀態，Grafana 會顯示為 `異常`
- `Synology SSD 剩餘壽命` 使用 DSM 透過 SNMP 回報的 `diskRemainLife`；僅有支援此欄位的 SSD 會顯示資料
- `ER-X AP Uplink 流量` 會用 `Router Port` 變數挑選 `ER-X` 上對應的實體介面，用來間接觀察像 `TP-Link Deco X20` 這類 AP 的 uplink 流量
- `TP-Link AP 固定 Port 流量` 會直接固定觀察 `eth1`、`eth2`、`eth4`，對應 `living-room-ap-ping`、`study-room-ap-ping`、`guest-room-ap-ping`
- `TP-Link AP 在線狀態` 會直接顯示所有 `role=access-point` 的 ICMP probe 結果；像 `study-room-ap-ping` 這種暫時未接線的設備，也能顯示離線但不一定需要告警

## `public-status-overview.json`

用途：

- 對外快速查看整體服務狀態，適合建立 Grafana 的公開 Dashboard 連結

主要面板：

- 整體營運狀態、24 小時可用性、回應時間與異常項目
- 監測服務、基礎設施、容器與儲存設備健康摘要
- 匿名化的 Linux 主機 CPU、記憶體與儲存空間使用率
- 網站、連線服務、網路設備等類型健康度
- Linux、Windows、網路儲存與監控平台健康度
- 24 小時可用性、服務可用性與服務回應狀態

隱私設計：

- 所有 PromQL 都先彙總，不依主機、服務、容器、磁碟或網路介面分組
- 不顯示裝置名稱、服務名稱、IP、URL、位置、內網拓撲、流量、容量或磁碟健康明細
- Dashboard 沒有篩選變數，避免公開連結可列出任何 label 值
- CPU、記憶體與儲存空間使用率只彙總 Linux 主機資料，不包含 Windows 或 SNMP 裝置

建立公開連結：

1. 在 Grafana 開啟「公開狀態中心」。
2. 選擇 **Share → Share externally**，將連結存取設為 **Anyone with the link** 後複製連結。
3. 請只分享這個 Dashboard；其餘三個既有 Dashboard 會顯示主機、服務或網路等環境資訊，不適合公開。
