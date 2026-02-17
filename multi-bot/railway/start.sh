#!/bin/bash
# ============================================================================
# 🦅 Script de inicialização do bot no Railway
# ============================================================================

set -e

echo "🦅 Iniciando OpenClaw Bot..."
echo "Bot: ${BOT_NAME:-unnamed}"
echo "Provider: ${LLM_PROVIDER:-not set}"
echo "Model: ${LLM_MODEL:-not set}"

# Verificar variáveis obrigatórias
if [ -z "$LLM_PROVIDER" ]; then
    echo "❌ LLM_PROVIDER não configurado!"
    exit 1
fi

# Configurar .env se não existir
ENV_FILE="$HOME/.openclaw/config/.env"
mkdir -p "$HOME/.openclaw/config"

if [ ! -f "$ENV_FILE" ]; then
    echo "📝 Criando .env..."
    cat > "$ENV_FILE" << EOF
# LLM Provider
LLM_PROVIDER=${LLM_PROVIDER}
LLM_MODEL=${LLM_MODEL}

# API Keys (configurar via Railway variables)
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}
GLM_API_KEY=${GLM_API_KEY:-}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}

# Supabase (opcional)
SUPABASE_URL=${SUPABASE_URL:-}
SUPABASE_KEY=${SUPABASE_KEY:-}
SUPABASE_SCHEMA=${SUPABASE_SCHEMA:-}

# WhatsApp (se configurado)
WHATSAPP_PHONE_ID=${WHATSAPP_PHONE_ID:-}
WHATSAPP_TOKEN=${WHATSAPP_TOKEN:-}

# Telegram (se configurado)
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}

# Bot identity
BOT_NAME=${BOT_NAME:-Bot}
EOF
    chmod 600 "$ENV_FILE"
fi

# Configurar SOUL.md se não existir
SOUL_FILE="$HOME/.openclaw/agents/main/agent/SOUL.md"
if [ ! -f "$SOUL_FILE" ]; then
    echo "📝 Criando SOUL.md padrão..."
    cat > "$SOUL_FILE" << 'EOF'
# SOUL.md

Você é um assistente profissional e prestativo.
Seja direto, útil e amigável.
Responda em português brasileiro.
EOF
fi

# Configurar Ollama se necessário
if [ "$LLM_PROVIDER" = "ollama" ]; then
    echo "🔧 Iniciando Ollama..."
    if command -v ollama &> /dev/null; then
        ollama serve &
        sleep 5
        ollama pull "${LLM_MODEL:-llama3.1:8b}" 2>/dev/null || true
    else
        echo "⚠️ Ollama não instalado. Instale com: curl -fsSL https://ollama.com/install.sh | sh"
    fi
fi

# Iniciar OpenClaw
echo "🚀 Iniciando OpenClaw daemon..."
openclaw daemon start

# Manter container rodando
echo "✅ Bot rodando! Monitorando..."
while true; do
    # Verificar se OpenClaw está rodando
    if ! openclaw status &>/dev/null; then
        echo "⚠️ OpenClaw caiu, reiniciando..."
        openclaw daemon start
    fi
    sleep 60
done
