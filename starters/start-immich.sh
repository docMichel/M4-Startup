#!/bin/bash
LOG_FILE="/tmp/startup-logs/immich-$(date +%Y%m%d-%H%M%S).log"
export HOME=/Users/michel
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] IMMICH: $1" | tee -a "$LOG_FILE"
}

# Vérifier si déjà lancé
if pgrep -f "uvicorn.*immich_ml.main" > /dev/null; then
    log "ML déjà en cours"
    if pgrep -f "node.*dist/main.js" > /dev/null; then
        log "API déjà en cours"
        exit 0
    fi
fi

# Vérifier montage NFS
if ! mount | grep -q "/Users/michel/mnt/immich-hub"; then
    log "ERREUR: NFS non monté"
    exit 1
fi

# Démarrer Redis directement (pas brew services)
if ! redis-cli ping > /dev/null 2>&1; then
    log "Démarrage Redis..."
    su - michel -c "/opt/homebrew/opt/redis/bin/redis-server /opt/homebrew/etc/redis.conf" >> "$LOG_FILE" 2>&1 &
    sleep 2
fi

# Démarrer PostgreSQL directement (pas brew services)
if ! su - michel -c "pg_isready" > /dev/null 2>&1; then
    log "Démarrage PostgreSQL..."
    su - michel -c "/opt/homebrew/opt/postgresql@14/bin/postgres -D /opt/homebrew/var/postgresql@14" >> "$LOG_FILE" 2>&1 &
    sleep 5
fi

# Vérifier/créer lien symbolique
if [ ! -L ~/immich-app/server/upload ] || [ "$(readlink ~/immich-app/server/upload)" != "$HOME/mnt/immich-hub" ]; then
    log "Création lien symbolique..."
    rm -f ~/immich-app/server/upload
    ln -s ~/mnt/immich-hub ~/immich-app/server/upload
fi

# Variables d'environnement communes
export DB_HOSTNAME=localhost
export REDIS_HOSTNAME=localhost  
export DB_USERNAME=immich
export DB_PASSWORD=immich-password
export DB_DATABASE_NAME=immich
export IMMICH_MACHINE_LEARNING_URL=http://localhost:3003
export IMMICH_BUILD_DATA=/Users/michel/immich-app/server/resources
export IMMICH_HOST=0.0.0.0

# 1. ML
log "Démarrage ML..."
cd ~/immich-app/machine-learning
source ~/immich-ml-venv/bin/activate
uvicorn immich_ml.main:app --host 0.0.0.0 --port 3003 >> "$LOG_FILE" 2>&1 &

# 2. API
log "Démarrage API..."
cd ~/immich-app/server
export IMMICH_PORT=2283
export IMMICH_WORKERS_EXCLUDE=microservices
export DB_VECTOR_EXTENSION=pgvector
node dist/workers/api.js >> "$LOG_FILE" 2>&1 &

# 3. Microservices
log "Démarrage Microservices..."
export IMMICH_WORKERS_INCLUDE=microservices
unset IMMICH_WORKERS_EXCLUDE
node dist/main.js >> "$LOG_FILE" 2>&1 &

# 4. Web
log "Démarrage Web..."
cd ~/immich-app/web
export IMMICH_SERVER_URL=http://localhost:2283
npm run dev -- --host 0.0.0.0 --port 3000 >> "$LOG_FILE" 2>&1 &

# Attendre et vérifier
sleep 10
if curl -s http://localhost:2283/api/server/ping | grep -q pong; then
    log "✓ Immich API OK"
else
    log "✗ Immich API KO"
fi

if curl -s http://localhost:3000 > /dev/null; then
    log "✓ Immich Web OK sur http://localhost:3000"
else
    log "✗ Immich Web KO"
fi

log "Immich démarré - Web: http://$(ipconfig getifaddr en0):3000"