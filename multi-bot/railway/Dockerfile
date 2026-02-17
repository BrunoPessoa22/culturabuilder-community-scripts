# ============================================================================
# 🦅 OpenClaw Bot — Dockerfile para Railway
# Comunidade Cultura Builder
# ============================================================================

FROM node:20-slim

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    curl \
    git \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Criar usuário não-root
RUN useradd -m -s /bin/bash botuser

# Instalar OpenClaw globalmente
RUN npm install -g openclaw

# Instalar Python (para sync scripts)
RUN apt-get update && apt-get install -y python3 && rm -rf /var/lib/apt/lists/*

# Copiar scripts
COPY start.sh /home/botuser/start.sh
COPY ../scripts/sync-to-supabase.sh /home/botuser/scripts/sync-to-supabase.sh
COPY ../scripts/restore-from-supabase.sh /home/botuser/scripts/restore-from-supabase.sh
RUN chmod +x /home/botuser/start.sh /home/botuser/scripts/*.sh

# Mudar para usuário não-root
USER botuser
WORKDIR /home/botuser

# Criar estrutura de pastas
RUN mkdir -p .openclaw/agents/main/agent \
    .openclaw/agents/main/memory \
    .openclaw/agents/main/sessions

# Porta do gateway (ajustar conforme necessidade)
EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD openclaw status || exit 1

# Iniciar
CMD ["/home/botuser/start.sh"]
