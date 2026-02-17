-- ============================================================================
-- 🦅 ROW LEVEL SECURITY — Isolamento entre bots
-- ============================================================================

-- Habilitar RLS nas tabelas admin
ALTER TABLE admin.bots ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin.billing ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin.logs ENABLE ROW LEVEL SECURITY;

-- Política: Apenas service_role pode acessar tabelas admin
CREATE POLICY "admin_only_bots" ON admin.bots
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "admin_only_billing" ON admin.billing
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "admin_only_logs" ON admin.logs
    FOR ALL USING (auth.role() = 'service_role');

-- ============================================================================
-- NOTA: Para schemas de bots individuais (bot_xxx.*), 
-- o acesso é controlado via service_role key no .env de cada bot.
-- Cada bot só conhece seu próprio schema_name.
-- 
-- Para segurança adicional, crie roles PostgreSQL por bot:
--
-- CREATE ROLE bot_cliente1 LOGIN PASSWORD 'xxx';
-- GRANT USAGE ON SCHEMA bot_cliente1 TO bot_cliente1;
-- GRANT ALL ON ALL TABLES IN SCHEMA bot_cliente1 TO bot_cliente1;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA bot_cliente1 TO bot_cliente1;
-- ============================================================================
