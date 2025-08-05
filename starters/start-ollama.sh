#!/bin/bash
LOG_FILE="/tmp/startup-logs/ollama-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] OLLAMA: $1" | tee -a "$LOG_FILE"
}

if pgrep -f "ollama serve" > /dev/null; then
    log "Déjà en cours"
    exit 0
fi

log "Démarrage Ollama..."
export HOME=/Users/michel
ollama serve >> "$LOG_FILE" 2>&1 &

# Attendre qu'Ollama soit prêt
sleep 5
if curl -s http://localhost:11434/api/tags > /dev/null; then
    log "✓ Ollama OK sur port 11434"
else
    log "✗ Ollama ne répond pas"
fi