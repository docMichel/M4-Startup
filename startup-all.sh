#!/bin/bash
# Script master qui lance tous les services

LOG_DIR="/tmp/startup-logs"
LOG_FILE="$LOG_DIR/startup-all-$(date +%Y%m%d-%H%M%S).log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "===== DÉMARRAGE STARTUP-ALL ====="
log "User: $(whoami)"
log "Script dir: $SCRIPT_DIR"

# 1. Montages
log "--- MONTAGES ---"
"$SCRIPT_DIR/starters/mount-all.sh" 2>&1 | tee -a "$LOG_FILE"

# 2. Attendre que les montages soient prêts
sleep 5
log "--- OLLAMA ---"
"$SCRIPT_DIR/starters/start-ollama.sh" 2>&1 | tee -a "$LOG_FILE" &
sleep 5


# 3. Lancer les services
log "--- SERVICES ---"
"$SCRIPT_DIR/starters/start-jellyfin.sh" 2>&1 | tee -a "$LOG_FILE" &
"$SCRIPT_DIR/starters/start-immich.sh" 2>&1 | tee -a "$LOG_FILE" &
"$SCRIPT_DIR/starters/start-flask.sh" 2>&1 | tee -a "$LOG_FILE" &

log "===== FIN STARTUP-ALL ====="
log "Logs dans: $LOG_DIR"