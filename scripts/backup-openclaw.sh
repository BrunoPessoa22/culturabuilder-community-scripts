#!/bin/bash
#===============================================================================
# 🦅 BACKUP COMPLETO DO OPENCLAW
# Criado por: Águia (Comunidade Cultura Builder)
# Versão: 1.0
# Data: 2026-02-12
#
# Uso: ./backup-openclaw.sh
# Ou:  ./backup-openclaw.sh --upload-s3 seu-bucket
#===============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurações
BACKUP_DIR="$HOME/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="openclaw-backup-$TIMESTAMP"

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🦅 BACKUP COMPLETO DO OPENCLAW                           ║"
echo "║  Comunidade Cultura Builder                               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

#-------------------------------------------------------------------------------
# FUNÇÕES
#-------------------------------------------------------------------------------

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✅]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠️]${NC} $1"
}

log_error() {
    echo -e "${RED}[❌]${NC} $1"
}

#-------------------------------------------------------------------------------
# PASSO 1: Verificações iniciais
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[1/8] Verificando ambiente...${NC}"

# Verificar se OpenClaw existe
if [ ! -d "$HOME/.openclaw" ]; then
    log_error "Pasta ~/.openclaw não encontrada!"
    log_warning "Tentando ~/.config/openclaw..."
    if [ ! -d "$HOME/.config/openclaw" ]; then
        log_error "Nenhuma instalação do OpenClaw encontrada."
        exit 1
    fi
fi

# Criar pasta de backups
mkdir -p "$BACKUP_DIR"

log_success "Ambiente verificado"

#-------------------------------------------------------------------------------
# PASSO 2: Parar OpenClaw
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[2/8] Parando OpenClaw...${NC}"

if command -v openclaw &> /dev/null; then
    openclaw daemon stop 2>/dev/null || true
    sleep 2
fi

# Garantir que parou
pkill -f "openclaw" 2>/dev/null || true

log_success "OpenClaw parado"

#-------------------------------------------------------------------------------
# PASSO 3: Calcular tamanho
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[3/8] Calculando tamanho...${NC}"

TOTAL_SIZE=0

if [ -d "$HOME/.openclaw" ]; then
    SIZE1=$(du -sb "$HOME/.openclaw" 2>/dev/null | cut -f1 || echo 0)
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE1))
    log_info "~/.openclaw: $(du -sh "$HOME/.openclaw" 2>/dev/null | cut -f1)"
fi

if [ -d "$HOME/.config/openclaw" ]; then
    SIZE2=$(du -sb "$HOME/.config/openclaw" 2>/dev/null | cut -f1 || echo 0)
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE2))
    log_info "~/.config/openclaw: $(du -sh "$HOME/.config/openclaw" 2>/dev/null | cut -f1)"
fi

log_success "Tamanho total estimado: $((TOTAL_SIZE / 1024 / 1024))MB"

#-------------------------------------------------------------------------------
# PASSO 4: Criar backup principal
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[4/8] Criando backup...${NC}"

BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME.tar.gz"

# Lista de pastas para backup
BACKUP_PATHS=""
[ -d "$HOME/.openclaw" ] && BACKUP_PATHS="$BACKUP_PATHS $HOME/.openclaw"
[ -d "$HOME/.config/openclaw" ] && BACKUP_PATHS="$BACKUP_PATHS $HOME/.config/openclaw"
[ -d "$HOME/.local/share/openclaw" ] && BACKUP_PATHS="$BACKUP_PATHS $HOME/.local/share/openclaw"

tar -czvf "$BACKUP_FILE" $BACKUP_PATHS 2>/dev/null

BACKUP_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
log_success "Backup criado: $BACKUP_FILE ($BACKUP_SIZE)"

#-------------------------------------------------------------------------------
# PASSO 5: Verificar integridade
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[5/8] Verificando integridade...${NC}"

if gzip -t "$BACKUP_FILE" 2>/dev/null; then
    log_success "Backup íntegro!"
else
    log_error "Backup corrompido! Tente novamente."
    exit 1
fi

#-------------------------------------------------------------------------------
# PASSO 6: Backup do .env (separado)
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[6/8] Backup de credenciais...${NC}"

ENV_BACKUP="$BACKUP_DIR/env-$TIMESTAMP.enc"

# Procurar arquivo .env
ENV_FILE=""
[ -f "$HOME/.openclaw/.env" ] && ENV_FILE="$HOME/.openclaw/.env"
[ -f "$HOME/.openclaw/config/.env" ] && ENV_FILE="$HOME/.openclaw/config/.env"
[ -f "$HOME/.config/openclaw/.env" ] && ENV_FILE="$HOME/.config/openclaw/.env"

if [ -n "$ENV_FILE" ]; then
    # Criptografar .env (opcional, pede senha)
    read -p "Deseja criptografar o backup do .env? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        openssl enc -aes-256-cbc -salt -pbkdf2 -in "$ENV_FILE" -out "$ENV_BACKUP"
        log_success "Credenciais salvas (criptografadas): $ENV_BACKUP"
    else
        cp "$ENV_FILE" "$BACKUP_DIR/env-$TIMESTAMP.env"
        chmod 600 "$BACKUP_DIR/env-$TIMESTAMP.env"
        log_success "Credenciais salvas: $BACKUP_DIR/env-$TIMESTAMP.env"
        log_warning "ATENÇÃO: Arquivo contém API keys em texto plano!"
    fi
else
    log_warning "Arquivo .env não encontrado"
fi

#-------------------------------------------------------------------------------
# PASSO 7: Documentação
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[7/8] Gerando documentação...${NC}"

INFO_FILE="$BACKUP_DIR/server-info-$TIMESTAMP.txt"

cat > "$INFO_FILE" << EOF
═══════════════════════════════════════════════════════════════
  INFORMAÇÕES DO BACKUP - OpenClaw
  Gerado por: Águia (Cultura Builder)
  Data: $(date)
═══════════════════════════════════════════════════════════════

📅 TIMESTAMP
   Backup: $TIMESTAMP
   Data: $(date '+%Y-%m-%d %H:%M:%S %Z')

🖥️  SERVIDOR
   Hostname: $(hostname)
   IP Público: $(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
   IP Privado: $(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
   
💻 SISTEMA
   OS: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
   Kernel: $(uname -r)
   Arch: $(uname -m)

📦 VERSÕES
   Node.js: $(node --version 2>/dev/null || echo "Não instalado")
   npm: $(npm --version 2>/dev/null || echo "Não instalado")
   OpenClaw: $(openclaw --version 2>/dev/null || echo "N/A")

📁 ESTRUTURA DO BACKUP
$(find $BACKUP_PATHS -type d 2>/dev/null | head -30 | sed 's/^/   /')

📊 TAMANHOS
   Backup comprimido: $BACKUP_SIZE
   Dados originais: $((TOTAL_SIZE / 1024 / 1024))MB

🔑 ARQUIVOS DE CREDENCIAIS
   .env encontrado: $([ -n "$ENV_FILE" ] && echo "Sim ($ENV_FILE)" || echo "Não")

═══════════════════════════════════════════════════════════════
  PARA RESTAURAR:
  
  1. Copie o backup para o novo servidor:
     scp $BACKUP_FILE usuario@novo-servidor:~/
  
  2. No novo servidor, extraia:
     cd ~ && tar -xzvf $BACKUP_NAME.tar.gz
  
  3. Instale o OpenClaw:
     sudo npm install -g openclaw
  
  4. Restaure o .env (se criptografado):
     openssl enc -aes-256-cbc -d -pbkdf2 -in env-$TIMESTAMP.enc -out ~/.openclaw/config/.env
  
  5. Inicie:
     openclaw daemon start
═══════════════════════════════════════════════════════════════
EOF

log_success "Documentação salva: $INFO_FILE"

#-------------------------------------------------------------------------------
# PASSO 8: Upload S3 (opcional)
#-------------------------------------------------------------------------------
if [ "$1" == "--upload-s3" ] && [ -n "$2" ]; then
    echo -e "${YELLOW}[8/8] Upload para S3...${NC}"
    S3_BUCKET=$2
    
    if command -v aws &> /dev/null; then
        aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/backups/"
        aws s3 cp "$INFO_FILE" "s3://$S3_BUCKET/backups/"
        log_success "Upload para s3://$S3_BUCKET/backups/ concluído!"
    else
        log_warning "AWS CLI não instalado. Pulando upload S3."
    fi
else
    echo -e "${YELLOW}[8/8] Upload S3 pulado (use --upload-s3 bucket-name)${NC}"
fi

#-------------------------------------------------------------------------------
# REINICIAR OPENCLAW
#-------------------------------------------------------------------------------
echo ""
read -p "Deseja reiniciar o OpenClaw agora? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    if command -v openclaw &> /dev/null; then
        openclaw daemon start
        log_success "OpenClaw reiniciado!"
    fi
fi

#-------------------------------------------------------------------------------
# RESUMO FINAL
#-------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ BACKUP CONCLUÍDO COM SUCESSO!                         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📁 Arquivos gerados:${NC}"
echo "   $BACKUP_FILE"
[ -f "$ENV_BACKUP" ] && echo "   $ENV_BACKUP (criptografado)"
[ -f "$BACKUP_DIR/env-$TIMESTAMP.env" ] && echo "   $BACKUP_DIR/env-$TIMESTAMP.env"
echo "   $INFO_FILE"
echo ""
echo -e "${BLUE}📋 Próximos passos:${NC}"
echo "   1. Baixe o backup pro seu PC:"
echo "      scp usuario@servidor:$BACKUP_FILE ./"
echo ""
echo "   2. Guarde em local seguro (Google Drive, S3, etc.)"
echo ""
echo "   3. Para restaurar em outro servidor, veja:"
echo "      cat $INFO_FILE"
echo ""
echo -e "${GREEN}🦅 Backup criado por Águia — Comunidade Cultura Builder${NC}"
