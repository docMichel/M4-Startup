#!/bin/bash
LOG_FILE="/tmp/startup-logs/jellyfin-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] JELLYFIN: $1" | tee -a "$LOG_FILE"
}

# Vérifier si déjà lancé
if pgrep -f "jellyfin" > /dev/null; then
    log "Déjà en cours (PID: $(pgrep -f jellyfin))"
    exit 0
fi

# Vérifier montage SMB
if ! mount | grep -q "/Users/michel/media-pool"; then
    log "ERREUR: SMB non monté"
    exit 1
fi

log "Démarrage..."

# Si on est root, lancer en tant que michel
if [ "$EUID" -eq 0 ]; then
    su - michel -c "export DOTNET_SYSTEM_IO_DISABLEFILELOCKING=1 && cd /Applications/Jellyfin.app/Contents/MacOS && ./jellyfin --webdir /Applications/Jellyfin.app/Contents/Resources/jellyfin-web" >> "$LOG_FILE" 2>&1 &
else
    # Sinon lancer directement
    export DOTNET_SYSTEM_IO_DISABLEFILELOCKING=1
    cd /Applications/Jellyfin.app/Contents/MacOS
    ./jellyfin --webdir /Applications/Jellyfin.app/Contents/Resources/jellyfin-web >> "$LOG_FILE" 2>&1 &
fi

sleep 5
if curl -s http://localhost:8096 > /dev/null; then
    log "✓ Jellyfin OK sur http://localhost:8096"
else
    log "✗ Jellyfin ne répond pas"
fi