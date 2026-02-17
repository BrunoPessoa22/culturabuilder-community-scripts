# 🔒 Guia de Segurança — OpenClaw Multi-Bot

## Checklist por Bot

- [ ] `.env` com permissão 600 (`chmod 600 .env`)
- [ ] API keys NUNCA no código ou Git
- [ ] Cada bot com schema Supabase isolado
- [ ] RLS (Row Level Security) ativo
- [ ] Volume persistente no Railway
- [ ] Backups automáticos configurados
- [ ] Monitoramento de erros ativo

## Variáveis de Ambiente

**NUNCA** commite `.env` no Git. Use:
- Railway: Variables no dashboard
- Supabase: Secrets no dashboard
- Local: `.env` com chmod 600

## Isolamento

Cada bot tem:
- Schema próprio no Supabase (bot_xxx)
- Volume próprio no Railway
- API key própria
- Configuração independente

Um bot comprometido NÃO afeta os outros.

## Permissões Supabase

Use `service_role` key apenas no backend.
NUNCA exponha `service_role` no frontend.
Use `anon` key para operações públicas.

## Backup

- Backup diário automático (cron)
- Testar restauração mensalmente
- Guardar backups em local separado (S3, Google Drive)

## Monitoramento

- Verificar logs diariamente
- Alertas para erros críticos
- Monitorar custos de API

## Incidentes

Se um bot for comprometido:
1. Revogar API key imediatamente
2. Parar o serviço no Railway
3. Verificar logs
4. Restaurar de backup limpo
5. Gerar nova API key
6. Redeployar
