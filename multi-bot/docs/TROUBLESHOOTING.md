# 🔧 Troubleshooting — OpenClaw Multi-Bot

## Problemas Comuns

### Bot não responde
1. Verificar se o serviço está rodando: `railway status`
2. Verificar logs: `railway logs`
3. Verificar se API key é válida
4. Testar API key manualmente com curl

### Erro de API key
- DeepSeek: Verificar em https://platform.deepseek.com
- GLM: Verificar em https://z.ai
- Regenerar key se necessário

### Volume perdido no Railway
- Verificar se o volume está montado: Settings → Volumes
- Restaurar de backup: `./scripts/backup-bot.sh --restore`

### Supabase schema não criado
1. Abrir SQL Editor no Supabase
2. Colar conteúdo de `supabase/schema.sql`
3. Executar manualmente

### Bot lento (Ollama)
- Normal em CPU (~5-10 tokens/s)
- Considerar trocar para DeepSeek ou GLM
- Usar modelo menor: `mistral:7b` ao invés de `llama3.1:8b`

### Memória não salva
- Verificar se volume está montado
- Verificar permissões: `chmod -R 700 ~/.openclaw`
- Verificar espaço em disco

### Railway deploy falha
1. Verificar Dockerfile
2. Verificar logs de build: `railway logs --build`
3. Verificar variáveis de ambiente
