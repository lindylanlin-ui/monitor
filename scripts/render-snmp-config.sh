#!/bin/sh
set -eu

# 啟動時把驗證檔與模組檔合併成 snmp_exporter 可直接讀取的 snmp.yml。
# 若本機存在 auths.local.yml，就優先使用本機私密設定；
# 否則退回 example 檔，讓專案至少能啟動與驗證格式。
AUTH_FILE="/etc/snmp-config/auths.local.yml"
if [ ! -f "$AUTH_FILE" ]; then
  AUTH_FILE="/etc/snmp-config/auths.example.yml"
fi

mkdir -p /etc/snmp_exporter
TMP_FILE="$(mktemp)"

{
  printf '# Generated at container startup. Edit auths.local.yml for real credentials.\n'
  cat "$AUTH_FILE"
  printf '\n'
  cat /etc/snmp-config/modules.yml
} > "$TMP_FILE"

mv "$TMP_FILE" /etc/snmp_exporter/snmp.yml
