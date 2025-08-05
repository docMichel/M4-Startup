#!/bin/bash
# Vérifie si TOUS les services tournent, sinon les lance

LOG="/tmp/check-services-$(date +%Y%m%d-%H%M%S).log"

check_service() {
    local name=$1
    local check_cmd=$2
    
    if eval "$check_cmd" > /dev/null 2>&1; then
        echo "[$(date '+%H:%M:%S')] ✓ $name OK" | tee -a "$LOG"
        return 0
    else
        echo "[$(date '+%H:%M:%S')] ✗ $name KO" | tee -a "$LOG"
        return 1
    fi
}

# Vérifie chaque service
NEED_START=0

check_service "Jellyfin" "curl -s http://localhost:8096" || NEED_START=1
check_service "Ollama" "curl -s http://localhost:11434/api/tags" || NEED_START=1
check_service "Immich API" "curl -s http://localhost:2283/api/server/ping | grep -q pong" || NEED_START=1
check_service "Immich Web" "curl -s http://localhost:3000" || NEED_START=1
check_service "Flask" "curl -s http://localhost:5000/api/health" || NEED_START=1

# Si au moins un service est KO
if [ $NEED_START -eq 1 ]; then
    echo "[$(date '+%H:%M:%S')] Lancement des services..." | tee -a "$LOG"
    sudo /Users/michel/M4-startup/startup-all.sh >> "$LOG" 2>&1
else
    echo "[$(date '+%H:%M:%S')] Tous les services sont actifs" | tee -a "$LOG"
fi