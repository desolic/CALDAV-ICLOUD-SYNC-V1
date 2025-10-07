#!/bin/bash

LOGFILE="/data/vdirsyncer.log"

echo "Starte vdirsyncer Synchronisation..." >> "$LOGFILE"

while true; do
    echo "Sync gestartet: $(date)" >> "$LOGFILE"
    vdirsyncer discover >> "$LOGFILE" 2>&1
    vdirsyncer sync >> "$LOGFILE" 2>&1
    echo "Sync beendet: $(date)" >> "$LOGFILE"
    sleep 30
done
