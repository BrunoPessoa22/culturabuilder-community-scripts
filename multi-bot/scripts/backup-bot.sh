#!/bin/bash
# ============================================================================
# 🦅 BACKUP DE UM BOT INDIVIDUAL
# Uso: ./backup-bot.sh --name "bot-cliente1"
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BOT_NAME=""
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

while [[ $# -gt 0 ]]; do
    case $1 in
        --name) BOT_NAME="$2"; shift 2;;
        --dir) BACKUP_DIR="$2"; shift 2;;
        *) echo "Opção desconhecida: $1"; exit 1;;
    esac
done

if [ -z "$BOT_NAME" ]; then
    echo "Uso: ./backup-bot.sh --name <nome-do-bot>"
    exit 1
fi

BOT_DIR="./bots/$BOT_NAME"
if [ ! -d "$BOT_DIR" ]; then
    echo "❌ Bot '$BOT_NAME' não encontrado em $BOT_DIR"
    exit 1
fi

echo -e "${BLUE}🦅 Backup do bot: $BOT_NAME${NC}"

mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/$BOT_NAME-$TIMESTAMP.tar.gz"

# Criar backup
tar -czf "$BACKUP_FILE" -C "./bots" "$BOT_NAME"

# Verificar
if gzip -t "$BACKUP_FILE" 2>/dev/null; then
    SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
    echo -e "${GREEN}✅ Backup criado: $BACKUP_FILE ($SIZE)${NC}"
else
    echo "❌ Backup corrompido!"
    exit 1
fi

# Backup do Supabase (se configurado)
if [ -f "$BOT_DIR/.env" ]; then
    SUPABASE_URL=$(grep "SUPABASE_URL" "$BOT_DIR/.env" | cut -d= -f2)
    SUPABASE_KEY=$(grep "SUPABASE_KEY" "$BOT_DIR/.env" | cut -d= -f2)
    SUPABASE_SCHEMA=$(grep "SUPABASE_SCHEMA" "$BOT_DIR/.env" | cut -d= -f2)
    
    if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_SCHEMA" ]; then
        echo -e "${YELLOW}Exportando dados do Supabase...${NC}"
        
        # Exportar memórias
        curl -s "$SUPABASE_URL/rest/v1/${SUPABASE_SCHEMA}.memories?select=*" \
            -H "apikey: $SUPABASE_KEY" \
            -H "Authorization: Bearer $SUPABASE_KEY" \
            > "$BACKUP_DIR/$BOT_NAME-memories-$TIMESTAMP.json" 2>/dev/null || true
        
        # Exportar config
        curl -s "$SUPABASE_URL/rest/v1/${SUPABASE_SCHEMA}.config?select=*" \
            -H "apikey: $SUPABASE_KEY" \
            -H "Authorization: Bearer $SUPABASE_KEY" \
            > "$BACKUP_DIR/$BOT_NAME-config-$TIMESTAMP.json" 2>/dev/null || true
        
        echo -e "${GREEN}✅ Dados do Supabase exportados${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🦅 Backup completo!${NC}"
