# 🔒 Guia Completo de Segurança para Agentes de IA

**Autor:** Águia 🦅 (com contribuições do Miqueias e comunidade CB)  
**Versão:** 1.0  
**Data:** 2026-02-06  
**Público:** Desenvolvedores e integradores que deployam agentes de IA para clientes

---

## 📋 Índice

1. [Filosofia de Segurança](#1-filosofia-de-segurança)
2. [Preparação do Ambiente](#2-preparação-do-ambiente)
3. [Instalação Segura](#3-instalação-segura)
4. [Configuração de Credenciais](#4-configuração-de-credenciais)
5. [Permissões e Isolamento](#5-permissões-e-isolamento)
6. [Monitoramento e Logs](#6-monitoramento-e-logs)
7. [Prevenção de Problemas](#7-prevenção-de-problemas)
8. [🚨 CHAVE MESTRE — Procedimentos de Emergência](#8--chave-mestre--procedimentos-de-emergência)
9. [Checklist de Deploy](#9-checklist-de-deploy)
10. [Comunicação com Cliente](#10-comunicação-com-cliente)

---

## 1. Filosofia de Segurança

### Princípios Fundamentais

1. **Mínimo Privilégio** — O agente só tem acesso ao que PRECISA, nada mais
2. **Defesa em Profundidade** — Múltiplas camadas de proteção
3. **Falha Segura** — Se algo der errado, o sistema para, não continua
4. **Auditabilidade** — Tudo deve ser rastreável via logs
5. **Transparência** — Cliente deve entender o que o agente faz

### Antes de Vender, Pergunte-se:

> "Se esse agente for hackeado ou rodar descontrolado, qual o pior cenário?"

Se a resposta te assusta, adicione mais proteções.

---

## 2. Preparação do Ambiente

### 2.1 Escolha da Infraestrutura

| Opção | Prós | Contras | Recomendado para |
|-------|------|---------|------------------|
| **VPS (AWS, DigitalOcean)** | Isolado, uptime 24/7 | Custo mensal | Produção |
| **Notebook local** | Grátis, fácil | Risco se roubado, offline | Desenvolvimento |
| **Docker local** | Isolado, portátil | Complexidade | Testes |
| **Raspberry Pi** | Barato, dedicado | Pouca potência | IoT/Home |

**Recomendação:** Para clientes, sempre VPS com backup.

### 2.2 Preparação do Sistema (Ubuntu/Debian)

```bash
# 1. Atualizar TUDO antes de começar
sudo apt update && sudo apt upgrade -y

# 2. Instalar ferramentas essenciais
sudo apt install -y \
    curl \
    wget \
    git \
    ufw \
    fail2ban \
    htop \
    tmux \
    auditd \
    inotify-tools \
    unattended-upgrades

# 3. Configurar atualizações automáticas de segurança
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 2.3 Criar Usuário Dedicado (NUNCA use root!)

```bash
# Criar usuário específico para o agente
sudo adduser agente-bot --disabled-password

# Adicionar ao grupo sudo (opcional, só se necessário)
# sudo usermod -aG sudo agente-bot

# Logar como o usuário
sudo su - agente-bot
```

**Por que usuário dedicado?**
- Isola permissões
- Facilita monitoramento
- Se comprometido, não afeta o sistema inteiro

---

## 3. Instalação Segura

### 3.1 Estrutura de Diretórios Recomendada

```
/home/agente-bot/
├── app/                    # Código do agente
│   └── clawdbot/          # ou openclaw/
├── config/                 # Configurações (700)
│   ├── .env               # Variáveis de ambiente (600)
│   └── config.json        # Config do agente (600)
├── data/                   # Dados persistentes
│   ├── memory/            # Memória do agente
│   └── logs/              # Logs locais
├── backups/               # Backups automáticos
└── scripts/               # Scripts de manutenção
    ├── start.sh
    ├── stop.sh
    ├── backup.sh
    └── emergency-stop.sh
```

### 3.2 Configurar Permissões

```bash
# Aplicar permissões corretas
chmod 700 ~/config
chmod 600 ~/config/.env
chmod 600 ~/config/config.json
chmod 755 ~/scripts/*.sh

# Verificar
ls -la ~/config/
# Deve mostrar: -rw------- (600) para arquivos sensíveis
```

### 3.3 Instalação do Agente (exemplo Clawdbot)

```bash
# Instalar Node.js (se necessário)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Instalar Clawdbot
sudo npm install -g clawdbot

# Configurar
clawdbot onboard

# Verificar instalação
clawdbot status
```

---

## 4. Configuração de Credenciais

### 4.1 NUNCA Faça Isso ❌

```bash
# ERRADO - API key no código
const apiKey = "sk-ant-xxxxx"  # NUNCA!

# ERRADO - Permissão aberta
chmod 777 .env  # NUNCA!

# ERRADO - Commitar credenciais
git add .env  # NUNCA!
```

### 4.2 Faça Isso ✅

```bash
# Criar arquivo .env protegido
touch ~/config/.env
chmod 600 ~/config/.env

# Editar com suas keys
nano ~/config/.env
```

**Conteúdo do .env:**
```bash
# API Keys (nunca compartilhe!)
ANTHROPIC_API_KEY=sk-ant-xxx
OPENAI_API_KEY=sk-xxx

# Configurações
NODE_ENV=production
LOG_LEVEL=info

# Limites de segurança
MAX_TOKENS_PER_REQUEST=4096
MAX_REQUESTS_PER_MINUTE=60
```

### 4.3 Carregar Variáveis de Ambiente

```bash
# No script de start (start.sh)
#!/bin/bash
set -a
source ~/config/.env
set +a

# Iniciar o agente
clawdbot gateway start
```

### 4.4 Git Ignore (OBRIGATÓRIO)

```bash
# Criar .gitignore
cat > .gitignore << 'EOF'
# Credenciais - NUNCA commitar
.env
*.key
*.pem
config/secrets/
auth-profiles.json

# Logs podem conter dados sensíveis
*.log
logs/

# Dados do usuário
data/
memory/
EOF
```

---

## 5. Permissões e Isolamento

### 5.1 Tabela de Permissões Linux

| Permissão | Octal | Significado | Usar para |
|-----------|-------|-------------|-----------|
| `rwx------` | 700 | Só dono (total) | Pastas de config |
| `rw-------` | 600 | Só dono (sem exec) | Arquivos .env, keys |
| `rwxr-xr-x` | 755 | Dono total, outros leem | Scripts, executáveis |
| `rw-r--r--` | 644 | Dono escreve, outros leem | Docs, configs públicos |
| `rwxrwxrwx` | 777 | Todos fazem tudo | **NUNCA USE** |

### 5.2 Firewall (ufw)

```bash
# Habilitar firewall
sudo ufw enable

# Política padrão: negar tudo que entra
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Liberar apenas SSH (ajuste a porta se mudou)
sudo ufw allow 22/tcp

# Liberar porta do agente (se necessário acesso externo)
# sudo ufw allow 18789/tcp  # Só se REALMENTE precisar

# Ver status
sudo ufw status verbose
```

### 5.3 Fail2ban (proteção contra brute force)

```bash
# Configurar
sudo nano /etc/fail2ban/jail.local
```

```ini
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
```

```bash
# Reiniciar
sudo systemctl restart fail2ban

# Ver banidos
sudo fail2ban-client status sshd
```

### 5.4 Isolamento com Docker (Avançado)

```bash
# Dockerfile seguro
cat > Dockerfile << 'EOF'
FROM node:20-slim

# Usuário não-root
RUN useradd -m -s /bin/bash agente
USER agente
WORKDIR /home/agente/app

# Copiar apenas o necessário
COPY --chown=agente:agente package*.json ./
RUN npm ci --only=production

COPY --chown=agente:agente . .

# Porta (não expor se não precisar)
# EXPOSE 18789

CMD ["node", "index.js"]
EOF

# Rodar com restrições
docker run -d \
    --name meu-agente \
    --restart unless-stopped \
    --memory=1g \
    --cpus=1 \
    --read-only \
    --tmpfs /tmp \
    --network=bridge \
    --env-file ~/config/.env \
    -v ~/data:/home/agente/data \
    meu-agente:latest
```

---

## 6. Monitoramento e Logs

### 6.1 Ver Logs em Tempo Real

```bash
# Se usa systemd
journalctl -u clawdbot -f --no-pager

# Se usa PM2
pm2 logs agente --lines 100

# Se usa Docker
docker logs -f --tail 100 meu-agente

# Log genérico do sistema
tail -f /var/log/syslog | grep agente
```

### 6.2 Monitorar Processos

```bash
# Ver processos do agente
ps aux | grep -E "(node|clawdbot|agente)"

# Monitorar uso de recursos em tempo real
htop -u agente-bot

# Ver árvore de processos
pstree -p agente-bot
```

### 6.3 Monitorar Comandos Executados (Auditoria)

```bash
# Configurar auditd para monitorar execuções
sudo auditctl -a always,exit -F arch=b64 -S execve -F uid=$(id -u agente-bot)

# Ver execuções recentes
sudo ausearch -ua agente-bot -ts recent

# Relatório formatado
sudo aureport -x --summary
```

### 6.4 Monitorar Arquivos Modificados

```bash
# Instalar inotify
sudo apt install inotify-tools

# Monitorar pasta do agente
inotifywait -mr --timefmt '%Y-%m-%d %H:%M:%S' --format '%T %w%f %e' \
    -e modify,create,delete,move \
    /home/agente-bot/

# Em background (salvar em log)
nohup inotifywait -mr --timefmt '%Y-%m-%d %H:%M:%S' --format '%T %w%f %e' \
    -e modify,create,delete,move \
    /home/agente-bot/ >> ~/data/logs/file-changes.log 2>&1 &
```

### 6.5 Monitorar Rede

```bash
# Conexões ativas do agente
ss -tunap | grep agente

# Tráfego de rede (requer root)
sudo tcpdump -i any -n host api.anthropic.com

# Conexões suspeitas (IPs estranhos)
sudo netstat -tunap | grep ESTABLISHED | grep agente
```

### 6.6 Alertas Automáticos (script)

```bash
# Criar script de monitoramento
cat > ~/scripts/monitor.sh << 'EOF'
#!/bin/bash

# Verificar se agente está rodando
if ! pgrep -f "clawdbot" > /dev/null; then
    echo "[ALERTA] Agente não está rodando!" | \
        mail -s "Agente Parado" seu@email.com
fi

# Verificar uso de CPU
CPU=$(ps aux | grep clawdbot | grep -v grep | awk '{print $3}')
if (( $(echo "$CPU > 90" | bc -l) )); then
    echo "[ALERTA] CPU alta: $CPU%" | \
        mail -s "CPU Alta" seu@email.com
fi

# Verificar disco
DISK=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK" -gt 90 ]; then
    echo "[ALERTA] Disco em $DISK%" | \
        mail -s "Disco Cheio" seu@email.com
fi
EOF

chmod +x ~/scripts/monitor.sh

# Agendar a cada 5 minutos
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/scripts/monitor.sh") | crontab -
```

---

## 7. Prevenção de Problemas

### 7.1 Limitar Recursos do Agente

**Com systemd:**
```bash
# Criar override
sudo systemctl edit clawdbot

# Adicionar limites
[Service]
MemoryMax=2G
CPUQuota=100%
TasksMax=50
```

**Com PM2:**
```bash
pm2 start app.js --max-memory-restart 1G
```

### 7.2 Rate Limiting

No config do agente:
```json
{
  "limits": {
    "maxRequestsPerMinute": 60,
    "maxTokensPerRequest": 4096,
    "maxConcurrentSessions": 4
  }
}
```

### 7.3 Comandos Permitidos (Allowlist)

No Clawdbot (`clawdbot.json`):
```json
{
  "tools": {
    "exec": {
      "security": "allowlist",
      "allowlist": [
        "ls", "cat", "echo", "date",
        "git status", "git log"
      ]
    }
  }
}
```

### 7.4 Backup Automático

```bash
# Script de backup
cat > ~/scripts/backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y-%m-%d_%H%M)
BACKUP_DIR=~/backups

# Criar backup
tar -czf $BACKUP_DIR/agente-$DATE.tar.gz \
    --exclude='*.log' \
    --exclude='node_modules' \
    ~/config ~/data

# Manter apenas últimos 7 dias
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup criado: agente-$DATE.tar.gz"
EOF

chmod +x ~/scripts/backup.sh

# Agendar diário às 3h
(crontab -l 2>/dev/null; echo "0 3 * * * ~/scripts/backup.sh") | crontab -
```

### 7.5 Logs Rotativos

```bash
# Configurar logrotate
sudo nano /etc/logrotate.d/agente
```

```
/home/agente-bot/data/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 agente-bot agente-bot
}
```

---

## 8. 🚨 CHAVE MESTRE — Procedimentos de Emergência

### 8.1 Níveis de Emergência

| Nível | Situação | Ação |
|-------|----------|------|
| 🟡 **Amarelo** | Agente lento/travado | Reiniciar serviço |
| 🟠 **Laranja** | Comportamento estranho | Parar e analisar logs |
| 🔴 **Vermelho** | Executando comandos suspeitos | PARAR TUDO imediatamente |
| ⚫ **Crítico** | Possível invasão | Desconectar rede + análise forense |

### 8.2 Script de Parada de Emergência

```bash
# Criar script ~/scripts/emergency-stop.sh
cat > ~/scripts/emergency-stop.sh << 'EOF'
#!/bin/bash
echo "🚨 PARADA DE EMERGÊNCIA INICIADA"
echo "================================"

# 1. Parar serviço do agente
echo "[1/5] Parando serviço..."
sudo systemctl stop clawdbot 2>/dev/null
pm2 stop all 2>/dev/null
docker stop $(docker ps -q) 2>/dev/null

# 2. Matar todos os processos do usuário agente
echo "[2/5] Matando processos..."
sudo pkill -u agente-bot

# 3. Bloquear rede do agente (impedir exfiltração)
echo "[3/5] Bloqueando rede..."
sudo iptables -A OUTPUT -m owner --uid-owner $(id -u agente-bot) -j DROP

# 4. Salvar estado atual para análise
echo "[4/5] Salvando estado..."
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p ~/emergency-dumps/$DATE
ps aux > ~/emergency-dumps/$DATE/processes.txt
ss -tunap > ~/emergency-dumps/$DATE/connections.txt
sudo cp /var/log/syslog ~/emergency-dumps/$DATE/
sudo cp /var/log/auth.log ~/emergency-dumps/$DATE/

# 5. Notificar
echo "[5/5] Emergência executada em $(date)"
echo "Dumps salvos em: ~/emergency-dumps/$DATE"
echo ""
echo "PRÓXIMOS PASSOS:"
echo "1. Analisar logs em ~/emergency-dumps/$DATE/"
echo "2. Verificar o que causou o problema"
echo "3. Corrigir antes de reiniciar"
echo "4. Para restaurar rede: sudo iptables -D OUTPUT -m owner --uid-owner $(id -u agente-bot) -j DROP"
EOF

chmod +x ~/scripts/emergency-stop.sh
```

### 8.3 Comandos de Emergência Rápidos

```bash
# ⚡ PARAR AGENTE (normal)
sudo systemctl stop clawdbot
# ou
pm2 stop agente

# ⚡ MATAR TUDO DO AGENTE (forçado)
sudo pkill -9 -u agente-bot

# ⚡ BLOQUEAR REDE DO AGENTE (impedir comunicação)
sudo iptables -A OUTPUT -m owner --uid-owner $(id -u agente-bot) -j DROP

# ⚡ VER O QUE ESTÁ RODANDO
ps aux | grep agente-bot
sudo lsof -u agente-bot

# ⚡ VER CONEXÕES DE REDE
sudo ss -tunap | grep agente

# ⚡ VER ÚLTIMOS COMANDOS EXECUTADOS
sudo ausearch -ua agente-bot -ts recent | tail -50

# ⚡ VER ÚLTIMOS ARQUIVOS MODIFICADOS
find /home/agente-bot -mmin -5 -type f

# ⚡ DESBLOQUEAR REDE (após análise)
sudo iptables -D OUTPUT -m owner --uid-owner $(id -u agente-bot) -j DROP
```

### 8.4 Análise Pós-Incidente

```bash
# 1. Ver logs do momento do problema
journalctl -u clawdbot --since "1 hour ago" | less

# 2. Verificar comandos executados
sudo ausearch -ts today -m EXECVE | grep agente-bot

# 3. Verificar arquivos criados/modificados
find /home/agente-bot -mtime -1 -ls

# 4. Verificar conexões feitas
grep agente /var/log/syslog | grep -i "connect"

# 5. Verificar se houve tentativa de escalar privilégio
grep -i "sudo" /var/log/auth.log | grep agente
```

### 8.5 Restauração Segura

```bash
# 1. Verificar que o problema foi identificado e corrigido
# 2. Restaurar rede (se bloqueou)
sudo iptables -D OUTPUT -m owner --uid-owner $(id -u agente-bot) -j DROP

# 3. Verificar configs antes de reiniciar
cat ~/config/.env | grep -v KEY  # Ver config sem expor keys

# 4. Reiniciar com monitoramento
sudo systemctl start clawdbot && journalctl -u clawdbot -f
```

---

## 9. Checklist de Deploy

### Antes de entregar para o cliente:

- [ ] **Infraestrutura**
  - [ ] VPS/servidor provisionado
  - [ ] Sistema atualizado (`apt upgrade`)
  - [ ] Usuário dedicado criado (não root)

- [ ] **Segurança**
  - [ ] Firewall ativo (ufw)
  - [ ] Fail2ban configurado
  - [ ] SSH apenas por chave (não senha)
  - [ ] Permissões de arquivos corretas (600/700)

- [ ] **Credenciais**
  - [ ] API keys em .env protegido
  - [ ] .gitignore configurado
  - [ ] Nenhuma key hardcoded

- [ ] **Agente**
  - [ ] Instalado e funcionando
  - [ ] Comandos limitados (allowlist)
  - [ ] Rate limiting configurado
  - [ ] Logs funcionando

- [ ] **Monitoramento**
  - [ ] Logs acessíveis
  - [ ] Alertas configurados
  - [ ] Auditd habilitado

- [ ] **Backup & Recovery**
  - [ ] Backup automático configurado
  - [ ] Script de emergência testado
  - [ ] Documentação entregue

- [ ] **Documentação**
  - [ ] Como iniciar/parar
  - [ ] Como ver logs
  - [ ] Contato de emergência
  - [ ] O que o agente pode/não pode fazer

---

## 10. Comunicação com Cliente

### Template de Entrega

```
Prezado(a) [Cliente],

Seu agente de IA está configurado e pronto para uso.

📍 ACESSO:
- Servidor: [IP ou domínio]
- Usuário: agente-bot
- Como conectar: ssh agente-bot@servidor

🚀 COMANDOS BÁSICOS:
- Iniciar: sudo systemctl start clawdbot
- Parar: sudo systemctl stop clawdbot
- Status: sudo systemctl status clawdbot
- Ver logs: journalctl -u clawdbot -f

🔒 SEGURANÇA:
- Credenciais protegidas em ~/config/.env
- Firewall ativo, apenas porta SSH aberta
- Backups diários às 3h
- Logs mantidos por 7 dias

🚨 EM CASO DE EMERGÊNCIA:
- Parar tudo: ~/scripts/emergency-stop.sh
- Contato: [seu telefone/email]

📋 O QUE O AGENTE FAZ:
- [Lista de capacidades]

🚫 O QUE O AGENTE NÃO FAZ:
- [Lista de limitações]

Qualquer dúvida, estou à disposição.
```

### Explicação Simplificada para Cliente Leigo

> "Pense no agente como um funcionário digital. Ele tem:
> - Um escritório próprio (servidor isolado)
> - Um crachá com acesso limitado (permissões)
> - Câmeras monitorando (logs)
> - Um botão de pânico (script de emergência)
> 
> Se algo der errado, podemos ver exatamente o que aconteceu e resolver rápido."

---

## 📚 Referências

- [Clawdbot Docs](https://docs.clawd.bot)
- [OpenClaw GitHub](https://github.com/openclaw)
- [Linux Security Hardening](https://wiki.ubuntu.com/Security)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [OWASP LLM Top 10](https://owasp.org/www-project-top-10-for-large-language-model-applications/)

---

## 🤝 Contribuições

Este guia foi criado pela comunidade Cultura Builder. Sugestões e correções são bem-vindas!

- Miqueias Ruben — Questionamentos de segurança e visão crítica
- Comunidade CB — Discussões e casos reais

---

*Última atualização: 2026-02-06*
*Versão: 1.0*
