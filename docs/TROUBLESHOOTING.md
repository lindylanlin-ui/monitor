# 查修手冊

這份文件是給未來維護時快速排錯用的。

重點不是只告訴你「哪裡壞了」，而是告訴你：

- 先看哪裡
- 要下什麼指令
- 要看哪些 log / metrics / labels
- 看到什麼代表正常
- 看到什麼代表根因可能在哪裡

如果你是第一次部署，先看 [README.md](/home/tuffy/project/monitor/README.md:1)。
如果你想知道每個設定檔的用途，再搭配 [CONFIG-REFERENCE.md](/home/tuffy/project/monitor/docs/CONFIG-REFERENCE.md:1) 一起看。

目前版本的正式告警流程是 `Grafana Alerting + Telegram`，不是 `Alertmanager`。

## 0. 新舊告警架構快速判斷表

| 你現在看到的東西 | 代表哪一套架構 | 現在是否正式生效 | 你應該改哪裡 |
| --- | --- | --- | --- |
| Grafana `Alerting` 頁面裡的規則、Contact point、Notification policy | `Grafana Alerting + Telegram` | 是 | `grafana/provisioning/alerting/rules.yml`、`grafana/provisioning/alerting/templates.yml`、`grafana/templates/contact-points.yml.tpl` |
| Telegram 是由 Grafana 測試通知送出成功 | `Grafana Alerting + Telegram` | 是 | `secrets/grafana-alerting/*` 與 Grafana provisioning |
| `prometheus/rules/infrastructure-alerts.yml` | 舊版 `Prometheus rule_files + Alertmanager` | 否 | 通常不用改，除非你要回切舊架構 |
| `alertmanager/alertmanager.yml` | 舊版 `Prometheus rule_files + Alertmanager` | 否 | 目前可忽略，除非你要重新啟用 Alertmanager |
| 想改 CPU / RAM / Disk 告警閥值 | `Grafana Alerting + Telegram` | 是 | `grafana/provisioning/alerting/rules.yml` |
| 想改告警要持續多久才送出 | `Grafana Alerting + Telegram` | 是 | `grafana/provisioning/alerting/rules.yml` 內的 `for:` |
| 想改 Telegram 訊息格式 | `Grafana Alerting + Telegram` | 是 | `grafana/provisioning/alerting/templates.yml` |
| 想改 Telegram bot token / chat id | `Grafana Alerting + Telegram` | 是 | `secrets/grafana-alerting/telegram_bot_token`、`secrets/grafana-alerting/telegram_chat_id` |

快速記憶版本：

- 看到 `Grafana Alerting` 頁面與 `grafana/provisioning/alerting/*`，就是現在正式在用的。
- 看到 `prometheus/rules/*` 跟 `alertmanager/*`，就是舊架構留下來的歷史參考。

## 1. 查修的大方向

建議每次都照這個順序查：

1. 先看容器有沒有起來
2. 再看 Prometheus target 是不是 `UP`
3. 再看 exporter / service 本身有沒有吐資料
4. 再看 Grafana 查詢條件有沒有對到資料
5. 最後才回頭改設定檔

這樣比較不容易一開始就改錯方向。

## 2. 第一層：容器與服務是否存活

### 看整體容器狀態

```bash
docker compose ps
```

你要看：

- `STATUS` 是否為 `Up`
- 有沒有容器一直 `Restarting`
- `healthy` 是否正常

如果某個服務沒起來，先看它的 log：

```bash
docker compose logs -f prometheus
docker compose logs -f grafana
docker compose logs -f cadvisor
docker compose logs -f snmp-exporter
```

如果想一次看全部：

```bash
make logs
```

## 3. 第二層：Prometheus 有沒有抓到 target

先打開：

- `http://localhost:9090/targets`

你要看：

- `windows-exporter`
- `snmp`
- `node-exporter`
- `cadvisor`
- `blackbox-http`
- `blackbox-tcp`

是否都是 `UP`。

如果你想用指令查：

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=up'
```

如果只想查某個 job：

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=up{job="cadvisor"}' | jq
```

判讀方式：

- 回傳 `"1"` 代表 target 正常
- 回傳 `"0"` 代表 Prometheus 抓不到
- 沒結果代表 job 名稱、label 或資料本身有問題

## 4. 第三層：Exporter 本身有沒有吐出 metrics

如果 target 是 `UP`，但 Grafana 還是 `No data`，下一步就不是看 target，而是看 exporter 有沒有真的吐出你要的 metrics。

### 查有哪些 metrics 名稱

```bash
curl -fsS 'http://127.0.0.1:9090/api/v1/label/__name__/values' | jq -r '.data[]'
```

例如只看容器 metrics：

```bash
curl -fsS 'http://127.0.0.1:9090/api/v1/label/__name__/values' | jq -r '.data[]' | rg '^container_'
```

這一步是在確認：

- exporter 有沒有吐出這類 metrics
- 儀表板查的 metrics 名稱是不是根本不存在

### 直接查某個 metrics

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=container_last_seen{job="cadvisor"}' | jq
```

如果有資料，代表 Prometheus 真的有抓到這個 metrics。

## 5. 第四層：Grafana `No data` 的標準查法

Grafana 顯示 `No data` 時，最常見原因不是「Grafana 壞了」，而是下面幾種：

- Prometheus 沒資料
- metrics 名稱不對
- label 篩選條件不對
- dashboard 變數選到沒有資料的值

建議這樣查：

1. 先打開 Grafana 該面板的 `Edit`
2. 看它實際查的 PromQL
3. 把 PromQL 複製到 Prometheus Web UI 測
4. 如果有變數，例如 `$compose_project`，先代入實際值再測

### 你要看哪個檔案

Grafana dashboard JSON 在：

- [grafana/dashboards/infrastructure-overview.json](/home/tuffy/project/monitor/grafana/dashboards/infrastructure-overview.json:1)
- [grafana/dashboards/docker-compose-overview.json](/home/tuffy/project/monitor/grafana/dashboards/docker-compose-overview.json:1)
- [grafana/dashboards/network-edge-and-nas.json](/home/tuffy/project/monitor/grafana/dashboards/network-edge-and-nas.json:1)

如果你想知道面板用途，可看：

- [grafana/dashboards/README.md](/home/tuffy/project/monitor/grafana/dashboards/README.md:1)

## 6. 本次案例：`Docker Compose Overview` 全部 `No data` 要怎麼查

這次我們實際就是這樣查的。

### 第 1 步：先看 cAdvisor 是否活著

```bash
docker compose ps
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=up{job="cadvisor"}' | jq
```

判讀：

- `up{job="cadvisor"} = 1` 代表 Prometheus 抓得到 cAdvisor
- 如果這一步就失敗，先不要看 Grafana

### 第 2 步：看 dashboard 查了哪些條件

這個面板主要查的是：

- `container_last_seen`
- `container_cpu_usage_seconds_total`
- `container_memory_working_set_bytes`
- `container_network_receive_bytes_total`
- `container_network_transmit_bytes_total`
- `container_start_time_seconds`

而且它會用這些 label 分組：

- `container_label_com_docker_compose_project`
- `container_label_com_docker_compose_service`

所以如果 cAdvisor 沒吐出這些 labels，面板就一定會 `No data`。

### 第 3 步：先確認容器 metrics 本身有沒有出現

```bash
curl -fsS 'http://127.0.0.1:9090/api/v1/label/__name__/values' | jq -r '.data[]' | rg '^container_'
```

如果有看到：

- `container_cpu_usage_seconds_total`
- `container_last_seen`
- `container_memory_working_set_bytes`

代表 cAdvisor 基本上有在工作。

### 第 4 步：查 compose labels 有沒有真的存在

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=count(container_cpu_usage_seconds_total{job="cadvisor",container_label_com_docker_compose_project!=""})' | jq
```

或：

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=count by (container_label_com_docker_compose_project) (container_last_seen{job="cadvisor"})' | jq
```

判讀：

- 有數字而且 label 不為空，代表 Grafana 面板理論上應該會有資料
- 如果 metrics 有，但 `compose_project` / `compose_service` 是空的，就表示 cAdvisor 沒拿到 Docker metadata

### 第 5 步：看 cAdvisor log 找根因

```bash
docker logs --tail 80 monitoring-cadvisor
```

這一步要找的重點字樣：

- `Registration of the docker container factory failed`
- `Registration of the containerd container factory failed`
- `Registration of the docker container factory successfully`

這次就是在 log 裡看到：

- 一開始 `docker factory failed`
- 後來補掛載後變成 `docker factory successfully`

這就可以很明確知道問題不在 Grafana，而在 cAdvisor 沒正確接上 Docker runtime。

### 第 6 步：查 Docker runtime 路徑

```bash
docker info --format '{{json .}}' | jq '{Driver, DockerRootDir, CgroupDriver, CgroupVersion, OperatingSystem}'
```

這一步是拿來看：

- Docker root dir 在哪裡
- 是否是 `systemd` cgroup
- 是不是 snap Docker

如果你是 snap Docker，很常需要注意：

- `DockerRootDir` 可能是 `/var/snap/docker/common/var-lib-docker`
- `containerd.sock` 可能在 `/run/snap.docker/containerd/containerd.sock`

### 第 7 步：查 cAdvisor 目前到底掛了哪些路徑

```bash
docker inspect monitoring-cadvisor --format '{{json .Mounts}}' | jq
```

這一步是在確認：

- `docker.sock` 有沒有掛進去
- `DockerRootDir` 有沒有掛對
- `containerd` 相關 socket 有沒有掛對

### 第 8 步：這次的實際修正

這次你的主機是 snap Docker，所以在 [docker-compose.yml](/home/tuffy/project/monitor/docker-compose.yml:113) 補了：

```yaml
- /run/snap.docker/containerd:/run/containerd:ro
```

補完後重啟：

```bash
docker compose up -d cadvisor
```

再回頭驗證：

```bash
docker logs --tail 30 monitoring-cadvisor
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=container_cpu_usage_seconds_total{job="cadvisor",container_label_com_docker_compose_project!=""}' | jq
```

如果回傳裡已經看得到：

- `container_label_com_docker_compose_project="monitor"`
- `container_label_com_docker_compose_service="prometheus"`

就代表這條線修好了。

## 7. Windows 面板 `No data` 怎麼查

### 第 1 步：先看 target 是否 UP

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=up{job="windows-exporter"}' | jq
```

### 第 2 步：直接打 exporter

在監控主機上測：

```bash
curl -fsS http://WINDOWS_IP:9182/metrics | head
```

你要看：

- 有沒有真的回 metrics
- 防火牆是否有放行 `9182/tcp`

### 第 3 步：查你面板查的 metrics 名稱對不對

例如：

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=windows_memory_physical_free_bytes' | jq
```

如果舊指標名稱沒資料、新指標有資料，就代表是 dashboard query 要更新。

## 8. SNMP 裝置一直 `DOWN` 怎麼查

### 先看 Prometheus target

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=up{job="snmp"}' | jq
```

### 再看 SNMP 設定對照

你要對照：

- `prometheus/file_sd/snmp-devices.local.yml`
- `snmp/auths.local.yml`

確認：

- `snmp_auth` 名稱有對上
- 裝置 IP 正確
- `modules` 適合那台設備

### 實機測 SNMP

SNMPv3：

```bash
snmpwalk -v3 -l authPriv -u 使用者名稱 -a SHA -A '認證密碼' -x AES -X '加密密碼' NAS_IP 1.3.6.1.2.1.1.1.0
```

SNMPv2c：

```bash
snmpwalk -v2c -c community ROUTER_IP 1.3.6.1.2.1.1.1.0
```

如果這一步都不通，Prometheus 也不會通。

## 9. Telegram 沒收到告警怎麼查

### 先看 bot 是否可用

```bash
TOKEN="$(cat secrets/grafana-alerting/telegram_bot_token)"
curl -s "https://api.telegram.org/bot${TOKEN}/getMe" | jq
```

### 再看 chat_id 是否正確

```bash
TOKEN="$(cat secrets/grafana-alerting/telegram_bot_token)"
curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates" | jq
```

注意：

- `getMe` 回的 `id` 是 bot 自己的 id，不是 chat id
- 你要找的是 `message.chat.id`

### 直接測試送訊息

```bash
TOKEN="$(cat secrets/grafana-alerting/telegram_bot_token)"
CHAT_ID="$(cat secrets/grafana-alerting/telegram_chat_id)"
curl -s "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=Telegram 測試訊息" | jq
```

如果有 `403 Forbidden`，通常代表：

- bot 還沒被你啟用對話
- chat id 填成 bot id
- 群組 / 私訊對象不對

### 看 Grafana Alerting log

```bash
docker compose logs -f grafana
```

### 用 Grafana 頁面直接測 Telegram

1. 左側進 `Alerting`
2. 進 `Notification configuration`
3. 右上角確認選的是 `Grafana`
4. 在 `Contact points` 找到 `telegram-monitoring`
5. 點 `View`
6. 在詳細頁按 `Test` 或 `Send test notification`

如果成功：

- Telegram 會收到一則測試通知
- Contact point 的狀態不再顯示 `Last delivery attempt failed`

如果失敗：

- 先看 Grafana UI 回傳的錯誤訊息
- 再看 `docker compose logs -f grafana`
- 檢查 `secrets/grafana-alerting/` 是否為真實值而不是 `replace-me...`

## 10. 常用查修指令速查表

### 容器狀態

```bash
docker compose ps
```

### 看某個服務 log

```bash
docker compose logs -f cadvisor
docker compose logs -f prometheus
docker compose logs -f grafana
```

### 查 Prometheus target 是否 UP

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=up' | jq
```

### 查某個 job

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=up{job="cadvisor"}' | jq
```

### 查有哪些 metrics

```bash
curl -fsS 'http://127.0.0.1:9090/api/v1/label/__name__/values' | jq -r '.data[]'
```

### 查某個 exporter 需要的 label

```bash
curl -fsS --get 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query=container_cpu_usage_seconds_total{job="cadvisor",container_label_com_docker_compose_project!=""}' | jq
```

### 看 cAdvisor 掛載

```bash
docker inspect monitoring-cadvisor --format '{{json .Mounts}}' | jq
```

### 看 Docker runtime 資訊

```bash
docker info --format '{{json .}}' | jq '{Driver, DockerRootDir, CgroupDriver, CgroupVersion, OperatingSystem}'
```

## 11. 什麼時候該看設定檔

如果你已經確認：

- 容器有正常啟動
- Prometheus target 是 `UP`
- exporter 也有吐出 metrics

但 Grafana 還是沒資料，這時再回頭看設定檔最有效率。

常看的檔案：

- [docker-compose.yml](/home/tuffy/project/monitor/docker-compose.yml:1)
- [prometheus/prometheus.yml](/home/tuffy/project/monitor/prometheus/prometheus.yml:1)
- [prometheus/file_sd/windows-hosts.yml](/home/tuffy/project/monitor/prometheus/file_sd/windows-hosts.yml:1)
- [prometheus/file_sd/snmp-devices.yml](/home/tuffy/project/monitor/prometheus/file_sd/snmp-devices.yml:1)
- [grafana/provisioning/alerting/rules.yml](/home/tuffy/project/monitor/grafana/provisioning/alerting/rules.yml:1)
- [grafana/templates/contact-points.yml.tpl](/home/tuffy/project/monitor/grafana/templates/contact-points.yml.tpl:1)
- [grafana/provisioning/datasources/datasource.yml](/home/tuffy/project/monitor/grafana/provisioning/datasources/datasource.yml:1)
- [grafana/provisioning/dashboards/dashboards.yml](/home/tuffy/project/monitor/grafana/provisioning/dashboards/dashboards.yml:1)

## 12. 最後的原則

看到 `No data` 不要第一時間就改 dashboard。

先問自己這 4 件事：

1. 服務有沒有起來？
2. Prometheus target 是不是 `UP`？
3. exporter 有沒有真的吐出這個 metrics？
4. dashboard 查詢條件有沒有篩掉資料？

照這個順序查，通常很快就能抓到根因。
