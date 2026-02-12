#!/bin/bash
#===============================================================================
# 🦅 INSTALADOR SEGURO DO OPENCLAW
# Criado por: Águia (Comunidade Cultura Builder)
# Versão: 1.0
# Data: 2026-02-11
#
# Uso: curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash
# Ou:  wget -qO- https://raw.githubusercontent.com/.../install.sh | bash
#===============================================================================

set -e  # Para no primeiro erro

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🦅 INSTALADOR SEGURO DO OPENCLAW                         ║"
echo "║  Comunidade Cultura Builder                               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

#-------------------------------------------------------------------------------
# 1. VERIFICAÇÕES INICIAIS
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[1/8] Verificando sistema...${NC}"

# Verificar se é Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}❌ Este script é apenas para Linux${NC}"
    exit 1
fi

# Verificar se não é root (melhor criar usuário dedicado)
if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  Rodando como root. Recomendado criar usuário dedicado.${NC}"
    read -p "Continuar mesmo assim? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Criando usuário 'openclaw-bot'..."
        useradd -m -s /bin/bash openclaw-bot 2>/dev/null || true
        echo -e "${GREEN}Usuário criado. Execute: su - openclaw-bot && bash $0${NC}"
        exit 0
    fi
fi

echo -e "${GREEN}✅ Sistema verificado${NC}"

#-------------------------------------------------------------------------------
# 2. ATUALIZAR SISTEMA
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[2/8] Atualizando sistema...${NC}"

sudo apt update -qq
sudo apt upgrade -y -qq

echo -e "${GREEN}✅ Sistema atualizado${NC}"

#-------------------------------------------------------------------------------
# 3. INSTALAR DEPENDÊNCIAS
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[3/8] Instalando dependências...${NC}"

sudo apt install -y -qq \
    curl \
    wget \
    git \
    ufw \
    fail2ban \
    htop \
    tmux \
    unattended-upgrades

# Verificar/Instalar Node.js
if ! command -v node &> /dev/null; then
    echo "Instalando Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi

NODE_VERSION=$(node --version)
echo -e "${GREEN}✅ Node.js instalado: $NODE_VERSION${NC}"

#-------------------------------------------------------------------------------
# 4. CONFIGURAR FIREWALL
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[4/8] Configurando firewall...${NC}"

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw --force enable

echo -e "${GREEN}✅ Firewall configurado (apenas SSH liberado)${NC}"

#-------------------------------------------------------------------------------
# 5. CONFIGURAR FAIL2BAN
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[5/8] Configurando Fail2ban...${NC}"

sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

echo -e "${GREEN}✅ Fail2ban configurado${NC}"

#-------------------------------------------------------------------------------
# 6. CRIAR ESTRUTURA DE DIRETÓRIOS
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[6/8] Criando estrutura de diretórios...${NC}"

# Criar diretórios com permissões corretas
mkdir -p ~/.openclaw/{config,data,logs,backups,scripts}
chmod 700 ~/.openclaw/config

# Criar arquivo .env template
cat > ~/.openclaw/config/.env.example <<EOF
# API Keys (NUNCA compartilhe!)
# Descomente e preencha as que for usar

# Anthropic (Claude)
#ANTHROPIC_API_KEY=sk-ant-xxx

# OpenAI (GPT)
#OPENAI_API_KEY=sk-xxx

# GLM/Kimi (Z.ai)
#GLM_API_KEY=xxx

# Configurações
NODE_ENV=production
LOG_LEVEL=info
EOF

chmod 600 ~/.openclaw/config/.env.example

echo -e "${GREEN}✅ Estrutura criada em ~/.openclaw/${NC}"

#-------------------------------------------------------------------------------
# 7. INSTALAR OPENCLAW
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[7/8] Instalando OpenClaw...${NC}"

sudo npm install -g openclaw

OPENCLAW_VERSION=$(openclaw --version 2>/dev/null || echo "instalado")
echo -e "${GREEN}✅ OpenClaw instalado: $OPENCLAW_VERSION${NC}"

#-------------------------------------------------------------------------------
# 8. CRIAR SCRIPTS AUXILIARES
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[8/8] Criando scripts auxiliares...${NC}"

# Script de backup
cat > ~/.openclaw/scripts/backup.sh <<'EOF'
#!/bin/bash
DATE=$(date +%Y-%m-%d_%H%M)
BACKUP_DIR=~/.openclaw/backups
tar -czf $BACKUP_DIR/openclaw-$DATE.tar.gz \
    --exclude='*.log' \
    ~/.openclaw/config ~/.openclaw/data
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
echo "Backup criado: openclaw-$DATE.tar.gz"
EOF
chmod +x ~/.openclaw/scripts/backup.sh

# Script de emergência
cat > ~/.openclaw/scripts/emergency-stop.sh <<'EOF'
#!/bin/bash
echo "🚨 PARADA DE EMERGÊNCIA"
openclaw daemon stop 2>/dev/null
pkill -f openclaw 2>/dev/null
echo "✅ OpenClaw parado"
echo "Para reiniciar: openclaw daemon start"
EOF
chmod +x ~/.openclaw/scripts/emergency-stop.sh

# Script de status
cat > ~/.openclaw/scripts/status.sh <<'EOF'
#!/bin/bash
echo "=== OpenClaw Status ==="
openclaw daemon status 2>/dev/null || echo "Daemon não está rodando"
echo ""
echo "=== Uso de Recursos ==="
ps aux | grep -E "(openclaw|node)" | grep -v grep | head -5
echo ""
echo "=== Disco ==="
df -h ~ | tail -1
echo ""
echo "=== Memória ==="
free -h | head -2
EOF
chmod +x ~/.openclaw/scripts/status.sh

# Adicionar aliases úteis
cat >> ~/.bashrc <<'EOF'

# OpenClaw aliases
alias oc='openclaw'
alias oc-start='openclaw daemon start'
alias oc-stop='openclaw daemon stop'
alias oc-status='~/.openclaw/scripts/status.sh'
alias oc-logs='openclaw logs -f'
alias oc-backup='~/.openclaw/scripts/backup.sh'
alias oc-emergency='~/.openclaw/scripts/emergency-stop.sh'
EOF

echo -e "${GREEN}✅ Scripts criados${NC}"

#-------------------------------------------------------------------------------
# FINALIZAÇÃO
#-------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📁 Estrutura criada:${NC}"
echo "   ~/.openclaw/"
echo "   ├── config/       (permissão 700)"
echo "   │   └── .env.example"
echo "   ├── data/"
echo "   ├── logs/"
echo "   ├── backups/"
echo "   └── scripts/"
echo "       ├── backup.sh"
echo "       ├── emergency-stop.sh"
echo "       └── status.sh"
echo ""
echo -e "${BLUE}🚀 Próximos passos:${NC}"
echo "   1. Copie .env.example para .env e configure suas API keys:"
echo "      cp ~/.openclaw/config/.env.example ~/.openclaw/config/.env"
echo "      nano ~/.openclaw/config/.env"
echo ""
echo "   2. Configure o OpenClaw:"
echo "      openclaw configure"
echo ""
echo "   3. Inicie o daemon:"
echo "      openclaw daemon start"
echo ""
echo -e "${BLUE}⌨️  Comandos úteis (recarregue o terminal primeiro):${NC}"
echo "   oc-start     → Iniciar daemon"
echo "   oc-stop      → Parar daemon"
echo "   oc-status    → Ver status"
echo "   oc-logs      → Ver logs"
echo "   oc-backup    → Fazer backup"
echo "   oc-emergency → Parada de emergência"
echo ""
echo -e "${YELLOW}⚠️  Recarregue o terminal para os aliases funcionarem:${NC}"
echo "   source ~/.bashrc"
echo ""
echo -e "${GREEN}🦅 Criado por Águia — Comunidade Cultura Builder${NC}"
