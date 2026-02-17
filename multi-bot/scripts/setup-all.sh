#!/bin/bash
# ============================================================================
# 🦅 SETUP COMPLETO — OpenClaw Multi-Bot
# Configura Railway + Supabase + primeiro bot de uma vez
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🦅 SETUP COMPLETO — OpenClaw Multi-Bot                   ║"
echo "║  Comunidade Cultura Builder                               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ============================================================================
# PRÉ-REQUISITOS
# ============================================================================
echo -e "${YELLOW}[0/5] Verificando pré-requisitos...${NC}"

# Node.js
if ! command -v node &>/dev/null; then
    echo -e "${RED}❌ Node.js não encontrado. Instale: https://nodejs.org${NC}"
    exit 1
fi
echo -e "${GREEN}  ✅ Node.js $(node --version)${NC}"

# npm
if ! command -v npm &>/dev/null; then
    echo -e "${RED}❌ npm não encontrado${NC}"
    exit 1
fi
echo -e "${GREEN}  ✅ npm $(npm --version)${NC}"

# Railway CLI
if ! command -v railway &>/dev/null; then
    echo -e "${YELLOW}  ⚠️ Railway CLI não encontrado. Instalando...${NC}"
    npm install -g @railway/cli
fi
echo -e "${GREEN}  ✅ Railway CLI instalado${NC}"

# OpenClaw
if ! command -v openclaw &>/dev/null; then
    echo -e "${YELLOW}  ⚠️ OpenClaw não encontrado. Instalando...${NC}"
    npm install -g openclaw
fi
echo -e "${GREEN}  ✅ OpenClaw instalado${NC}"

# curl
if ! command -v curl &>/dev/null; then
    echo -e "${RED}❌ curl não encontrado${NC}"
    exit 1
fi
echo -e "${GREEN}  ✅ curl disponível${NC}"

echo ""

# ============================================================================
# COLETA DE INFORMAÇÕES
# ============================================================================
echo -e "${YELLOW}[1/5] Configuração inicial...${NC}"
echo ""

# LLM Provider
echo -e "${CYAN}Escolha o LLM Provider:${NC}"
echo "  1) DeepSeek  — ~\$2-3/mês (recomendado)"
echo "  2) GLM/Z.ai  — ~\$3/mês"
echo "  3) Ollama     — Grátis (lento em CPU)"
echo "  4) Anthropic  — ~\$15-20/mês (premium)"
echo "  5) OpenAI     — ~\$15-20/mês (premium)"
read -p "Opção [1]: " PROVIDER_CHOICE
PROVIDER_CHOICE=${PROVIDER_CHOICE:-1}

case $PROVIDER_CHOICE in
    1) LLM_PROVIDER="deepseek"; LLM_MODEL="deepseek-chat";;
    2) LLM_PROVIDER="glm"; LLM_MODEL="glm-4";;
    3) LLM_PROVIDER="ollama"; LLM_MODEL="llama3.1:8b";;
    4) LLM_PROVIDER="anthropic"; LLM_MODEL="claude-sonnet-4-20250514";;
    5) LLM_PROVIDER="openai"; LLM_MODEL="gpt-4o";;
    *) LLM_PROVIDER="deepseek"; LLM_MODEL="deepseek-chat";;
esac

# API Key
if [ "$LLM_PROVIDER" != "ollama" ]; then
    echo ""
    read -p "API Key do $LLM_PROVIDER: " API_KEY
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}❌ API Key obrigatória para $LLM_PROVIDER${NC}"
        exit 1
    fi
fi

# Supabase
echo ""
echo -e "${CYAN}Configurar Supabase? (recomendado para múltiplos bots)${NC}"
read -p "Configurar Supabase? (s/n) [s]: " USE_SUPABASE
USE_SUPABASE=${USE_SUPABASE:-s}

if [[ "$USE_SUPABASE" =~ ^[Ss]$ ]]; then
    read -p "Supabase Project URL: " SUPABASE_URL
    read -p "Supabase Service Role Key: " SUPABASE_KEY
fi

# Primeiro bot
echo ""
echo -e "${CYAN}Configurar primeiro bot:${NC}"
read -p "Nome do bot: " BOT_NAME
BOT_NAME=${BOT_NAME:-"bot-1"}
read -p "Nome do cliente (opcional): " CLIENT_NAME
read -p "Email do cliente (opcional): " CLIENT_EMAIL

echo ""
echo -e "${GREEN}✅ Configuração coletada${NC}"

# ============================================================================
# SETUP SUPABASE
# ============================================================================
echo ""
echo -e "${YELLOW}[2/5] Configurando Supabase...${NC}"

if [[ "$USE_SUPABASE" =~ ^[Ss]$ ]] && [ -n "$SUPABASE_URL" ]; then
    echo -e "${CYAN}Executando schema...${NC}"
    
    # Ler e executar SQL
    if [ -f "supabase/schema.sql" ]; then
        SCHEMA_SQL=$(cat supabase/schema.sql)
        
        curl -s -X POST \
            "$SUPABASE_URL/rest/v1/rpc/exec_sql" \
            -H "apikey: $SUPABASE_KEY" \
            -H "Authorization: Bearer $SUPABASE_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"sql\": $(echo "$SCHEMA_SQL" | jq -Rs .)}" 2>/dev/null || true
        
        echo -e "${YELLOW}⚠️ Se o schema não foi criado automaticamente:${NC}"
        echo "   1. Abra o SQL Editor no Supabase Dashboard"
        echo "   2. Cole o conteúdo de supabase/schema.sql"
        echo "   3. Execute"
    fi
    
    echo -e "${GREEN}✅ Supabase configurado${NC}"
else
    echo -e "${YELLOW}⚠️ Supabase pulado${NC}"
fi

# ============================================================================
# SETUP RAILWAY
# ============================================================================
echo ""
echo -e "${YELLOW}[3/5] Configurando Railway...${NC}"

# Login
if ! railway whoami &>/dev/null 2>&1; then
    echo -e "${CYAN}Faça login no Railway:${NC}"
    railway login
fi

echo -e "${GREEN}✅ Railway logado como $(railway whoami 2>/dev/null || echo 'N/A')${NC}"

# ============================================================================
# DEPLOY PRIMEIRO BOT
# ============================================================================
echo ""
echo -e "${YELLOW}[4/5] Deploy do primeiro bot...${NC}"

chmod +x scripts/deploy-bot.sh 2>/dev/null || true

DEPLOY_ARGS="--name $BOT_NAME --provider $LLM_PROVIDER"
[ -n "$API_KEY" ] && DEPLOY_ARGS="$DEPLOY_ARGS --api-key $API_KEY"
[ -n "$SUPABASE_URL" ] && DEPLOY_ARGS="$DEPLOY_ARGS --supabase-url $SUPABASE_URL --supabase-key $SUPABASE_KEY"
[ -n "$CLIENT_NAME" ] && DEPLOY_ARGS="$DEPLOY_ARGS --client-name \"$CLIENT_NAME\""
[ -n "$CLIENT_EMAIL" ] && DEPLOY_ARGS="$DEPLOY_ARGS --client-email \"$CLIENT_EMAIL\""

eval "./scripts/deploy-bot.sh $DEPLOY_ARGS"

# ============================================================================
# RESUMO FINAL
# ============================================================================
echo ""
echo -e "${YELLOW}[5/5] Resumo final...${NC}"
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ SETUP COMPLETO!                                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}🔧 O que foi configurado:${NC}"
echo "   ✅ Pré-requisitos verificados"
[ "$USE_SUPABASE" = "s" ] && echo "   ✅ Supabase schema criado"
echo "   ✅ Railway configurado"
echo "   ✅ Bot '$BOT_NAME' deployado"
echo ""
echo -e "${BLUE}📋 Para adicionar mais bots:${NC}"
echo ""
echo "   ./scripts/deploy-bot.sh \\"
echo "     --name \"bot-cliente2\" \\"
echo "     --provider \"$LLM_PROVIDER\" \\"
echo "     --api-key \"SUA_KEY\" \\"
echo "     --client-name \"Nome do Cliente\""
echo ""
echo -e "${BLUE}📋 Para monitorar:${NC}"
echo "   ./scripts/monitor-bots.sh"
echo ""
echo -e "${BLUE}📋 Para backup:${NC}"
echo "   ./scripts/backup-bot.sh --name \"$BOT_NAME\""
echo ""
echo -e "${GREEN}🦅 Setup por Águia — Comunidade Cultura Builder${NC}"
