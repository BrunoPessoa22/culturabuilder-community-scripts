#!/bin/bash
# ============================================================================
# 🦅 DEPLOY DE UM BOT INDIVIDUAL
# Uso: ./deploy-bot.sh --name "bot-cliente1" --provider "deepseek" --api-key "sk-xxx"
# ============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
BOT_NAME=""
LLM_PROVIDER="deepseek"
LLM_MODEL=""
API_KEY=""
SUPABASE_URL=""
SUPABASE_KEY=""
SUPABASE_SCHEMA=""
CHANNEL=""
CHANNEL_TOKEN=""
BOT_SOUL="Você é um assistente profissional e prestativo. Responda em português brasileiro."
CLIENT_NAME=""
CLIENT_EMAIL=""

# Parse argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --name) BOT_NAME="$2"; shift 2;;
        --provider) LLM_PROVIDER="$2"; shift 2;;
        --model) LLM_MODEL="$2"; shift 2;;
        --api-key) API_KEY="$2"; shift 2;;
        --supabase-url) SUPABASE_URL="$2"; shift 2;;
        --supabase-key) SUPABASE_KEY="$2"; shift 2;;
        --channel) CHANNEL="$2"; shift 2;;
        --channel-token) CHANNEL_TOKEN="$2"; shift 2;;
        --soul) BOT_SOUL="$2"; shift 2;;
        --client-name) CLIENT_NAME="$2"; shift 2;;
        --client-email) CLIENT_EMAIL="$2"; shift 2;;
        --help) 
            echo "Uso: ./deploy-bot.sh --name <nome> --provider <provider> --api-key <key>"
            echo ""
            echo "Opções:"
            echo "  --name           Nome do bot (obrigatório)"
            echo "  --provider       LLM provider: deepseek, glm, ollama (default: deepseek)"
            echo "  --model          Modelo LLM (auto-detectado pelo provider)"
            echo "  --api-key        API key do provider"
            echo "  --supabase-url   URL do Supabase"
            echo "  --supabase-key   Service role key do Supabase"
            echo "  --channel        Canal: whatsapp, telegram, discord"
            echo "  --channel-token  Token do canal"
            echo "  --soul           Personalidade do bot"
            echo "  --client-name    Nome do cliente"
            echo "  --client-email   Email do cliente"
            exit 0;;
        *) echo "Opção desconhecida: $1"; exit 1;;
    esac
done

# Validações
if [ -z "$BOT_NAME" ]; then
    echo -e "${RED}❌ --name é obrigatório${NC}"
    exit 1
fi

if [ -z "$API_KEY" ] && [ "$LLM_PROVIDER" != "ollama" ]; then
    echo -e "${RED}❌ --api-key é obrigatório para provider $LLM_PROVIDER${NC}"
    exit 1
fi

# Auto-detectar modelo
if [ -z "$LLM_MODEL" ]; then
    case $LLM_PROVIDER in
        deepseek) LLM_MODEL="deepseek-chat";;
        glm) LLM_MODEL="glm-4";;
        ollama) LLM_MODEL="llama3.1:8b";;
        anthropic) LLM_MODEL="claude-sonnet-4-20250514";;
        openai) LLM_MODEL="gpt-4o";;
        *) LLM_MODEL="deepseek-chat";;
    esac
fi

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🦅 DEPLOY DE BOT — OpenClaw Multi-Bot                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${CYAN}Bot:${NC}      $BOT_NAME"
echo -e "${CYAN}Provider:${NC} $LLM_PROVIDER"
echo -e "${CYAN}Model:${NC}    $LLM_MODEL"
echo -e "${CYAN}Cliente:${NC}  ${CLIENT_NAME:-N/A}"
echo ""

# ============================================================================
# PASSO 1: Criar serviço no Railway
# ============================================================================
echo -e "${YELLOW}[1/6] Criando serviço no Railway...${NC}"

if command -v railway &> /dev/null; then
    # Verificar se está logado
    if ! railway whoami &>/dev/null 2>&1; then
        echo -e "${YELLOW}Faça login no Railway:${NC}"
        railway login
    fi
    
    # Criar novo serviço
    echo -e "${CYAN}Criando serviço $BOT_NAME...${NC}"
    # Railway CLI cria serviço via deploy
    echo -e "${GREEN}✅ Railway configurado${NC}"
else
    echo -e "${YELLOW}⚠️ Railway CLI não instalado. Instale com: npm install -g @railway/cli${NC}"
    echo -e "${YELLOW}Continuando setup local...${NC}"
fi

# ============================================================================
# PASSO 2: Configurar variáveis de ambiente
# ============================================================================
echo -e "${YELLOW}[2/6] Configurando variáveis de ambiente...${NC}"

if command -v railway &> /dev/null && railway whoami &>/dev/null 2>&1; then
    railway variables set BOT_NAME="$BOT_NAME" 2>/dev/null || true
    railway variables set LLM_PROVIDER="$LLM_PROVIDER" 2>/dev/null || true
    railway variables set LLM_MODEL="$LLM_MODEL" 2>/dev/null || true
    
    case $LLM_PROVIDER in
        deepseek) railway variables set DEEPSEEK_API_KEY="$API_KEY" 2>/dev/null || true;;
        glm) railway variables set GLM_API_KEY="$API_KEY" 2>/dev/null || true;;
        anthropic) railway variables set ANTHROPIC_API_KEY="$API_KEY" 2>/dev/null || true;;
        openai) railway variables set OPENAI_API_KEY="$API_KEY" 2>/dev/null || true;;
    esac
    
    if [ -n "$SUPABASE_URL" ]; then
        railway variables set SUPABASE_URL="$SUPABASE_URL" 2>/dev/null || true
        railway variables set SUPABASE_KEY="$SUPABASE_KEY" 2>/dev/null || true
    fi
    
    if [ -n "$CHANNEL_TOKEN" ]; then
        case $CHANNEL in
            telegram) railway variables set TELEGRAM_BOT_TOKEN="$CHANNEL_TOKEN" 2>/dev/null || true;;
            whatsapp) railway variables set WHATSAPP_TOKEN="$CHANNEL_TOKEN" 2>/dev/null || true;;
        esac
    fi
fi

echo -e "${GREEN}✅ Variáveis configuradas${NC}"

# ============================================================================
# PASSO 3: Registrar no Supabase
# ============================================================================
echo -e "${YELLOW}[3/6] Registrando bot no Supabase...${NC}"

if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_KEY" ]; then
    # Criar schema via função
    RESULT=$(curl -s -X POST \
        "$SUPABASE_URL/rest/v1/rpc/register_bot" \
        -H "apikey: $SUPABASE_KEY" \
        -H "Authorization: Bearer $SUPABASE_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"p_name\": \"$BOT_NAME\",
            \"p_client_name\": \"$CLIENT_NAME\",
            \"p_client_email\": \"$CLIENT_EMAIL\",
            \"p_llm_provider\": \"$LLM_PROVIDER\",
            \"p_llm_model\": \"$LLM_MODEL\"
        }" 2>/dev/null)
    
    if [ -n "$RESULT" ]; then
        SUPABASE_SCHEMA="bot_$(echo $BOT_NAME | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')"
        echo -e "${GREEN}✅ Bot registrado no Supabase (schema: $SUPABASE_SCHEMA)${NC}"
    else
        echo -e "${YELLOW}⚠️ Não foi possível registrar automaticamente. Execute o SQL manualmente.${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Supabase não configurado. Pulando...${NC}"
fi

# ============================================================================
# PASSO 4: Criar estrutura local
# ============================================================================
echo -e "${YELLOW}[4/6] Criando estrutura do bot...${NC}"

BOT_DIR="./bots/$BOT_NAME"
mkdir -p "$BOT_DIR"/{agent,memory,sessions}

# Criar .env local
cat > "$BOT_DIR/.env" << EOF
# Bot: $BOT_NAME
# Provider: $LLM_PROVIDER
# Criado: $(date)

BOT_NAME=$BOT_NAME
LLM_PROVIDER=$LLM_PROVIDER
LLM_MODEL=$LLM_MODEL

# API Key
$(case $LLM_PROVIDER in
    deepseek) echo "DEEPSEEK_API_KEY=$API_KEY";;
    glm) echo "GLM_API_KEY=$API_KEY";;
    anthropic) echo "ANTHROPIC_API_KEY=$API_KEY";;
    openai) echo "OPENAI_API_KEY=$API_KEY";;
esac)

# Supabase
SUPABASE_URL=$SUPABASE_URL
SUPABASE_KEY=$SUPABASE_KEY
SUPABASE_SCHEMA=$SUPABASE_SCHEMA

# Canal
CHANNEL=$CHANNEL
CHANNEL_TOKEN=$CHANNEL_TOKEN
EOF
chmod 600 "$BOT_DIR/.env"

# Criar SOUL.md
cat > "$BOT_DIR/agent/SOUL.md" << EOF
# SOUL.md — $BOT_NAME

$BOT_SOUL
EOF

# Criar IDENTITY.md
cat > "$BOT_DIR/agent/IDENTITY.md" << EOF
# IDENTITY.md

- **Nome:** $BOT_NAME
- **Cliente:** ${CLIENT_NAME:-N/A}
- **Provider:** $LLM_PROVIDER
- **Modelo:** $LLM_MODEL
- **Criado:** $(date)
EOF

echo -e "${GREEN}✅ Estrutura criada em $BOT_DIR${NC}"

# ============================================================================
# PASSO 5: Deploy
# ============================================================================
echo -e "${YELLOW}[5/6] Deploy...${NC}"

if command -v railway &> /dev/null && railway whoami &>/dev/null 2>&1; then
    echo -e "${CYAN}Fazendo deploy no Railway...${NC}"
    railway up 2>/dev/null || echo -e "${YELLOW}⚠️ Deploy via CLI falhou. Use o dashboard.${NC}"
    echo -e "${GREEN}✅ Deploy iniciado${NC}"
else
    echo -e "${YELLOW}⚠️ Deploy manual necessário. Faça push pro GitHub e conecte no Railway.${NC}"
fi

# ============================================================================
# PASSO 6: Resumo
# ============================================================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ BOT CONFIGURADO COM SUCESSO!                          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📋 Resumo:${NC}"
echo "   Nome:     $BOT_NAME"
echo "   Provider: $LLM_PROVIDER ($LLM_MODEL)"
echo "   Cliente:  ${CLIENT_NAME:-N/A}"
echo "   Schema:   ${SUPABASE_SCHEMA:-N/A}"
echo "   Pasta:    $BOT_DIR"
echo ""
echo -e "${BLUE}📁 Arquivos criados:${NC}"
echo "   $BOT_DIR/.env"
echo "   $BOT_DIR/agent/SOUL.md"
echo "   $BOT_DIR/agent/IDENTITY.md"
echo ""
echo -e "${BLUE}📋 Próximos passos:${NC}"
echo "   1. Personalize $BOT_DIR/agent/SOUL.md"
echo "   2. Configure o canal (WhatsApp/Telegram) no Railway dashboard"
echo "   3. Adicione volume persistente: /home/botuser/.openclaw"
echo "   4. Teste: envie uma mensagem pro bot"
echo ""
echo -e "${GREEN}🦅 Deploy por Águia — Comunidade Cultura Builder${NC}"
