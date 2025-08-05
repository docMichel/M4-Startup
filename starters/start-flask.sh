#!/bin/bash
LOG_FILE="/tmp/startup-logs/flask-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FLASK: $1" | tee -a "$LOG_FILE"
}

if pgrep -f "caption_server.py" > /dev/null; then
    log "Déjà en cours"
    exit 0
fi

# ATTENDRE QU'IMMICH SOIT PRÊT
log "Attente d'Immich sur port 3001..."
for i in {1..30}; do
    if curl -s http://localhost:3001/api/server/version > /dev/null 2>&1; then
        log "✓ Immich API disponible"
        break
    fi
    sleep 2
done

# Vérifier si Immich répond vraiment
if ! curl -s http://localhost:3001/api/server/version > /dev/null 2>&1; then
    log "⚠️  Immich API non disponible, Flask démarrera en mode dégradé"
fi

log "Démarrage Caption Server..."
export HOME=/Users/michel
cd /Users/michel/caption-maker

# ACTIVER LE VENV PROPREMENT
log "Activation du venv..."
source venv/bin/activate

# Vérifier qu'on utilise le bon Python
log "Python utilisé: $(which python)"
log "Python version: $(python --version)"

# Maintenant lancer avec le python activé
python src/caption_server.py >> "$LOG_FILE" 2>&1 &


sleep 5
if curl -s http://localhost:5000/api/health > /dev/null 2>&1; then
    log "✓ Flask OK sur http://localhost:5000"
else
    log "✗ Flask ne répond pas"
fi