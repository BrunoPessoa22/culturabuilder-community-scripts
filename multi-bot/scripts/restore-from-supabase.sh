#!/bin/bash
# ============================================================================
# 🦅 RESTORE DO SUPABASE → OPENCLAW
# Restaura memórias, config e contexto do Supabase para o OpenClaw local
#
# Uso: ./restore-from-supabase.sh
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🦅 RESTORE SUPABASE → OPENCLAW                          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Configurações
BOT_DIR="${BOT_DIR:-$HOME/.openclaw}"

# Carregar .env
if [ -f "$BOT_DIR/config/.env" ]; then
    source "$BOT_DIR/config/.env"
elif [ -f ".env" ]; then
    source .env
fi

# Validar
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_KEY" ] || [ -z "$SUPABASE_SCHEMA" ]; then
    echo -e "${RED}❌ SUPABASE_URL, SUPABASE_KEY ou SUPABASE_SCHEMA não configurados${NC}"
    echo "Configure no .env ou exporte as variáveis."
    exit 1
fi

AGENT_DIR="$BOT_DIR/agents/main/agent"
MEMORY_DIR="$BOT_DIR/agents/main/memory"

echo -e "${YELLOW}Schema: $SUPABASE_SCHEMA${NC}"
echo ""

# ============================================================================
# FUNÇÃO: Query Supabase
# ============================================================================
supabase_get() {
    local table=$1
    local params=$2
    
    curl -s "$SUPABASE_URL/rest/v1/${SUPABASE_SCHEMA}.${table}?${params}" \
        -H "apikey: $SUPABASE_KEY" \
        -H "Authorization: Bearer $SUPABASE_KEY" 2>/dev/null
}

# ============================================================================
# 1. VERIFICAR DADOS DISPONÍVEIS
# ============================================================================
echo -e "${YELLOW}[1/4] Verificando dados no Supabase...${NC}"

MEMORIES=$(supabase_get "memories" "select=key,category,importance&order=importance.desc")
MEM_COUNT=$(echo "$MEMORIES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

SESSIONS=$(supabase_get "sessions" "select=id,status,last_message_at&order=last_message_at.desc&limit=10")
SESS_COUNT=$(echo "$SESSIONS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

MESSAGES=$(supabase_get "messages" "select=id&limit=1&order=id.desc")
# Get total approximate count
MSG_INFO=$(supabase_get "messages" "select=id&order=id.desc&limit=1")
MSG_LAST=$(echo "$MSG_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else 0)" 2>/dev/null || echo "0")

echo -e "${GREEN}  📝 Memórias: $MEM_COUNT${NC}"
echo -e "${GREEN}  💬 Sessões: $SESS_COUNT${NC}"
echo -e "${GREEN}  📨 Último msg ID: ~$MSG_LAST${NC}"
echo ""

if [ "$MEM_COUNT" = "0" ] && [ "$SESS_COUNT" = "0" ]; then
    echo -e "${RED}❌ Nenhum dado encontrado no schema $SUPABASE_SCHEMA${NC}"
    exit 1
fi

# ============================================================================
# 2. RESTAURAR MEMÓRIAS
# ============================================================================
echo -e "${YELLOW}[2/4] Restaurando memórias...${NC}"

mkdir -p "$AGENT_DIR" "$MEMORY_DIR"

# Buscar todas as memórias
ALL_MEMORIES=$(supabase_get "memories" "select=key,value,category&order=importance.desc")

echo "$ALL_MEMORIES" | python3 -c "
import sys, json, os

memories = json.load(sys.stdin)
agent_dir = '$AGENT_DIR'
memory_dir = '$MEMORY_DIR'

restored = 0
for mem in memories:
    key = mem['key']
    value = mem['value']
    
    if key in ['MEMORY.md', 'SOUL.md', 'USER.md', 'IDENTITY.md', 'AGENTS.md', 'TOOLS.md', 'HEARTBEAT.md']:
        # Arquivos core → agent dir
        filepath = os.path.join(agent_dir, key)
        with open(filepath, 'w') as f:
            f.write(value)
        print(f'  ✅ {key} → {filepath}')
        restored += 1
    elif key.startswith('memory/'):
        # Memórias diárias → memory dir
        relpath = key.replace('memory/', '', 1)
        filepath = os.path.join(memory_dir, relpath)
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        with open(filepath, 'w') as f:
            f.write(value)
        print(f'  ✅ {key} → {filepath}')
        restored += 1

print(f'\n  Total: {restored} arquivos restaurados')
" 2>/dev/null || echo -e "${RED}  ❌ Erro ao processar memórias${NC}"

# ============================================================================
# 3. RESTAURAR CONFIGURAÇÕES
# ============================================================================
echo ""
echo -e "${YELLOW}[3/4] Restaurando configurações...${NC}"

CONFIG=$(supabase_get "config" "select=key,value&key=eq.bot_config")
CONFIG_DATA=$(echo "$CONFIG" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data:
    config = data[0].get('value', {})
    for k, v in config.items():
        print(f'{k}={v}')
" 2>/dev/null)

if [ -n "$CONFIG_DATA" ]; then
    echo -e "${GREEN}  ✅ Config recuperado (não sobrescreve .env existente)${NC}"
    echo "  Valores encontrados:"
    echo "$CONFIG_DATA" | sed 's/^/    /'
else
    echo -e "${YELLOW}  ⚠️ Nenhuma config encontrada${NC}"
fi

# ============================================================================
# 4. RESTAURAR ÚLTIMO ESTADO DE SESSÃO (resumo)
# ============================================================================
echo ""
echo -e "${YELLOW}[4/4] Resumo de sessões...${NC}"

echo "$SESSIONS" | python3 -c "
import sys, json
sessions = json.load(sys.stdin)
for s in sessions[:5]:
    sid = s.get('id', 'N/A')[:30]
    status = s.get('status', 'N/A')
    last = s.get('last_message_at', 'N/A')[:19]
    print(f'  {sid}... | {status} | {last}')
if not sessions:
    print('  Nenhuma sessão encontrada')
" 2>/dev/null || echo "  Erro ao listar sessões"

# ============================================================================
# PERMISSÕES
# ============================================================================
chmod -R 700 "$AGENT_DIR" 2>/dev/null
chmod -R 700 "$MEMORY_DIR" 2>/dev/null

# ============================================================================
# RESUMO FINAL
# ============================================================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ RESTORE CONCLUÍDO!                                    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📋 Próximos passos:${NC}"
echo "  1. Reinicie o OpenClaw: openclaw daemon restart"
echo "  2. Mande uma mensagem pro bot: 'Leia suas memórias e me conte o que lembra'"
echo "  3. Verifique se tudo está correto"
echo ""
echo -e "${GREEN}🦅 Restore por Águia — Comunidade Cultura Builder${NC}"
