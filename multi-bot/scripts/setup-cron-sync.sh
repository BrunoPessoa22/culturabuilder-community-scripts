#!/bin/bash
# ============================================================================
# 🦅 CONFIGURAR SYNC AUTOMÁTICO VIA CRON
# Adiciona cron job para sincronizar OpenClaw → Supabase a cada 30 minutos
# e backup diário à meia-noite
#
# Uso: ./setup-cron-sync.sh
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}🦅 Configurando sync automático...${NC}"
echo ""

# Verificar scripts
if [ ! -f "$SCRIPT_DIR/sync-to-supabase.sh" ]; then
    echo "❌ sync-to-supabase.sh não encontrado em $SCRIPT_DIR"
    exit 1
fi

chmod +x "$SCRIPT_DIR/sync-to-supabase.sh"
chmod +x "$SCRIPT_DIR/backup-bot.sh" 2>/dev/null

# Criar diretório de logs
mkdir -p /var/log/openclaw-sync 2>/dev/null || mkdir -p "$HOME/logs"
LOG_DIR=$([ -d /var/log/openclaw-sync ] && echo "/var/log/openclaw-sync" || echo "$HOME/logs")

# Verificar crontab atual
CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")

# Remover entradas anteriores do sync
CLEAN_CRON=$(echo "$CURRENT_CRON" | grep -v "sync-to-supabase\|openclaw-backup-daily" || true)

# Adicionar novas entradas
NEW_CRON="$CLEAN_CRON

# 🦅 OpenClaw Multi-Bot — Sync automático
# Sync para Supabase a cada 30 minutos
*/30 * * * * $SCRIPT_DIR/sync-to-supabase.sh >> $LOG_DIR/sync.log 2>&1

# Backup completo diário às 3:00 AM
0 3 * * * $SCRIPT_DIR/backup-bot.sh --name \"\$(hostname)\" --dir $HOME/backups >> $LOG_DIR/backup.log 2>&1

# Limpeza de logs semanalmente (domingos às 4:00 AM)
0 4 * * 0 find $LOG_DIR -name '*.log' -mtime +30 -delete 2>/dev/null
"

# Aplicar crontab
echo "$NEW_CRON" | crontab -

echo -e "${GREEN}✅ Cron jobs configurados:${NC}"
echo ""
echo "  ⏰ A cada 30 min  → Sync OpenClaw → Supabase"
echo "  ⏰ 03:00 AM       → Backup diário completo"
echo "  ⏰ Dom 04:00 AM   → Limpeza de logs antigos"
echo ""
echo -e "${BLUE}📁 Logs em: $LOG_DIR${NC}"
echo ""

# Verificar
echo -e "${YELLOW}Cron jobs ativos:${NC}"
crontab -l | grep -v "^#" | grep -v "^$" | sed 's/^/  /'

echo ""

# Rodar primeiro sync agora
read -p "Rodar primeiro sync agora? (s/n) [s]: " RUN_NOW
RUN_NOW=${RUN_NOW:-s}

if [[ "$RUN_NOW" =~ ^[Ss]$ ]]; then
    echo ""
    echo -e "${YELLOW}Rodando sync...${NC}"
    $SCRIPT_DIR/sync-to-supabase.sh
fi

echo ""
echo -e "${GREEN}🦅 Sync automático configurado!${NC}"
