# 擴充與告警設計指南

這份文件放未來擴充這套監控平台時最常用的流程與範例。

如果你是第一次部署，先看 [README.md](../README.md) 與 [SETUP-GUIDE.md](./SETUP-GUIDE.md)。

## 1. 先分清楚你要做的是哪一種

- 新增監控指標
  - 目標是讓 Prometheus 抓到新的 metric
- 新增 dashboard 面板
  - 目標是把已經存在的 metric 視覺化
- 新增告警規則
  - 目標是讓某個條件成立時通知你
- 調整告警閥值
  - 目標是修改既有規則的敏感度

## 2. 新增監控指標的標準流程

### 情境 A：Prometheus 已經抓得到，只是你還沒拿來用

1. 先查 metric 是否存在
2. 用 PromQL 算出你真正想看的值
3. 確認結果合理，再拿去做 dashboard 或 alert

例如：

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=hrStorageUsed{job="snmp",instance="synology-nas"}' | jq
```

### 情境 B：Prometheus 根本抓不到

先補資料來源，不要先改 dashboard。

常見位置：

- Linux：`prometheus/file_sd/linux-hosts.yml`
- Windows：`prometheus/file_sd/windows-hosts.local.yml`
- SNMP：`prometheus/file_sd/snmp-devices.local.yml`
- HTTP / TCP probe：`prometheus/file_sd/http-services.yml`、`prometheus/file_sd/tcp-services.yml`
- ICMP probe：`prometheus/file_sd/icmp-services.local.yml`
- SNMP 模組：`snmp/modules.yml`
- 主機端自訂資料：node_exporter textfile collector；Fail2ban 實例請看 [FAIL2BAN-MONITORING.md](./FAIL2BAN-MONITORING.md)

## 3. 新增 dashboard 面板的標準流程

1. 先決定哪個 dashboard 最適合放
2. 改對應的 `grafana/dashboards/*.json`
3. 選對 panel 類型
4. 設定 query、標題、單位、legend
5. 補 `docs/DASHBOARDS.md`
6. 重載 Grafana

若要從零建立一張可 provision 的 dashboard，請依 [FAIL2BAN-MONITORING.md 的「建立全新 dashboard」](./FAIL2BAN-MONITORING.md#建立全新的-grafana-dashboard) 流程處理 UID、JSON、資料來源與驗證。

常見 panel 類型：

- `timeseries`
  - 看趨勢，例如 CPU、流量、溫度
- `stat`
  - 看現在值，例如可用容量、總容量、狀態摘要
- `table`
  - 看明細，例如磁碟健康、volume 狀態

重載：

```bash
docker compose up -d --force-recreate grafana
```

## 4. 新增告警規則的標準流程

1. 先把 PromQL 單獨查到正確
2. 決定告警類型
3. 寫進 `grafana/provisioning/alerting/rules.yml`
4. 寫 `summary` 與 `description`
5. 設 `for:` 避免瞬間波動誤報
6. 重載 Grafana
7. 實際測一次

常見告警類型：

- 固定門檻
  - 例如 `CPU > 85%`
- 相對基線
  - 例如最近 `5m` 高於最近 `1h` 平均的 `3 倍`
- 可達性
  - 例如 `up < 1`、`probe_success < 1`
- 狀態值異常
  - 例如 `diskHealthStatus != bool 1`

## 5. 閥值一開始怎麼定比較合理

1. 先看最近 `24h` 或 `7d` 趨勢
2. 找平常平均值與尖峰值
3. 先設保守一點
4. 觀察 1 到 2 週後再微調

實務建議：

- CPU / RAM / Disk
  - 比較適合固定門檻
- 網路流量
  - 比較適合「相對基線 + 最低絕對門檻」
- 狀態欄位
  - 比較適合直接判斷值是否異常

## 6. 一個完整範例：新增 NAS 容量面板

目標：

- 在 dashboard 顯示 `/volume1` 使用率、已用、可用、總容量

先查 metric：

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=hrStorageSize{job="snmp",instance="synology-nas"}' | jq
```

PromQL 範例：

```promql
100 * (
  hrStorageUsed{job="snmp", instance="synology-nas", hrStorageDescr=~"/volume[0-9]+"}
  /
  hrStorageSize{job="snmp", instance="synology-nas", hrStorageDescr=~"/volume[0-9]+"}
)
```

## 7. 更進階的告警設計範例集

### 範例 A：CPU / RAM / Disk 固定門檻型

適合：

- CPU 使用率
- 記憶體使用率
- 磁碟使用率

範例：

```promql
100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{job="node-exporter", mode="idle"}[5m]))) > 85
```

設計建議：

- `for:` 通常用 `5m` 到 `10m`
- CPU / RAM 通常先做 `warning`
- Disk 依剩餘空間決定 `warning` 或 `critical`

### 範例 B：網路流量異常尖峰型

適合：

- NAS / Router
- 某條 WAN / LAN 介面

範例：

```promql
sum by (instance) (
  rate(ifHCInOctets{job="snmp", instance="synology-nas", ifDescr=~"eth[0-9]+"}[5m]) * 8
)
>
clamp_min(
  avg_over_time((
    sum by (instance) (
      rate(ifHCInOctets{job="snmp", instance="synology-nas", ifDescr=~"eth[0-9]+"}[5m]) * 8
    )
  )[1h:5m]) * 3,
  200000000
)
```

設計建議：

- `3 倍` 是不錯的起點
- 再加一個絕對下限，例如 `200 Mbps`
- `for:` 建議先用 `5m`
- 介面一定要先挑對

### 範例 C：狀態值異常型

適合：

- 磁碟健康
- RAID 狀態
- 服務啟用 / 停用狀態

範例：

```promql
diskHealthStatus{job="snmp"} != bool 1
```

設計建議：

- 很適合搭配 `table` panel
- 健康時若會回空集合，優先考慮 `bool`
- `for:` 可以略長，例如 `10m`

### 範例 D：可達性 / 存活型

適合：

- exporter / SNMP target
- HTTP / TCP / ICMP probe

範例：

```promql
up{job=~"node-exporter|windows-exporter|snmp"} < 1
```

或：

```promql
probe_success < 1
```

設計建議：

- 最常見誤報來源是短暫網路抖動
- `for:` 通常不要小於 `2m`

### 範例 E：家用 AP 的間接監控

情境：

- 例如 `TP-Link Deco X20` 這類家用 AP 不一定支援 SNMP
- 但你還是想知道它有沒有活著，以及 uplink 流量大不大

做法：

1. 用 `ICMP probe` 監控 AP 在線狀態
2. 用 `ER-X` 的介面流量，間接看它連接的 uplink port

ICMP 目標範例：

```yaml
- targets: ["192.168.1.50"]
  labels:
    service: tplink-x20-ping
    role: access-point
    site: home
```

ER-X uplink PromQL 範例：

```promql
rate(ifHCInOctets{job="snmp", instance="erx-router", ifDescr="eth2"}[5m]) * 8
```

```promql
rate(ifHCOutOctets{job="snmp", instance="erx-router", ifDescr="eth2"}[5m]) * 8
```

## 8. 從 dashboard query 轉成 alert query

這是最實用的一招。

1. 先找到 panel 裡的 `expr`
2. 確認 query 本身有資料
3. 想清楚你要告警的是固定門檻、相對基線，還是狀態異常
4. 再把它放進 alert rule

### 例子 1：從使用率圖表變成高使用率告警

dashboard query：

```promql
100 * (
  hrStorageUsed{job="snmp", instance=~"$device", hrStorageDescr=~"/volume[0-9]+"}
  /
  hrStorageSize{job="snmp", instance=~"$device", hrStorageDescr=~"/volume[0-9]+"}
)
```

alert query：

```promql
100 * (
  hrStorageUsed{job="snmp", instance="synology-nas", hrStorageDescr=~"/volume[0-9]+"}
  /
  hrStorageSize{job="snmp", instance="synology-nas", hrStorageDescr=~"/volume[0-9]+"}
) > 85
```

### 例子 2：從流量圖表變成尖峰告警

dashboard query：

```promql
sum by (instance) (rate(ifHCInOctets{job="snmp", instance=~"$device"}[5m]) * 8)
```

alert query 的思路：

- 不要直接拿去做固定門檻
- 先補介面篩選
- 再補 `avg_over_time` 基線與 `clamp_min`

## 9. 新增 alert rule 時每個欄位怎麼想

每條規則都可以當成回答這 6 個問題：

1. 我要監控哪個值？
   - `expr`
2. 什麼時候算異常？
   - 比較條件或 PromQL 本身
3. 要連續多久才算真的異常？
   - `for:`
4. 通知時怎麼讓人一眼看懂？
   - `summary`
5. 要補充什麼背景？
   - `description`
6. 嚴重度是什麼？
   - `labels.severity`

簡化骨架：

```yaml
- uid: example_rule
  title: ExampleAlert
  condition: B
  data:
    - refId: A
      datasourceUid: prometheus
      model:
        expr: your_promql_here
        instant: true
        refId: A
    - refId: B
      datasourceUid: __expr__
      model:
        expression: A
        refId: B
        type: classic_conditions
  noDataState: OK
  executionErrorState: Error
  for: 5m
  annotations:
    summary: "..."
    description: "..."
  labels:
    severity: warning
```

## 10. 修改後怎麼驗證自己沒改壞

至少做這幾步：

1. `make validate`
2. 打開 Grafana 確認 panel 沒有 `No data` / `Error`
3. 打開 Prometheus 確認 query 有資料
4. 打開 Grafana `Alerting` 頁面確認規則已載入
5. 必要時做一次刻意測試

## 11. 最常踩的坑

- 直接把所有網卡加總
  - 很容易把同一筆流量重複計算
- 沒先查 Prometheus 就直接改 dashboard
  - 容易浪費時間
- `for:` 設太短
  - 容易被瞬間尖峰洗版
- `summary` 寫太抽象
  - Telegram 收到時看不出哪台主機、哪個 volume、哪條介面
- `NoData` 跟 `OK` 沒分清楚
  - 有些規則健康時本來就可能回空集合
- 忘了重載 Grafana
  - 改完 provisioning 或 dashboard JSON 後不會自動套用
