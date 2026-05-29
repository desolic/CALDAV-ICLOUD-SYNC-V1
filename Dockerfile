# Base-Image per Digest gepinnt (reproduzierbar). Aktualisieren via:
#   docker pull python:3.11-slim
#   docker inspect --format='{{index .RepoDigests 0}}' python:3.11-slim
FROM python:3.11-slim@sha256:a3ab0b966bc4e91546a033e22093cb840908979487a9fc0e6e38295747e49ac0

# vdirsyncer-Version pinnen (reproduzierbar)
ARG VDIRSYNCER_VERSION=0.20.0

# Systemupdates + minimale Laufzeitabhaengigkeiten
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
      ca-certificates \
      tini \
      gosu \
    && rm -rf /var/lib/apt/lists/*

# vdirsyncer (gepinnt) installieren
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir "vdirsyncer==${VDIRSYNCER_VERSION}"

# Unprivilegierter Benutzer; /config wird zur Laufzeit gemountet
RUN useradd --system --uid 10001 --create-home --home-dir /home/sync sync \
    && mkdir -p /config \
    && chown -R sync:sync /config /home/sync

# Skripte (root:root, nur lesbar/ausfuehrbar)
COPY sync.sh /usr/local/bin/sync.sh
COPY render_config.py /usr/local/bin/render_config.py
RUN chmod 0555 /usr/local/bin/sync.sh /usr/local/bin/render_config.py

VOLUME ["/config"]

# Sinnvolle Defaults (in der Synology-GUI ueberschreibbar)
ENV SYNC_INTERVAL=300 \
    COLLECTIONS_MODE=auto

# Healthcheck: Log wurde innerhalb von 2 Sync-Intervallen aktualisiert
HEALTHCHECK --interval=60s --timeout=10s --start-period=120s --retries=3 \
  CMD test -f /config/logs/sync.log \
      && [ "$(( $(date +%s) - $(stat -c %Y /config/logs/sync.log) ))" -lt "$(( ${SYNC_INTERVAL:-300} * 2 ))" ] || exit 1

# tini als PID1 (sauberes Signal-/Zombie-Handling); sync.sh droppt via gosu auf 'sync'
ENTRYPOINT ["tini", "--"]
CMD ["/usr/local/bin/sync.sh"]
