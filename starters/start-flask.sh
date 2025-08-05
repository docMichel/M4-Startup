#!/bin/bash
LOG_FILE="/tmp/startup-logs/flask-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FLASK: $1" | tee -a "$LOG_FILE"
}

if pgrep -f "caption_server.py" > /dev/null; then
    log "Déjà en cours"
    exit 0
fi

log "Démarrage Caption Server..."
export HOME=/Users/michel
cd /Users/michel/caption-maker
/Users/michel/caption-maker/venv/bin/python src/caption_server.py >> "$LOG_FILE" 2>&1 &

log "✓ Flask lancé"