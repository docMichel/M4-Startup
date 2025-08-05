#!/bin/bash
# Script master qui lance tous les services

# Configuration globale
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export HOME=/Users/michel


LOG_DIR="/tmp/startup-logs"
LOG_FILE="$LOG_DIR/startup-all-$(date +%Y%m%d-%H%M%S).log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

wait_for_service() {
    local service_name=$1
    local check_command=$2
    local max_wait=${3:-20}
    local elapsed=0
    
    while [ $elapsed -lt $max_wait ]; do
        if eval "$check_command" > /dev/null 2>&1; then
            log "✓ $service_name OK après ${elapsed}s"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
        echo -n "." | tee -a "$LOG_FILE"
    done
    
    log ""
    log "✗ $service_name KO après ${max_wait}s"
    return 1
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
wait_for_service "Ollama" "curl -s http://localhost:11434/api/tags" 30


# 3. Lancer les services
log "--- SERVICES ---"

"$SCRIPT_DIR/starters/start-jellyfin.sh" 2>&1 | tee -a "$LOG_FILE" &
wait_for_service "Jellyfin" "curl -s http://localhost:8096" 30

"$SCRIPT_DIR/starters/start-immich.sh" 2>&1 | tee -a "$LOG_FILE" &
wait_for_service "Immich ML" "curl -s http://localhost:3003/ping || curl -s http://localhost:3003/docs | grep -q FastAPI" 30

# Attendre API
wait_for_service "Immich API" "curl -s http://localhost:2283/api/server/ping | grep -q pong" 60

# Attendre Web
wait_for_service "Immich Web" "curl -s http://localhost:3000" 30

# Attendre Microservices (optionnel, pas de endpoint direct)

log "✓ Immich complet"


"$SCRIPT_DIR/starters/start-flask.sh" 2>&1 | tee -a "$LOG_FILE" &
wait_for_service "Flask" "curl -s http://localhost:5000/api/health" 30


log "===== FIN STARTUP-ALL ====="
log "Logs dans: $LOG_DIR"