#!/bin/bash
set -e

CONFIG_PATH="/config/config"
TEMPLATE_PATH="/config.template"
LOG_DIR="/config/logs"

# Log-Verzeichnis anlegen
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/sync.log"

# Erstkonfiguration erstellen, falls nicht vorhanden
if [ ! -f "$CONFIG_PATH" ]; then
    echo "⚙️  Keine Konfiguration gefunden, erstelle neue aus Template ..." | tee -a "$LOG_FILE"
    cp "$TEMPLATE_PATH" "$CONFIG_PATH"

    # Platzhalter ersetzen
    sed -i "s|\${APPLE_ID}|${APPLE_ID}|g" "$CONFIG_PATH"
    sed -i "s|\${APPLE_APP_PASSWORD}|${APPLE_APP_PASSWORD}|g" "$CONFIG_PATH"
    sed -i "s|\${SYNOLGY_CALDAV_URL}|${SYNOLGY_CALDAV_URL}|g" "$CONFIG_PATH"
    sed -i "s|\${SYNOLGY_USER}|${SYNOLGY_USER}|g" "$CONFIG_PATH"
    sed -i "s|\${SYNOLGY_PASSWORD}|${SYNOLGY_PASSWORD}|g" "$CONFIG_PATH"

    echo "🔍 Führe automatische iCloud-Discovery durch ..." | tee -a "$LOG_FILE"
    vdirsyncer discover 2>&1 | tee -a "$LOG_FILE" || echo "⚠️  Discovery konnte nicht abgeschlossen werden, bitte Config prüfen." | tee -a "$LOG_FILE"
fi

echo "🚀 Starte bidirektionalen Synchronisation alle 30 Sekunden ..." | tee -a "$LOG_FILE"
while true; do
    echo "🔄 Sync gestartet: $(date)" | tee -a "$LOG_FILE"
    vdirsyncer sync icloud-synology 2>&1 | tee -a "$LOG_FILE"
    echo "⏱ Warten 30 Sekunden ..." | tee -a "$LOG_FILE"
    sleep 30
done
