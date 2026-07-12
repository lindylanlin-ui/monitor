# AGENTS.md

本文件適用於整個 repository。此專案不是一般應用程式，而是一套以 Docker Compose 部署的 Prometheus、Grafana 與 exporter 監控平台；修改時應優先維持設定可重現、敏感資料不進版控，以及現有監控與告警不中斷。

## 專案概覽

- `docker-compose.yml`：服務、映像、網路、掛載與啟動參數。
- `.env.example`：可提交的環境變數範本；真實值放在被忽略的 `.env`。
- `prometheus/prometheus.yml`：scrape jobs、relabel 與 metrics 保留邏輯。
- `prometheus/file_sd/`：Prometheus target 清單。共用或示範設定可提交；站點專屬 target 應放在 `*.local.yml`。
- `prometheus/blackbox.yml`：HTTP、TCP、ICMP probe 模組。
- `snmp/modules.yml`：可提交的 SNMP 指標模組；認證資料放在 `snmp/auths.local.yml`。
- `grafana/dashboards/*.json`：由 provisioning 載入的 dashboard 來源檔。
- `grafana/provisioning/`：Grafana datasource、dashboard provider、告警規則與通知模板。
- `grafana/templates/contact-points.yml.tpl`：不含真實 token/chat ID 的 contact point 範本。
- `scripts/`：容器啟動時產生 SNMP 或 Grafana runtime 設定的 POSIX shell 腳本。
- `docs/`：建置、設定、擴充、dashboard 與查修文件；先從 `docs/INDEX.md` 找對應章節。

## 修改原則

1. 先閱讀 `README.md`、`docs/INDEX.md` 與需求相關的文件，再修改最小範圍。
2. 保留使用者現有的未提交變更；不要重排或重寫無關的 YAML、JSON 或文件。
3. 設定、dashboard、告警或操作流程改變時，同步更新相關 `docs/*.md`；使用者入口或常用指令改變時也更新 `README.md`。
4. 註解與使用者文件沿用繁體中文；服務名稱、label、metric、PromQL 與設定鍵保留其技術原名。
5. Shell 腳本必須相容 `/bin/sh`，維持 `set -eu`、正確引用變數，且不要把 secret 輸出到 stdout/stderr。
6. 除非任務明確要求，不要啟動、停止、重建服務，也不要清除 volume 或 runtime data。設定驗證不應改變正在運作的環境。

## 設定慣例

- 新增 Compose 環境變數時，同步補到 `.env.example` 並加上用途註解；不要把主機專屬值硬編碼進 `docker-compose.yml`。
- 映像版本維持明確 pin，並集中由 `.env.example` 的版本變數管理。
- 新增外部 target 時，使用既有 label 慣例：主機通常使用 `device`、`role`、`site`，probe 使用 `service`、`role`；確認 relabel 後的 `instance` 穩定且可讀。
- 真實 IP、內部 hostname、帳密或站點專屬設備清單放在被忽略的 `.local.yml` / `.env` / `secrets/`，提交內容只保留安全的範例。
- Grafana query 使用 datasource UID `prometheus`。修改 dashboard JSON 時保留既有 dashboard UID 與未涉及的 panel ID，確保 JSON 格式有效，並同步更新 `docs/DASHBOARDS.md`。
- 新增或修改告警前，先確認 PromQL 能回傳預期資料；規則應有清楚的名稱、合理的 `for`、severity label，以及可供通知閱讀的 `summary` / `description`。
- `grafana/provisioning/` 與 `grafana/templates/` 是可提交的來源；`grafana/runtime/` 是啟動時產生的結果，不可直接維護。
- `snmp/modules.yml` 與 `snmp/auths.example.yml` 不得包含真實 community、使用者或密碼；最終 `snmp/generated/snmp.yml` 不可提交或手改。

## 敏感與產生資料

不要新增、提交、覆寫或在輸出中揭露下列本機內容，除非使用者明確要求處理該資料：

- `.env`
- `*.local.yml`
- `secrets/`
- `grafana/data/`、`grafana/runtime/`
- `prometheus/data/`
- `snmp/generated/`
- `logs/` 中的執行記錄

需要新增可分享的設定時，修改對應的 example、template 或追蹤中的共用檔案，不要複製真實值。

## 驗證方式

依修改範圍執行最小但足夠的檢查：

```bash
# 所有修改至少執行
git diff --check

# Compose、環境變數或掛載有變動時
make validate

# Dashboard JSON 有變動時
jq empty grafana/dashboards/*.json

# Shell 腳本有變動時
sh -n scripts/*.sh
```

注意：`make validate` 會先執行 `make bootstrap`，在缺少本機檔案時建立被 Git 忽略的 placeholder 與資料夾。若 Docker 在目前環境不可用，應如實回報未執行的檢查，不要以修改設定或重啟服務來繞過。

若相關容器原本已在執行，而且任務允許查詢 runtime，可追加：

```bash
docker compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml
docker compose ps
```

不要只因為要驗證而執行 `docker compose down`、刪除資料，或強制重建整套服務。若必須套用 Grafana provisioning 或做實際 probe，先說明影響並限定到相關服務。

## 完成前檢查

- Diff 只包含任務需要的變更，沒有本機資料或 secret。
- YAML/JSON/shell 語法已依修改範圍檢查。
- Prometheus job、label、Grafana UID 與 datasource 引用保持一致。
- 行為改變已同步到 README 或 `docs/`。
- 最終回報列出已執行的驗證，以及因環境限制未執行的 runtime 驗證。
