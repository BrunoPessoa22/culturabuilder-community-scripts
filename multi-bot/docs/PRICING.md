# 💰 Detalhamento de Custos — OpenClaw Multi-Bot

## Custos Fixos

| Item | Plano | Custo/mês |
|------|-------|-----------|
| Railway Pro | Até 50 instâncias | $20 |
| Supabase Free | 500MB, 50k rows | $0 |
| Supabase Pro | 8GB, unlimited | $25 |

## Custos por Bot (LLM)

| Provider | Modelo | Custo estimado/bot/mês | Qualidade |
|----------|--------|----------------------|-----------|
| Ollama | llama3.1:8b | $0 (CPU) | ⭐⭐⭐ |
| DeepSeek | deepseek-chat | $2-3 | ⭐⭐⭐⭐ |
| GLM | glm-4 | $3 | ⭐⭐⭐⭐ |
| Haiku 3.5 | claude-haiku | $5-10 | ⭐⭐⭐⭐ |
| GPT-4o Mini | gpt-4o-mini | $5-10 | ⭐⭐⭐⭐ |
| Sonnet 4 | claude-sonnet | $15-20 | ⭐⭐⭐⭐⭐ |
| GPT-4o | gpt-4o | $15-20 | ⭐⭐⭐⭐⭐ |

*Estimativa baseada em ~500-1000 mensagens/dia por bot*

## Cenários de Negócio

### 10 bots com DeepSeek
- Railway: $20
- Supabase Free: $0
- DeepSeek (10x): $30
- **Total: $50/mês (~R$250)**
- Cobrando R$50/bot = R$500 → **Lucro: R$250**

### 20 bots com GLM
- Railway: $20
- Supabase Free: $0
- GLM (20x): $60
- **Total: $80/mês (~R$400)**
- Cobrando R$50/bot = R$1.000 → **Lucro: R$600**

### 50 bots com DeepSeek
- Railway: $20
- Supabase Pro: $25
- DeepSeek (50x): $150
- **Total: $195/mês (~R$975)**
- Cobrando R$50/bot = R$2.500 → **Lucro: R$1.525**

## Dicas para Reduzir Custos

1. **Cache de respostas** — Respostas comuns não precisam de LLM
2. **Modelo menor para tarefas simples** — Usar Haiku/Mini para FAQ
3. **Limitar tokens** — Max tokens por resposta
4. **Horário comercial** — Desativar bots fora do horário
5. **Monitorar uso** — Dashboard Supabase + logs
