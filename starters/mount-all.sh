#!/bin/bash
LOG_FILE="/tmp/startup-logs/mount-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MOUNT: $1" | tee -a "$LOG_FILE"
}

# SMB pour Jellyfin
if ! mount | grep -q "/Users/michel/media-pool"; then
    log "Montage SMB..."
    mkdir -p /Users/michel/media-pool
    mount_smbfs //michel:trosque@10.0.0.2/media /Users/michel/media-pool
    [ $? -eq 0 ] && log "✓ SMB monté" || log "✗ Erreur SMB"
else
    log "SMB déjà monté"
fi

# NFS pour Immich
if ! mount | grep -q "/Users/michel/mnt/immich-hub"; then
    log "Montage NFS..."
    mkdir -p /Users/michel/mnt/immich-hub
    /sbin/mount_nfs -o vers=3,tcp,hard,resvport 10.0.0.1:/mnt/immich-pool /Users/michel/mnt/immich-hub
    [ $? -eq 0 ] && log "✓ NFS monté" || log "✗ Erreur NFS"
else
    log "NFS déjà monté"
fi