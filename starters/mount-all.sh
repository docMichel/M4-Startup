#!/bin/bash
LOG_FILE="/tmp/startup-logs/mount-$(date +%Y%m%d-%H%M%S).log"
HUB="192.168.0.11"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MOUNT: $1" | tee -a "$LOG_FILE"
}


# Attendre que le réseau soit prêt
log "Attente du réseau..."
for i in {1..30}; do
    if ping -c 1 -W 1 ${HUB} > /dev/null 2>&1; then
        log "✓ Réseau OK"
        break
    fi
    sleep 1
done


# SMB pour Jellyfin
#if ! mount | grep -q "/Users/michel/media-pool"; then
 if false; then
    log "Montage SMB..."
    mkdir -p /Users/michel/media-pool
   for attempt in 1 2 3; do
    if mount_smbfs //michel:trosque@${HUB}/media /Users/michel/media-pool 2>/dev/null; then
        log "✓ SMB monté (tentative $attempt)"
        break
    fi
    log "Tentative $attempt échouée, attente 5s..."
    sleep 5
done

else
    log "SMB déjà monté"
fi


# SMB pour Immich avec OPTIONS
if ! mount | grep -q "/Volumes/immich-hub"; then
    log "Montage SMB..."
    sudo mkdir -p /Volumes/immich-hub
    
    for attempt in 1 2 3; do
        if sudo mount_smbfs -o nobrowse,nodev,nosuid,soft //michel:HubPass2025@${HUB}/immich-pool /Volumes/immich-hub 2>/dev/null; then
            log "✓ SMB monté avec options (tentative $attempt)"
            break
        fi
        log "Tentative $attempt échouée, attente 5s..."
        sleep 5
    done

else
    log "SMB déjà monté"
fi


# NFS pour Immich
#if ! mount | grep -q "/Users/michel/mnt/immich-hub"; then
###    log "Montage NFS..."
#    mkdir -p /Users/michel/mnt/immich-hub
 #   /sbin/mount_nfs -o vers=3,tcp,hard,resvport 10.0.0.1:/mnt/immich-pool /Users/michel/mnt/immich-hub
 #   [ $? -eq 0 ] && log "✓ NFS monté" || log "✗ Erreur NFS"
#else
#    log "NFS déjà monté"
#fi