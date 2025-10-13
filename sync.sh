#!/bin/bash
set -e

# Pfade
CONFIG_DIR="/config"
CONFIG_PATH="$CONFIG_DIR/config"
TEMPLATE_PATH="/config.template"
STATUS_DIR="$CONFIG_DIR/status"
LOG_DIR="$CONFIG_DIR/logs"

# Logs-Verzeichnis erstellen
mkdir -p "$LOG_DIR"
if [ -d "$LOG_DIR" ]; then
    echo "✅ Logs-Verzeichnis erstellt: $LOG_DIR"
else
    echo "❌ Logs-Verzeichnis konnte nicht erstellt werden: $LOG_DIR"
    exit 1
fi

# Log-Datei definieren
LOG_FILE="$LOG_DIR/sync.log"
touch "$LOG_FILE" || { echo "❌ Log-Datei konnte nicht erstellt werden: $LOG_FILE"; exit 1; }
echo "✅ Log-Datei bereit: $LOG_FILE"

# Status-Verzeichnis erstellen
mkdir -p "$STATUS_DIR"
if [ -d "$STATUS_DIR" ]; then
    echo "✅ Status-Verzeichnis erstellt: $STATUS_DIR" | tee -a "$LOG_FILE"
else
    echo "❌ Status-Verzeichnis konnte nicht erstellt werden: $STATUS_DIR" | tee -a "$LOG_FILE"
    exit 1
fi

# Config erstellen oder aktualisieren
if [ ! -f "$CONFIG_PATH" ]; then
    echo "⚙️  Keine Config gefunden, erstelle aus Template..." | tee -a "$LOG_FILE"

    if [ ! -f "$TEMPLATE_PATH" ]; then
        echo "❌ Config-Template nicht gefunden: $TEMPLATE_PATH" | tee -a "$LOG_FILE"
        exit 1
    fi

    # Config aus Template erzeugen und Variablen ersetzen
    if ! envsubst '${APPLE_ID} ${APPLE_APP_PASSWORD} ${SYNOLGY_CALDAV_URL} ${SYNOLGY_USER} ${SYNOLGY_PASSWORD}' < "$TEMPLATE_PATH" > "$CONFIG_PATH"; then
        echo "❌ Fehler beim Erstellen der Config: $CONFIG_PATH" | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "✅ Config erstellt: $CONFIG_PATH" | tee -a "$LOG_FILE"
else
    echo "ℹ️  Config bereits vorhanden: $CONFIG_PATH" | tee -a "$LOG_FILE"
fi

# Symlink für vdirsyncer setzen
mkdir -p /root/.config/vdirsyncer
ln -sf "$CONFIG_PATH" /root/.config/vdirsyncer/config
echo "✅ Symlink für vdirsyncer gesetzt: /root/.config/vdirsyncer/config -> $CONFIG_PATH" | tee -a "$LOG_FILE"

# Inhalt der Config ausgeben
echo "🔍 Inhalt der Config:" | tee -a "$LOG_FILE"
cat "$CONFIG_PATH" | tee -a "$LOG_FILE"

# Bidirektionalen Sync starten
echo "🚀 Starte bidirektionalen Sync alle 30 Sekunden ..." | tee -a "$LOG_FILE"

while true; do
    echo "🔄 Sync gestartet: $(date)" | tee -a "$LOG_FILE"

    if vdirsyncer sync icloud-synology --force-a --config "$CONFIG_PATH" 2>&1 | tee -a "$LOG_FILE"; then
        echo "✅ Sync erfolgreich abgeschlossen: $(date)" | tee -a "$LOG_FILE"
    else
        echo "❌ Fehler während des Syncs: $(date)" | tee -a "$LOG_FILE"
    fi

    echo "⏱ Warten 30 Sekunden ..." | tee -a "$LOG_FILE"
    sleep 30
done