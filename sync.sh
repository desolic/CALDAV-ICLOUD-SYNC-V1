#!/bin/bash
set -e

CONFIG_DIR="/config"
CONFIG_PATH="$CONFIG_DIR/config"
TEMPLATE_PATH="/config.template"
STATUS_DIR="$CONFIG_DIR/status"
LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/sync.log"

echo "🟢 Container gestartet"

# Logs- und Statusverzeichnis erstellen
mkdir -p "$LOG_DIR"
echo "✅ Logs-Verzeichnis erstellt: $LOG_DIR"
mkdir -p "$STATUS_DIR"
echo "✅ Status-Verzeichnis erstellt: $STATUS_DIR"

# Config erzeugen
if [ ! -f "$CONFIG_PATH" ]; then
    echo "⚙️  Keine Config gefunden, erstelle aus Template..." | tee -a "$LOG_FILE"

    if [ ! -f "$TEMPLATE_PATH" ]; then
        echo "❌ Config-Template nicht gefunden: $TEMPLATE_PATH" | tee -a "$LOG_FILE"
        exit 1
    fi

    # Platzhalter mit Variablen ersetzen
    envsubst '${APPLE_ID} ${APPLE_APP_PASSWORD} ${SYNOLGY_CALDAV_URL} ${SYNOLGY_USER} ${SYNOLGY_PASSWORD}' \
        < "$TEMPLATE_PATH" > "$CONFIG_PATH"

    echo "✅ Config erstellt: $CONFIG_PATH" | tee -a "$LOG_FILE"
fi

echo "🔍 Inhalt der Config:"
cat "$CONFIG_PATH" | tee -a "$LOG_FILE"

# Bidirektionalen Sync starten (iCloud gewinnt bei Konflikten)
echo "🚀 Starte bidirektionalen Sync alle 30 Sekunden ..." | tee -a "$LOG_FILE"

while true; do
    echo "🔄 Sync gestartet: $(date)" | tee -a "$LOG_FILE"
    vdirsyncer sync icloud-synology --force-a --config "$CONFIG_PATH" 2>&1 | tee -a "$LOG_FILE"
    echo "✅ Sync abgeschlossen" | tee -a "$LOG_FILE"
    echo "⏱ Warte 30 Sekunden ..." | tee -a "$LOG_FILE"
    sleep 30
done