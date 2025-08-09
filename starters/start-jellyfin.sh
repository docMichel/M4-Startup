#!/bin/bash
LOG_FILE="/tmp/startup-logs/jellyfin-$(date +%Y%m%d-%H%M%S).log"

mkdir -p /tmp/startup-logs
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"  # Accessible en écriture par tous


log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] JELLYFIN: $1" | tee -a "$LOG_FILE"
}
# Au début de start-jellyfin.sh, après le log() :
if [ "$EUID" -eq 0 ]; then
    # Relancer tout le script en tant que michel
    exec su - michel -c "$0 $@"
fi

# Vérifier si déjà lancé
if pgrep -f "jellyfin" > /dev/null; then
    log "Déjà en cours (PID: $(pgrep -f jellyfin))"
    exit 0
fi

# Fonction pour monter SMB avec les bonnes permissions
mount_smb_optimized() {
    log "Vérification montage SMB..."
    
    # Démonter si déjà monté (pour remonter avec bonnes options)
    if mount | grep -q "/Users/michel/media-pool"; then
        log "Démontage SMB existant..."
        sudo umount -f /Users/michel/media-pool 2>/dev/null
        sleep 1
    fi
    
    # Créer le point de montage
    mkdir -p /Users/michel/media-pool
    
    # Monter avec options optimisées pour streaming vidéo
    log "Montage SMB optimisé..."
    
    # Options optimisées pour Jellyfin :
    # - nobrowse : pas de browsing Finder (plus rapide)
    # - f 0755 : force les permissions fichiers
    # - d 0755 : force les permissions dossiers
    
    if [ "$EUID" -eq 0 ]; then
        # Si root, utiliser mount_smbfs avec les bonnes options
        mount_smbfs -o nobrowse -f 0755 -d 0755 //michel:trosque@10.0.0.2/media /Users/michel/media-pool
    else
        # Si pas root, montage normal
        mount_smbfs -o nobrowse -f 0755 -d 0755 //michel:trosque@10.0.0.2/media /Users/michel/media-pool
    fi
    
    if [ $? -eq 0 ]; then
        log "✓ SMB monté avec succès"
        # Tester l'accès
        if ls /Users/michel/media-pool/ > /dev/null 2>&1; then
            log "✓ Accès SMB vérifié"
            return 0
        else
            log "⚠️ SMB monté mais accès refusé, tentative avec noperm..."
            sudo umount -f /Users/michel/media-pool 2>/dev/null
            mount_smbfs -o nobrowse,noperm //michel:trosque@10.0.0.2/media /Users/michel/media-pool
            return $?
        fi
    else
        log "✗ Échec montage SMB"
        return 1
    fi
}

# Monter ou vérifier SMB
mount_smb_optimized
if [ $? -ne 0 ]; then
    log "ERREUR: Impossible de monter SMB"
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