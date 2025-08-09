#!/bin/bash
LOG_FILE="/tmp/startup-logs/immich-$(date +%Y%m%d-%H%M%S).log"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] IMMICH: $1" | tee -a "$LOG_FILE"
}
#

# Vérifier montage NFS
if ! mount | grep -q "/Users/michel/mnt/immich-hub"; then
    log "ERREUR: NFS non monté"
    exit 1
fi

# Remplacer la vérification actuelle par :
# Vérifier si TOUT est déjà lancé (INCLURE VITE!)
if curl -s http://localhost:2283/api/server/ping 2>/dev/null | grep -q pong && \
   curl -s http://localhost:3003/ping 2>/dev/null && \
   curl -s http://localhost:3000 2>/dev/null > /dev/null; then
    log "Immich déjà complètement actif et fonctionnel"
    exit 0
fi

# TOUT LANCER EN TANT QUE MICHEL avec su -c
log "Démarrage complet d'Immich..."

pkill -f "vite dev" 2>/dev/null
pkill -f "esbuild" 2>/dev/null
sleep 1


# Le script complet dans une seule commande su
su - michel -c 'bash -s' << 'IMMICH_SCRIPT'
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Démarrer les services si nécessaire
# Au lieu de brew services start redis
if ! redis-cli ping > /dev/null 2>&1; then
    /opt/homebrew/opt/redis/bin/redis-server /opt/homebrew/etc/redis.conf > /tmp/redis.log 2>&1 &
    sleep 2
fi

# Lancer PostgreSQL directement sans brew services
if ! pg_isready > /dev/null 2>&1; then
    /opt/homebrew/opt/postgresql@14/bin/postgres -D /opt/homebrew/var/postgresql@14 > /tmp/postgresql.log 2>&1 &
    sleep 5
fi

# Vérifier/créer le lien symbolique
if [ ! -L ~/immich-app/server/upload ] || [ "$(readlink ~/immich-app/server/upload)" != "$HOME/mnt/immich-hub" ]; then
    rm -f ~/immich-app/server/upload
    ln -s ~/mnt/immich-hub ~/immich-app/server/upload
fi

# Vérifier structure minimale
cd ~/mnt/immich-hub
for dir in library upload thumbs encoded-video profile backups; do
    [ ! -d "$dir" ] && mkdir -p "$dir"
    [ ! -f "$dir/.immich" ] && touch "$dir/.immich"
done

# Variables d'environnement
export DB_HOSTNAME=localhost
export REDIS_HOSTNAME=localhost  
export DB_USERNAME=immich
export DB_PASSWORD=immich-password
export DB_DATABASE_NAME=immich
export IMMICH_MACHINE_LEARNING_URL=http://localhost:3003
export IMMICH_BUILD_DATA=/Users/michel/immich-app/server/resources
export IMMICH_HOST=0.0.0.0
export DB_VECTOR_EXTENSION=pgvector

# 1. ML
cd ~/immich-app/machine-learning
source ~/immich-ml-venv/bin/activate
uvicorn immich_ml.main:app --host 0.0.0.0 --port 3003 > /tmp/ml.log 2>&1 &

# 2. API
cd ~/immich-app/server
export IMMICH_PORT=2283
export IMMICH_WORKERS_EXCLUDE=microservices
node dist/workers/api.js > /tmp/api.log 2>&1 &

# 3. Microservices
export IMMICH_WORKERS_INCLUDE=microservices
unset IMMICH_WORKERS_EXCLUDE
node dist/main.js > /tmp/microservices.log 2>&1 &

# 4. Web
cd ~/immich-app/web
export IMMICH_SERVER_URL=http://localhost:2283
npm run dev -- --host 0.0.0.0 --port 3000 > /tmp/web.log 2>&1 &

IMMICH_SCRIPT

# Attendre et vérifier
log "Attente du démarrage des services..."
sleep 20

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