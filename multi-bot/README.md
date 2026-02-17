# 🦅 OpenClaw Multi-Bot — Guia Completo

Deploy de múltiplos bots OpenClaw no Railway com Supabase, isolados e seguros.

## 📐 Arquitetura

```
┌─────────────────────────────────────────────────────┐
│                    SEUS CLIENTES                     │
│  WhatsApp  │  Telegram  │  Discord  │  Web Chat     │
└──────┬─────┴─────┬──────┴─────┬─────┴──────┬────────┘
       │           │            │            │
┌──────▼───────────▼────────────▼────────────▼────────┐
│                  RAILWAY (Pro $20/mês)                │
│                                                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │  Bot #1  │ │  Bot #2  │ │  Bot #N  │  ...       │
│  │ OpenClaw │ │ OpenClaw │ │ OpenClaw │            │
│  │ Volume 📁│ │ Volume 📁│ │ Volume 📁│            │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘            │
│       │             │            │                   │
└───────┼─────────────┼────────────┼───────────────────┘
        │             │            │
┌───────▼─────────────▼────────────▼───────────────────┐
│              SUPABASE (Free / Pro)                     │
│                                                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│  │ bot_1_*  │ │ bot_2_*  │ │ bot_n_*  │  Schemas    │
│  │ messages │ │ messages │ │ messages │  isolados   │
│  │ memory   │ │ memory   │ │ memory   │              │
│  │ config   │ │ config   │ │ config   │              │
│  └──────────┘ └──────────┘ └──────────┘              │
│                                                        │
│  ┌─────────────────────────────────────┐              │
│  │        admin (schema global)         │              │
│  │  bots │ clients │ billing │ logs    │              │
│  └─────────────────────────────────────┘              │
└────────────────────────────────────────────────────────┘
        │
┌───────▼──────────────────────────────────────────────┐
│              LLM PROVIDERS (escolha)                   │
│                                                        │
│  💰 Grátis:     Ollama local (CPU, lento)              │
│  💵 Barato:     DeepSeek ($2-3/mês) | GLM ($3/mês)    │
│  💵 Médio:      Haiku 3.5 ($5-10/mês)                 │
│  💎 Premium:    Sonnet 4 ($15-20/mês) | GPT-4o         │
│  👑 Top:        Opus 4.6 ($50+/mês)                    │
└────────────────────────────────────────────────────────┘
```

## 💰 Custos Estimados

| Componente | Plano | Custo |
|-----------|-------|-------|
| Railway Pro | 50 instâncias | $20/mês |
| Supabase Free | 500MB, 50k rows | $0/mês |
| Supabase Pro | 8GB, unlimited | $25/mês |
| DeepSeek (por bot) | API | ~$2-3/mês |
| GLM/Z.ai (por bot) | API | ~$3/mês |

**Exemplo: 10 bots com DeepSeek**
- Railway: $20 + Supabase Free: $0 + DeepSeek: $30 = **$50/mês total**
- Cobrando R$50/bot/mês = R$500 receita → **~R$250 lucro**

**Exemplo: 30 bots com GLM**
- Railway: $20 + Supabase Pro: $25 + GLM: $90 = **$135/mês**
- Cobrando R$50/bot/mês = R$1.500 receita → **~R$750 lucro**

## 📁 Estrutura do Repositório

```
openclaw-multi-bot/
├── README.md                    # Este arquivo
├── scripts/
│   ├── setup-all.sh            # Setup completo (tudo de uma vez)
│   ├── setup-railway.sh        # Configurar Railway
│   ├── setup-supabase.sh       # Configurar Supabase
│   ├── deploy-bot.sh           # Deploy de um bot individual
│   ├── backup-bot.sh           # Backup de um bot
│   └── monitor-bots.sh         # Monitoramento
├── configs/
│   ├── openclaw-template.json  # Template de config do OpenClaw
│   ├── deepseek.env            # Template .env DeepSeek
│   ├── glm.env                 # Template .env GLM
│   └── ollama.env              # Template .env Ollama
├── supabase/
│   ├── schema.sql              # Schema completo
│   ├── rls-policies.sql        # Row Level Security
│   └── functions.sql           # Funções úteis
├── railway/
│   ├── Dockerfile              # Imagem do bot
│   ├── railway.toml            # Config Railway
│   ├── start.sh                # Script de inicialização
│   └── nixpacks.toml           # Build config
├── docs/
│   ├── SEGURANCA.md            # Guia de segurança
│   ├── TROUBLESHOOTING.md      # Resolução de problemas
│   └── PRICING.md              # Detalhamento de custos
└── .gitignore
```

## 🚀 Quick Start

### Opção 1: Setup completo (recomendado)

```bash
git clone https://github.com/BrunoPessoa22/openclaw-multi-bot.git
cd openclaw-multi-bot
chmod +x scripts/*.sh
./scripts/setup-all.sh
```

### Opção 2: Passo a passo manual

Siga as seções abaixo na ordem.

---

## 📋 Pré-requisitos

- Conta no [Railway](https://railway.com) (Pro, $20/mês)
- Conta no [Supabase](https://supabase.com) (Free ou Pro)
- API key de um LLM provider (DeepSeek, GLM, ou outro)
- [Railway CLI](https://docs.railway.app/develop/cli) instalado
- Node.js 20+ instalado localmente (para testes)

```bash
# Instalar Railway CLI
npm install -g @railway/cli

# Login
railway login
```

---

## Parte 1: Configurar Supabase

### 1.1 Criar projeto

1. Acesse [supabase.com](https://supabase.com)
2. Crie um novo projeto
3. Anote: **Project URL**, **anon key**, **service_role key**

### 1.2 Executar schema

No SQL Editor do Supabase, cole e execute o conteúdo de `supabase/schema.sql`:

```sql
-- Cria todas as tabelas necessárias
-- Ver arquivo supabase/schema.sql
```

### 1.3 Configurar RLS (Row Level Security)

Execute `supabase/rls-policies.sql` no SQL Editor.

---

## Parte 2: Configurar Railway

### 2.1 Criar projeto

```bash
# Criar novo projeto
railway init

# Ou linkar projeto existente
railway link
```

### 2.2 Deploy do primeiro bot

```bash
./scripts/deploy-bot.sh \
  --name "bot-cliente1" \
  --provider "deepseek" \
  --api-key "sk-xxx" \
  --supabase-url "https://xxx.supabase.co" \
  --supabase-key "xxx"
```

### 2.3 Configurar volume persistente

No dashboard do Railway:
1. Selecione o serviço
2. Settings → Volumes
3. Add Volume: mount em `/home/user/.openclaw`

---

## Parte 3: Configurar OpenClaw no Bot

### 3.1 Escolher provider

**DeepSeek (recomendado custo-benefício):**
```bash
# API key: https://platform.deepseek.com
export LLM_PROVIDER=deepseek
export DEEPSEEK_API_KEY=sk-xxx
export LLM_MODEL=deepseek-chat
```

**GLM/Z.ai:**
```bash
# API key: https://z.ai/subscribe
export LLM_PROVIDER=glm
export GLM_API_KEY=xxx
export LLM_MODEL=glm-4
```

**Ollama (grátis, mais lento):**
```bash
# Roda local no mesmo container
export LLM_PROVIDER=ollama
export OLLAMA_BASE_URL=http://localhost:11434
export LLM_MODEL=llama3.1:8b
```

### 3.2 Personalizar bot

Edite os arquivos em `~/.openclaw/agents/main/agent/`:
- `SOUL.md` — Personalidade do bot
- `USER.md` — Dados do cliente
- `IDENTITY.md` — Nome e identidade
- `TOOLS.md` — Ferramentas disponíveis

---

## Parte 4: Segurança

### Checklist obrigatório por bot:

- [ ] `.env` com chmod 600
- [ ] API keys nunca no código
- [ ] Volume persistente configurado
- [ ] RLS ativo no Supabase
- [ ] Cada bot com schema isolado
- [ ] Backup automático configurado
- [ ] Monitoramento ativo

Ver `docs/SEGURANCA.md` para detalhes completos.

---

## 🔧 Scripts Disponíveis

| Script | Descrição |
|--------|-----------|
| `setup-all.sh` | Setup completo do zero |
| `setup-railway.sh` | Configura Railway + CLI |
| `setup-supabase.sh` | Cria schema no Supabase |
| `deploy-bot.sh` | Deploy individual de um bot |
| `backup-bot.sh` | Backup de um bot específico |
| `monitor-bots.sh` | Status de todos os bots |

---

## 📞 Suporte

- **Comunidade:** [Cultura Builder](https://culturabuilder.com)
- **Discord:** CB Community
- **GitHub Issues:** Abra uma issue neste repo

---

## 📜 Licença

MIT — Use e modifique livremente!

---

## 👥 Créditos

- **Marcos** — Idealizador do projeto Multi-Bot, visão de negócio e arquitetura
- **Águia** 🦅 — Desenvolvimento, scripts e documentação
- **Bruno Pessoa** — Infraestrutura e manutenção do repositório
- **Comunidade CB** — Feedback, testes e sugestões

*Criado com 🦅 por Águia — Comunidade Cultura Builder*
