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
log "Attente d'Immich sur port 2283..."
for i in {1..30}; do
    if curl -s http://localhost:2283/api/server/version > /dev/null 2>&1; then
        log "✓ Immich API disponible"
        break
    fi
    sleep 2
done

# Vérifier si Immich répond vraiment
if ! curl -s http://localhost:2283/api/server/version > /dev/null 2>&1; then
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

# Dans start-flask.sh, après le lancement
log "Attente du démarrage de Flask..."
FLASK_OK=0
for i in {1..20}; do
    if curl -s http://localhost:5000/api/health > /dev/null 2>&1; then
        log "✓ Flask OK après ${i}s"
        FLASK_OK=1
        break
    fi
    sleep 1
done

if [ $FLASK_OK -eq 0 ]; then
    log "✗ Flask ne répond toujours pas après 20s"
    log "Vérification du processus..."
    
    if pgrep -f caption_server.py > /dev/null; then
        log "Le processus tourne mais ne répond pas"
        log "Dernières lignes du log:"
        tail -10 "$LOG_FILE"
    else
        log "Le processus Flask est mort"
        log "Tentative de redémarrage..."
        cd /Users/michel/caption-maker
        source venv/bin/activate
        python src/caption_server.py >> "$LOG_FILE" 2>&1 &
        sleep 10
        
        if curl -s http://localhost:5000/api/health > /dev/null 2>&1; then
            log "✓ Flask OK après redémarrage"
        else
            log "✗ Flask KO définitivement - voir $LOG_FILE"
        fi
    fi
fi