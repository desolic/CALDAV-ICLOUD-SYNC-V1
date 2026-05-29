#!/usr/bin/env bash
set -euo pipefail
umask 077

# ---- Privilegien-Drop (Synology-Bind-Mounts) -------------------------------
# Als root gestartet: /config dem unprivilegierten User uebereignen, dann droppen.
PUID="${PUID:-10001}"
PGID="${PGID:-10001}"
if [ "$(id -u)" = "0" ]; then
  groupmod -o -g "$PGID" sync 2>/dev/null || true
  usermod -o -u "$PUID" sync 2>/dev/null || true
  mkdir -p /config
  chown -R sync:sync /config /home/sync
  exec gosu sync:sync "$0" "$@"
fi

# ---- Ab hier: unprivilegiert -----------------------------------------------
export HOME=/home/sync
CONFIG_DIR="/config"
STATUS_DIR="${CONFIG_DIR}/status"
LOG_DIR="${CONFIG_DIR}/logs"
LOG_FILE="${LOG_DIR}/sync.log"
VDIRSYNCER_DIR="${HOME}/.config/vdirsyncer"   # ephemer, NICHT auf dem Volume
CONFIG_PATH="${VDIRSYNCER_DIR}/config"
export VDIRSYNCER_CONFIG="${CONFIG_PATH}"

SYNC_INTERVAL="${SYNC_INTERVAL:-300}"         # Sekunden zwischen den Syncs
LOG_MAX_BYTES="${LOG_MAX_BYTES:-5242880}"     # 5 MiB, danach Rotation
LOG_KEEP="${LOG_KEEP:-3}"                      # Anzahl rotierter Dateien

mkdir -p "$STATUS_DIR" "$LOG_DIR" "$VDIRSYNCER_DIR"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" | tee -a "$LOG_FILE"
}

rotate_log() {
  [ -f "$LOG_FILE" ] || return 0
  local size
  size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
  [ "$size" -le "$LOG_MAX_BYTES" ] && return 0
  local i
  for ((i = LOG_KEEP - 1; i >= 1; i--)); do
    [ -f "${LOG_FILE}.$i" ] && mv -f "${LOG_FILE}.$i" "${LOG_FILE}.$((i + 1))" || true
  done
  mv -f "$LOG_FILE" "${LOG_FILE}.1"
  : >"$LOG_FILE"
}

trap 'log "🛑 Beendet ($(date))"; exit 0' TERM INT

log "🚀 Initialisiert ($(date)) - User $(id -un) ($(id -u):$(id -g))"

# ---- Config erzeugen (chmod 600, keine Klartext-Persistenz auf dem Volume) --
log "🔐 Erzeuge vdirsyncer-Config ..."
if ! python3 /usr/local/bin/render_config.py >"$CONFIG_PATH"; then
  log "❌ Config-Erzeugung fehlgeschlagen (siehe Fehler oben)."
  exit 1
fi
chmod 600 "$CONFIG_PATH"

# ---- Discovery (nicht-interaktiv; listet Kalender fuers GUI-Log) ------------
log "🔎 Discovery ..."
if ! discover_out=$(vdirsyncer discover icloud_synology 2>&1); then
  log "❌ Discovery fehlgeschlagen - Zugangsdaten/URL pruefen:"
  log "$discover_out"
  exit 1
fi
log "$discover_out"
log "ℹ️  Kalenderauswahl via COLLECTIONS / COLLECTION_MAPPING (GUI-Umgebungsvariablen)."

# ---- Sync-Loop --------------------------------------------------------------
log "🔁 Sync-Loop (Intervall ${SYNC_INTERVAL}s, Modus ${COLLECTIONS_MODE:-auto})"
while true; do
  rotate_log
  log "🔄 Sync gestartet"
  if sync_out=$(vdirsyncer sync icloud_synology 2>&1); then
    rc=0
  else
    rc=$?
  fi
  log "$sync_out"
  if [ "$rc" -eq 0 ] && ! grep -qiE 'error|critical' <<<"$sync_out"; then
    log "✅ Sync ok"
  else
    log "❌ Sync mit Fehlern (rc=$rc)"
  fi
  # sleep im Hintergrund + wait, damit SIGTERM den Loop sofort unterbricht
  sleep "$SYNC_INTERVAL" &
  wait $!
done
