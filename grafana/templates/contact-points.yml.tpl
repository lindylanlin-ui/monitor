# Grafana Alerting contact point 模板。
# 真正的 Telegram bot token / chat id 會在容器啟動時由腳本寫入 runtime provisioning，
# 因此這份模板可以安全地提交到 GitHub。
apiVersion: 1

contactPoints:
  - orgId: 1
    name: telegram-monitoring
    receivers:
      - uid: telegram_monitoring
        type: telegram
        settings:
          bottoken: "__GRAFANA_TELEGRAM_BOT_TOKEN__"
          chatid: "__GRAFANA_TELEGRAM_CHAT_ID__"
          message: |
            {{ template "telegram.monitoring.message" . }}
          uploadImage: false
        secure_settings:
          bottoken: "__GRAFANA_TELEGRAM_BOT_TOKEN__"
