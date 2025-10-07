FROM python:3.11-slim

# Installiere vdirsyncer
RUN pip install --no-cache-dir vdirsyncer

# Arbeitsverzeichnis
WORKDIR /data

# Kopiere Config und Skript
COPY config /root/.vdirsyncer
COPY sync.sh /usr/local/bin/sync.sh
RUN chmod +x /usr/local/bin/sync.sh

# Startbefehl
CMD ["/usr/local/bin/sync.sh"]
