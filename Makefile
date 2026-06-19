SHELL := /bin/sh

.PHONY: bootstrap validate up down logs ps

bootstrap:
	@if [ ! -f .env ]; then cp .env.example .env; fi
	@if [ ! -f snmp/auths.local.yml ]; then cp snmp/auths.example.yml snmp/auths.local.yml; fi
	@if [ ! -f prometheus/file_sd/windows-hosts.local.yml ]; then printf '[]\n' > prometheus/file_sd/windows-hosts.local.yml; fi
	@if [ ! -f prometheus/file_sd/snmp-devices.local.yml ]; then printf '[]\n' > prometheus/file_sd/snmp-devices.local.yml; fi
	@mkdir -p secrets/alertmanager
	@if [ ! -f secrets/alertmanager/telegram_bot_token ]; then printf 'replace-me-with-your-telegram-bot-token\n' > secrets/alertmanager/telegram_bot_token; fi
	@if [ ! -f secrets/alertmanager/telegram_chat_id ]; then printf 'replace-me-with-your-telegram-chat-id\n' > secrets/alertmanager/telegram_chat_id; fi

validate: bootstrap
	docker compose config >/dev/null

up: bootstrap
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f --tail=200

ps:
	docker compose ps
