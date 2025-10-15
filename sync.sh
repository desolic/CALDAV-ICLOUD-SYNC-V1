#!/bin/bash

# Pfade
CONFIG_DIR="/config"
CONFIG_PATH="$CONFIG_DIR/config"
TEMPLATE_PATH="/config.template"
STATUS_DIR="$CONFIG_DIR/status"
LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/sync.log"

# Logs-Verzeichnis erstellen
mkdir -p "$LOG_DIR"
[ -d "$LOG_DIR" ] && echo "✅ Logs-Verzeichnis erstellt: $LOG_DIR" || { echo "❌ Logs-Verzeichnis konnte nicht erstellt werden: $LOG_DIR"; exit 1; }

# Log-Datei definieren
touch "$LOG_FILE" || { echo "❌ Log-Datei konnte nicht erstellt werden: $LOG_FILE"; exit 1; }
echo "✅ Log-Datei bereit: $LOG_FILE"

# Container-Startmeldung
echo "🚀 Initialisiert am $(date)" | tee -a "$LOG_FILE"

# Status-Verzeichnis erstellen
mkdir -p "$STATUS_DIR" && echo "✅ Status-Verzeichnis erstellt: $STATUS_DIR" | tee -a "$LOG_FILE"

# Config erstellen oder aktualisieren
if [ ! -f "$CONFIG_PATH" ]; then
    echo "⚙️  Keine Config gefunden, erstelle aus Template..." | tee -a "$LOG_FILE"
    [ -f "$TEMPLATE_PATH" ] || { echo "❌ Config-Template nicht gefunden: $TEMPLATE_PATH" | tee -a "$LOG_FILE"; exit 1; }
    command -v envsubst >/dev/null || { echo "❌ envsubst nicht gefunden, bitte gettext installieren" | tee -a "$LOG_FILE"; exit 1; }
    envsubst '${APPLE_ID} ${APPLE_APP_PASSWORD} ${SYNOLGY_CALDAV_URL} ${SYNOLGY_USER} ${SYNOLGY_PASSWORD}' < "$TEMPLATE_PATH" > "$CONFIG_PATH" \
        && echo "✅ Config erstellt: $CONFIG_PATH" | tee -a "$LOG_FILE"
fi

# Prüfen ob Config lesbar ist
[ -r "$CONFIG_PATH" ] || { echo "❌ Config nicht lesbar: $CONFIG_PATH" | tee -a "$LOG_FILE"; exit 1; }

# vdirsyncer Standardpfad vorbereiten
mkdir -p /root/.config/vdirsyncer && echo "✅ vdirsyncer Config-Ordner erstellt" | tee -a "$LOG_FILE"
ln -sf "$CONFIG_PATH" /root/.config/vdirsyncer/config && echo "✅ Symlink gesetzt: /root/.config/vdirsyncer/config -> $CONFIG_PATH" | tee -a "$LOG_FILE"

# Debug: Erste 5 Zeilen der Config
echo "🔍 Erste 5 Zeilen der Config:" | tee -a "$LOG_FILE"
[ -s "$CONFIG_PATH" ] && head -n 5 "$CONFIG_PATH" | tee -a "$LOG_FILE"

# Prüfen ob vdirsyncer verfügbar ist
command -v vdirsyncer >/dev/null 2>&1 || { echo "❌ vdirsyncer nicht gefunden" | tee -a "$LOG_FILE"; exit 1; }

# Einmalige Discovery nur beim ersten Start
if [ ! -f "$STATUS_DIR/discovery_done" ]; then
    echo "🔍 Discovery gestartet..." | tee -a "$LOG_FILE"
    DISCOVER_OUTPUT=$(vdirsyncer discover icloud_synology 2>&1)
    echo "$DISCOVER_OUTPUT" | tee -a "$LOG_FILE"
    [ $? -ne 0 ] && { echo "❌ Discovery fehlgeschlagen" | tee -a "$LOG_FILE"; exit 1; }

    # iCloud-Kalender auflisten
    echo "Bitte wähle die iCloud-Kalender aus (Mehrfachauswahl durch Komma getrennt):"
    ICLOUD_IDS=()
    i=1
    declare -A ICLOUD_MAP
    while read -r line; do
        CAL_ID=$(echo "$line" | awk '{print $1}')
        CAL_NAME=$(echo "$line" | sed -n 's/.*("\(.*\)").*/\1/p')
        [ -n "$CAL_ID" ] && [ -n "$CAL_NAME" ] && echo "[$i] $CAL_NAME" && ICLOUD_MAP[$i]="$CAL_ID" && ((i++))
    done < <(echo "$DISCOVER_OUTPUT" | grep -A20 'iCloud:' | grep '"')

    read -p "Nummern der iCloud-Kalender: " INPUT
    [ -z "$INPUT" ] && { echo "Keine Auswahl getroffen, Discovery abgebrochen" | tee -a "$LOG_FILE"; exit 1; }

    COLLECTIONS=()
    for NUM in $(echo "$INPUT" | tr ',' ' '); do
        ICAL=${ICLOUD_MAP[$NUM]}
        echo "Wähle den Synology-Zielkalender für $ICAL:"
        j=1
        declare -A SYNO_MAP
        while read -r line; do
            SYNO_ID=$(echo "$line" | awk '{print $1}')
            SYNO_NAME=$(echo "$line" | sed -n 's/.*("\(.*\)").*/\1/p')
            [ -n "$SYNO_ID" ] && [ -n "$SYNO_NAME" ] && echo "[$j] $SYNO_NAME" && SYNO_MAP[$j]="$SYNO_ID" && ((j++))
        done < <(echo "$DISCOVER_OUTPUT" | grep -A20 'Synology:' | grep '"')

        read -p "Nummer des Zielkalenders: " SYN_NUM
        [ -z "$SYN_NUM" ] && { echo "Keine Auswahl getroffen, Discovery abgebrochen" | tee -a "$LOG_FILE"; exit 1; }
        COLLECTIONS+=("[\"$ICAL\",\"${SYNO_MAP[$SYN_NUM]}\"]")
    done

    # Collections in Config schreiben
    sed -i '/collections = /c\collections = ['"$(IFS=, ; echo "${COLLECTIONS[*]}")"']' "$CONFIG_PATH"
    echo "✅ Discovery abgeschlossen, Config aktualisiert" | tee -a "$LOG_FILE"

    touch "$STATUS_DIR/discovery_done"
fi

# Bidirektionaler Sync starten
echo "🚀 Starte bidirektionalen Sync alle 30 Sekunden ..." | tee -a "$LOG_FILE"

while true; do
    echo "🔄 Sync gestartet: $(date)" | tee -a "$LOG_FILE"
    SYNC_OUTPUT=$(vdirsyncer sync icloud_synology 2>&1) || true
    SYNC_EXIT_CODE=$?
    echo "$SYNC_OUTPUT" | tee -a "$LOG_FILE"
    if [ $SYNC_EXIT_CODE -eq 0 ] && ! echo "$SYNC_OUTPUT" | grep -qiE 'critical:|error:|warning:'; then
        echo "✅ Sync erfolgreich abgeschlossen: $(date)" | tee -a "$LOG_FILE"
    else
        echo "❌ Sync fehlgeschlagen: $(date)" | tee -a "$LOG_FILE"
        echo "⚠️ Bitte Fehlerausgabe prüfen" | tee -a "$LOG_FILE"
    fi
    [ ! -d "$STATUS_DIR" ] || [ ! -w "$STATUS_DIR" ] && echo "❌ Status-Ordner nicht vorhanden oder nicht beschreibbar: $STATUS_DIR" | tee -a "$LOG_FILE" || echo "✅ Status-Ordner OK: $STATUS_DIR" | tee -a "$LOG_FILE"
    echo "⚙️ Warten 30 Sekunden ..." | tee -a "$LOG_FILE"
    sleep 30
done
