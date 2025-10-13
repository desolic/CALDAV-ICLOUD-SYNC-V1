#!/bin/bash
set -e

# Pfade
CONFIG_DIR="/config"
CONFIG_PATH="$CONFIG_DIR/config"
TEMPLATE_PATH="/config.template"
STATUS_DIR="$CONFIG_DIR/status"
LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/sync.log"

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

# Container-Startmeldung
echo "🚀 Initialisiert am $(date)" | tee -a "$LOG_FILE"

# Status-Verzeichnis erstellen
if mkdir -p "$STATUS_DIR"; then
    echo "✅ Status-Verzeichnis erstellt: $STATUS_DIR" | tee -a "$LOG_FILE"
else
    echo "❌ Fehler beim Erstellen des Status-Verzeichnisses: $STATUS_DIR" | tee -a "$LOG_FILE"
fi

# Config erstellen oder aktualisieren
if [ ! -f "$CONFIG_PATH" ]; then
    echo "⚙️  Keine Config gefunden, erstelle aus Template..." | tee -a "$LOG_FILE"

    if [ ! -f "$TEMPLATE_PATH" ]; then
        echo "❌ Config-Template nicht gefunden: $TEMPLATE_PATH" | tee -a "$LOG_FILE"
        exit 1
    fi

    # Prüfen, ob envsubst verfügbar ist
    if ! command -v envsubst &> /dev/null; then
        echo "❌ envsubst nicht gefunden, bitte gettext installieren" | tee -a "$LOG_FILE"
        exit 1
    fi

    # Config aus Template erzeugen, Variablen ersetzen
    if envsubst '${APPLE_ID} ${APPLE_APP_PASSWORD} ${SYNOLGY_CALDAV_URL} ${SYNOLGY_USER} ${SYNOLGY_PASSWORD}' < "$TEMPLATE_PATH" > "$CONFIG_PATH"; then
        echo "✅ Config erstellt: $CONFIG_PATH" | tee -a "$LOG_FILE"
    else
        echo "❌ Fehler beim Erstellen der Config: $CONFIG_PATH" | tee -a "$LOG_FILE"
        exit 1
    fi
else
    echo "ℹ️  Config bereits vorhanden: $CONFIG_PATH" | tee -a "$LOG_FILE"
fi

# Prüfen, ob Config lesbar ist
if [ ! -r "$CONFIG_PATH" ]; then
    echo "❌ Config nicht lesbar: $CONFIG_PATH" | tee -a "$LOG_FILE"
    exit 1
fi

# vdirsyncer Standardpfad vorbereiten
if mkdir -p /root/.config/vdirsyncer; then
    echo "✅ vdirsyncer Config-Ordner erstellt" | tee -a "$LOG_FILE"
else
    echo "❌ Fehler beim Erstellen von /root/.config/vdirsyncer" | tee -a "$LOG_FILE"
fi

if ln -sf "$CONFIG_PATH" /root/.config/vdirsyncer/config; then
    echo "✅ Symlink gesetzt: /root/.config/vdirsyncer/config -> $CONFIG_PATH" | tee -a "$LOG_FILE"
else
    echo "❌ Fehler beim Setzen des Symlinks" | tee -a "$LOG_FILE"
fi

# Debug: Nur die ersten 20 Zeilen der Config prüfen
echo "🔍 Erste 5 Zeilen der Config:" | tee -a "$LOG_FILE"
if [ -s "$CONFIG_PATH" ]; then
    head -n 5 "$CONFIG_PATH" | tee -a "$LOG_FILE"
else
    echo "⚠️ Config ist leer!" | tee -a "$LOG_FILE"
fi

# Prüfen ob vdirsyncer verfügbar ist
if ! command -v vdirsyncer &> /dev/null; then
    echo "❌ vdirsyncer nicht gefunden" | tee -a "$LOG_FILE"
    exit 1
fi

# Bidirektionalen Sync starten
echo "🚀 Starte bidirektionalen Sync alle 30 Sekunden ..." | tee -a "$LOG_FILE"

while true; do
    echo "🔄 Sync gestartet: $(date)" | tee -a "$LOG_FILE"

    # Sync ausführen, Output zwischenspeichern
    SYNC_OUTPUT=$(vdirsyncer sync icloud_synology 2>&1)
    SYNC_EXIT_CODE=$?

    # Ausgabe immer ins Log schreiben
    echo "$SYNC_OUTPUT" | tee -a "$LOG_FILE"

    # Erfolg nur melden, wenn Exit-Code 0
    if [ $SYNC_EXIT_CODE -eq 0 ]; then
        echo "✅ Sync erfolgreich abgeschlossen: $(date)" | tee -a "$LOG_FILE"
    else
        echo "❌ Sync fehlgeschlagen: $(date)" | tee -a "$LOG_FILE"
        echo "⚠️ Bitte Fehlerausgabe prüfen" | tee -a "$LOG_FILE"
    fi

    # Prüfen, ob Status-Ordner existiert und beschreibbar ist
    if [ ! -d "$STATUS_DIR" ] || [ ! -w "$STATUS_DIR" ]; then
        echo "❌ Status-Ordner nicht vorhanden oder nicht beschreibbar: $STATUS_DIR" | tee -a "$LOG_FILE"
    else
        echo "✅ Status-Ordner OK: $STATUS_DIR" | tee -a "$LOG_FILE"
    fi

    echo "⚙️ Warten 30 Sekunden ..." | tee -a "$LOG_FILE"
    sleep 30
done