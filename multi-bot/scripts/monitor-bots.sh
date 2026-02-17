#!/bin/bash
# ============================================================================
# 🦅 MONITOR DE BOTS — Status de todos os bots
# ============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🦅 MONITOR DE BOTS — OpenClaw Multi-Bot                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Verificar bots locais
if [ -d "./bots" ]; then
    echo -e "${CYAN}📊 Bots configurados:${NC}"
    echo ""
    printf "%-20s %-12s %-15s %-10s\n" "NOME" "PROVIDER" "MODELO" "STATUS"
    printf "%-20s %-12s %-15s %-10s\n" "----" "--------" "------" "------"
    
    for bot_dir in ./bots/*/; do
        if [ -f "$bot_dir/.env" ]; then
            BOT_NAME=$(basename "$bot_dir")
            PROVIDER=$(grep "LLM_PROVIDER" "$bot_dir/.env" | cut -d= -f2)
            MODEL=$(grep "LLM_MODEL" "$bot_dir/.env" | cut -d= -f2)
            
            # Verificar status via Railway (se disponível)
            STATUS="${GREEN}config'd${NC}"
            
            printf "%-20s %-12s %-15s " "$BOT_NAME" "$PROVIDER" "$MODEL"
            echo -e "$STATUS"
        fi
    done
else
    echo -e "${YELLOW}Nenhum bot configurado localmente.${NC}"
    echo "Use ./scripts/deploy-bot.sh para criar o primeiro bot."
fi

echo ""

# Verificar Railway (se logado)
if command -v railway &>/dev/null && railway whoami &>/dev/null 2>&1; then
    echo -e "${CYAN}🚂 Railway Services:${NC}"
    railway status 2>/dev/null || echo -e "${YELLOW}  Use 'railway link' primeiro${NC}"
fi

echo ""

# Supabase stats (se configurado)
if [ -f "./bots/.supabase-config" ]; then
    source "./bots/.supabase-config"
    echo -e "${CYAN}🗄️ Supabase:${NC}"
    
    DASHBOARD=$(curl -s -X POST \
        "$SUPABASE_URL/rest/v1/rpc/dashboard" \
        -H "apikey: $SUPABASE_KEY" \
        -H "Authorization: Bearer $SUPABASE_KEY" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    if [ -n "$DASHBOARD" ]; then
        echo "   $DASHBOARD"
    else
        echo -e "${YELLOW}   Não foi possível conectar${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🦅 Monitor por Águia — Comunidade Cultura Builder${NC}"
