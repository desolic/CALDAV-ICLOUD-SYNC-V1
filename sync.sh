#!/usr/bin/env bash
set -e

# Pfade
CONFIG_DIR="/config"
CONFIG_PATH="$CONFIG_DIR/config"
TEMPLATE_PATH="/config.template"
LOG_DIR="$CONFIG_DIR/logs"
STATUS_DIR="$CONFIG_DIR/status"

# Ordner erstellen
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$STATUS_DIR"
echo "✅ Ordner erstellt: $CONFIG_DIR, $LOG_DIR, $STATUS_DIR"

LOG_FILE="$LOG_DIR/sync.log"

# Config erstellen oder vorhandene Config verwenden
if [ ! -f "$CONFIG_PATH" ]; then
    echo "⚙️  Keine Konfiguration gefunden, erstelle neue aus Template ..." | tee -a "$LOG_FILE"
    
    # Variablen aus Template ersetzen und als config speichern
    envsubst < "$TEMPLATE_PATH" > "$CONFIG_PATH"
    echo "✅ Config aus Template erstellt: $CONFIG_PATH" | tee -a "$LOG_FILE"
    
    echo "🔍 Führe automatische iCloud-Discovery durch ..." | tee -a "$LOG_FILE"
    vdirsyncer discover --config "$CONFIG_PATH" 2>&1 | tee -a "$LOG_FILE" || \
        echo "⚠️  Discovery konnte nicht abgeschlossen werden, bitte Config prüfen." | tee -a "$LOG_FILE"
    echo "✅ Discovery abgeschlossen" | tee -a "$LOG_FILE"
else
    echo "ℹ️  Vorhandene Config gefunden: $CONFIG_PATH" | tee -a "$LOG_FILE"
fi

echo "🚀 Starte bidirektionalen Synchronisation alle 30 Sekunden ..." | tee -a "$LOG_FILE"

while true; do
    echo "🔄 Sync gestartet: $(date)" | tee -a "$LOG_FILE"
    
    # Synology gewinnt bei Konflikten
    vdirsyncer sync --config "$CONFIG_PATH" icloud-synology --force-b-direction 2>&1 | tee -a "$LOG_FILE"
    
    echo "✅ Sync abgeschlossen: $(date)" | tee -a "$LOG_FILE"
    echo "⏱ Warten 30 Sekunden ..." | tee -a "$LOG_FILE"
    sleep 30
done
