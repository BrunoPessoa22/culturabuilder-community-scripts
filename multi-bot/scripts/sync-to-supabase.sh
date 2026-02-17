#!/bin/bash
# ============================================================================
# 🦅 SYNC OPENCLAW → SUPABASE
# Sincroniza memórias, sessões e mensagens do OpenClaw para o Supabase
# 
# Uso: ./sync-to-supabase.sh
# Cron: */30 * * * * /path/to/sync-to-supabase.sh >> /var/log/sync.log 2>&1
# ============================================================================

set -e

# Configurações (via env ou .env)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOT_DIR="${BOT_DIR:-$HOME/.openclaw}"

# Carregar .env
if [ -f "$BOT_DIR/config/.env" ]; then
    source "$BOT_DIR/config/.env"
elif [ -f ".env" ]; then
    source .env
fi

# Validar
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_KEY" ] || [ -z "$SUPABASE_SCHEMA" ]; then
    echo "[$(date)] ❌ SUPABASE_URL, SUPABASE_KEY ou SUPABASE_SCHEMA não configurados"
    exit 1
fi

AGENT_DIR="$BOT_DIR/agents/main/agent"
MEMORY_DIR="$BOT_DIR/agents/main/memory"
SESSION_DIR="$BOT_DIR/agents/main/sessions"
SYNC_STATE="$BOT_DIR/.last-sync"

echo "[$(date)] 🔄 Iniciando sync para Supabase (schema: $SUPABASE_SCHEMA)..."

# ============================================================================
# FUNÇÃO: Upsert no Supabase
# ============================================================================
supabase_upsert() {
    local table=$1
    local data=$2
    local on_conflict=${3:-""}
    
    local url="$SUPABASE_URL/rest/v1/${SUPABASE_SCHEMA}.${table}"
    local headers=(-H "apikey: $SUPABASE_KEY" -H "Authorization: Bearer $SUPABASE_KEY" -H "Content-Type: application/json" -H "Prefer: resolution=merge-duplicates")
    
    curl -s -X POST "$url" "${headers[@]}" -d "$data" 2>/dev/null
}

supabase_query() {
    local table=$1
    local params=$2
    
    local url="$SUPABASE_URL/rest/v1/${SUPABASE_SCHEMA}.${table}?${params}"
    curl -s "$url" -H "apikey: $SUPABASE_KEY" -H "Authorization: Bearer $SUPABASE_KEY" 2>/dev/null
}

# ============================================================================
# 1. SYNC MEMÓRIAS (arquivos .md → tabela memories)
# ============================================================================
echo "[$(date)] 📝 Sincronizando memórias..."

MEMORY_COUNT=0

# MEMORY.md principal
if [ -f "$AGENT_DIR/MEMORY.md" ]; then
    CONTENT=$(cat "$AGENT_DIR/MEMORY.md" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""')
    supabase_upsert "memories" "[{
        \"key\": \"MEMORY.md\",
        \"value\": $CONTENT,
        \"category\": \"core\",
        \"importance\": 10
    }]" >/dev/null
    MEMORY_COUNT=$((MEMORY_COUNT + 1))
fi

# SOUL.md
if [ -f "$AGENT_DIR/SOUL.md" ]; then
    CONTENT=$(cat "$AGENT_DIR/SOUL.md" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""')
    supabase_upsert "memories" "[{
        \"key\": \"SOUL.md\",
        \"value\": $CONTENT,
        \"category\": \"core\",
        \"importance\": 10
    }]" >/dev/null
    MEMORY_COUNT=$((MEMORY_COUNT + 1))
fi

# USER.md
if [ -f "$AGENT_DIR/USER.md" ]; then
    CONTENT=$(cat "$AGENT_DIR/USER.md" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""')
    supabase_upsert "memories" "[{
        \"key\": \"USER.md\",
        \"value\": $CONTENT,
        \"category\": \"core\",
        \"importance\": 10
    }]" >/dev/null
    MEMORY_COUNT=$((MEMORY_COUNT + 1))
fi

# IDENTITY.md
if [ -f "$AGENT_DIR/IDENTITY.md" ]; then
    CONTENT=$(cat "$AGENT_DIR/IDENTITY.md" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""')
    supabase_upsert "memories" "[{
        \"key\": \"IDENTITY.md\",
        \"value\": $CONTENT,
        \"category\": \"core\",
        \"importance\": 10
    }]" >/dev/null
    MEMORY_COUNT=$((MEMORY_COUNT + 1))
fi

# Memórias diárias (memory/*.md)
if [ -d "$MEMORY_DIR" ]; then
    find "$MEMORY_DIR" -name "*.md" -type f | while read -r md_file; do
        FILENAME=$(basename "$md_file")
        RELPATH=$(realpath --relative-to="$MEMORY_DIR" "$md_file")
        CONTENT=$(cat "$md_file" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""')
        
        supabase_upsert "memories" "[{
            \"key\": \"memory/$RELPATH\",
            \"value\": $CONTENT,
            \"category\": \"daily\",
            \"importance\": 5
        }]" >/dev/null
        MEMORY_COUNT=$((MEMORY_COUNT + 1))
    done
fi

echo "[$(date)] ✅ $MEMORY_COUNT memórias sincronizadas"

# ============================================================================
# 2. SYNC SESSÕES (sessions/*.jsonl → tabelas sessions + messages)
# ============================================================================
echo "[$(date)] 💬 Sincronizando sessões e mensagens..."

SESSION_COUNT=0
MSG_COUNT=0
LAST_SYNC=$(cat "$SYNC_STATE" 2>/dev/null || echo "0")

if [ -d "$SESSION_DIR" ]; then
    find "$SESSION_DIR" -name "*.jsonl" -type f | while read -r session_file; do
        SESSION_ID=$(basename "$session_file" .jsonl)
        
        # Verificar se arquivo foi modificado desde último sync
        FILE_MOD=$(stat -c %Y "$session_file" 2>/dev/null || stat -f %m "$session_file" 2>/dev/null || echo "0")
        if [ "$FILE_MOD" -le "$LAST_SYNC" ] 2>/dev/null; then
            continue
        fi
        
        # Upsert sessão
        supabase_upsert "sessions" "[{
            \"id\": \"$SESSION_ID\",
            \"status\": \"active\",
            \"last_message_at\": \"$(date -Iseconds)\"
        }]" >/dev/null
        SESSION_COUNT=$((SESSION_COUNT + 1))
        
        # Processar mensagens (últimas linhas desde último sync)
        # Cada linha é um JSON com role, content, timestamp
        tail -n 100 "$session_file" | while IFS= read -r line; do
            # Validar JSON
            if echo "$line" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
                ROLE=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('role','unknown'))" 2>/dev/null)
                CONTENT=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); c=d.get('content',''); print(json.dumps(c[:5000] if isinstance(c,str) else str(c)[:5000]))" 2>/dev/null)
                TIMESTAMP=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('timestamp',''))" 2>/dev/null)
                
                if [ -n "$ROLE" ] && [ "$CONTENT" != '""' ]; then
                    supabase_upsert "messages" "[{
                        \"session_id\": \"$SESSION_ID\",
                        \"role\": \"$ROLE\",
                        \"content\": $CONTENT,
                        \"created_at\": \"${TIMESTAMP:-$(date -Iseconds)}\"
                    }]" >/dev/null
                    MSG_COUNT=$((MSG_COUNT + 1))
                fi
            fi
        done
    done
fi

echo "[$(date)] ✅ $SESSION_COUNT sessões, mensagens sincronizadas"

# ============================================================================
# 3. SYNC CONFIGURAÇÕES
# ============================================================================
echo "[$(date)] ⚙️ Sincronizando configurações..."

# Salvar config atual
CONFIG_JSON=$(cat "$BOT_DIR/config/.env" 2>/dev/null | grep -v "^#" | grep "=" | python3 -c "
import sys, json
config = {}
for line in sys.stdin:
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        key, _, val = line.partition('=')
        # Não incluir API keys no backup de config
        if 'KEY' not in key and 'TOKEN' not in key and 'SECRET' not in key and 'PASSWORD' not in key:
            config[key.strip()] = val.strip()
print(json.dumps(config))
" 2>/dev/null || echo '{}')

supabase_upsert "config" "[{
    \"key\": \"bot_config\",
    \"value\": $CONFIG_JSON
}]" >/dev/null

supabase_upsert "config" "[{
    \"key\": \"last_sync\",
    \"value\": {\"timestamp\": \"$(date -Iseconds)\", \"hostname\": \"$(hostname)\"}
}]" >/dev/null

echo "[$(date)] ✅ Configurações sincronizadas"

# ============================================================================
# 4. ATUALIZAR ANALYTICS DIÁRIOS
# ============================================================================
echo "[$(date)] 📊 Atualizando analytics..."

TODAY=$(date +%Y-%m-%d)

# Contar mensagens de hoje
if [ -d "$SESSION_DIR" ]; then
    MSGS_TODAY=$(find "$SESSION_DIR" -name "*.jsonl" -newer "$SYNC_STATE" -exec cat {} \; 2>/dev/null | wc -l || echo 0)
else
    MSGS_TODAY=0
fi

supabase_upsert "analytics" "[{
    \"date\": \"$TODAY\",
    \"messages_in\": $((MSGS_TODAY / 2)),
    \"messages_out\": $((MSGS_TODAY / 2))
}]" >/dev/null

echo "[$(date)] ✅ Analytics atualizados"

# ============================================================================
# SALVAR ESTADO DO SYNC
# ============================================================================
date +%s > "$SYNC_STATE"

echo "[$(date)] ✅ Sync completo!"
echo "---"
