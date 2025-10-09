FROM python:3.11-slim

# Systemupdates und Sicherheitsfixes
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# vdirsyncer installieren
RUN pip install --no-cache-dir --upgrade pip setuptools vdirsyncer

# Arbeitsverzeichnis
WORKDIR /data

# Config-Verzeichnis vorbereiten
RUN mkdir -p /config

# Dateien kopieren
COPY sync.sh /usr/local/bin/sync.sh
COPY config.template /config.template

# Rechte setzen
RUN chmod +x /usr/local/bin/sync.sh

# VDIRSYNCER_CONFIG auf den gemounteten Ordner zeigen
ENV VDIRSYNCER_CONFIG=/config/config

# Startbefehl
CMD ["/usr/local/bin/sync.sh"]

