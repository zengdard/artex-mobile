SHELL := /bin/bash
SERIAL ?= 192.168.1.12:5555
PREFIX := /data/data/com.termux/files/usr
PHONE_HOME := /data/data/com.termux/files/home
ADB := adb -s $(SERIAL)
RUNAS := run-as com.termux

.PHONY: deploy desktop start stop status logs ui doctor

deploy:
	./scripts/install-termux.sh

desktop:
	./install.sh desktop

start:
	$(ADB) shell '$(RUNAS) $(PREFIX)/bin/bash $(PHONE_HOME)/artex/scripts/start-termux.sh'

stop:
	$(ADB) shell '$(RUNAS) $(PREFIX)/bin/bash $(PHONE_HOME)/artex/scripts/stop-termux.sh'

status:
	$(ADB) shell '$(RUNAS) $(PREFIX)/bin/bash $(PHONE_HOME)/artex/scripts/status-termux.sh'

logs:
	$(ADB) shell '$(RUNAS) tail -n 80 $(PHONE_HOME)/artex/logs/artex.log'

ui:
	./scripts/open-ui.sh

doctor:
	@command -v adb >/dev/null || { echo "adb manquant"; exit 1; }
	@$(ADB) get-state || { echo "téléphone $(SERIAL) injoignable"; exit 1; }
	@echo "adb OK — $(SERIAL)"
