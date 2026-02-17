-- ============================================================================
-- 🦅 OPENCLAW MULTI-BOT — SCHEMA SUPABASE
-- Comunidade Cultura Builder
-- ============================================================================

-- Schema admin (global)
CREATE SCHEMA IF NOT EXISTS admin;

-- ============================================================================
-- TABELA: admin.bots — Registro de todos os bots
-- ============================================================================
CREATE TABLE admin.bots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    client_name VARCHAR(200),
    client_email VARCHAR(200),
    client_phone VARCHAR(50),
    railway_service_id VARCHAR(100),
    railway_project_id VARCHAR(100),
    llm_provider VARCHAR(50) NOT NULL DEFAULT 'deepseek',  -- deepseek, glm, ollama, openai, anthropic
    llm_model VARCHAR(100) NOT NULL DEFAULT 'deepseek-chat',
    status VARCHAR(20) NOT NULL DEFAULT 'active',  -- active, paused, suspended, deleted
    schema_name VARCHAR(100) NOT NULL,  -- schema isolado no supabase
    monthly_cost DECIMAL(10,2) DEFAULT 0,
    monthly_revenue DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- ============================================================================
-- TABELA: admin.billing — Controle financeiro
-- ============================================================================
CREATE TABLE admin.billing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id UUID REFERENCES admin.bots(id) ON DELETE CASCADE,
    month DATE NOT NULL,  -- primeiro dia do mês
    llm_cost DECIMAL(10,2) DEFAULT 0,
    railway_cost DECIMAL(10,2) DEFAULT 0,
    total_cost DECIMAL(10,2) DEFAULT 0,
    revenue DECIMAL(10,2) DEFAULT 0,
    profit DECIMAL(10,2) DEFAULT 0,
    token_count BIGINT DEFAULT 0,
    message_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(bot_id, month)
);

-- ============================================================================
-- TABELA: admin.logs — Log centralizado
-- ============================================================================
CREATE TABLE admin.logs (
    id BIGSERIAL PRIMARY KEY,
    bot_id UUID REFERENCES admin.bots(id) ON DELETE CASCADE,
    level VARCHAR(10) NOT NULL DEFAULT 'info',  -- debug, info, warn, error, fatal
    category VARCHAR(50),  -- auth, message, llm, system, security
    message TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index para queries rápidas
CREATE INDEX idx_logs_bot_created ON admin.logs(bot_id, created_at DESC);
CREATE INDEX idx_logs_level ON admin.logs(level) WHERE level IN ('error', 'fatal');

-- ============================================================================
-- FUNÇÃO: Criar schema isolado para novo bot
-- ============================================================================
CREATE OR REPLACE FUNCTION admin.create_bot_schema(bot_name TEXT)
RETURNS TEXT AS $$
DECLARE
    schema_name TEXT;
BEGIN
    -- Sanitizar nome do schema
    schema_name := 'bot_' || regexp_replace(lower(bot_name), '[^a-z0-9]', '_', 'g');
    
    -- Criar schema
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_name);
    
    -- Tabela de mensagens
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.messages (
            id BIGSERIAL PRIMARY KEY,
            session_id VARCHAR(100),
            role VARCHAR(20) NOT NULL,  -- user, assistant, system
            content TEXT NOT NULL,
            channel VARCHAR(50),  -- whatsapp, telegram, discord, web
            sender_id VARCHAR(100),
            sender_name VARCHAR(200),
            metadata JSONB DEFAULT ''{}''::jsonb,
            created_at TIMESTAMPTZ DEFAULT NOW()
        )', schema_name);
    
    -- Tabela de memórias
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.memories (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            key VARCHAR(200) NOT NULL,
            value TEXT NOT NULL,
            category VARCHAR(50) DEFAULT ''general'',  -- general, user, preference, fact, rule
            importance INTEGER DEFAULT 5,  -- 1-10
            expires_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )', schema_name);
    
    -- Tabela de configurações
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.config (
            key VARCHAR(200) PRIMARY KEY,
            value JSONB NOT NULL,
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )', schema_name);
    
    -- Tabela de sessões
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.sessions (
            id VARCHAR(100) PRIMARY KEY,
            channel VARCHAR(50),
            user_id VARCHAR(100),
            user_name VARCHAR(200),
            status VARCHAR(20) DEFAULT ''active'',
            last_message_at TIMESTAMPTZ DEFAULT NOW(),
            message_count INTEGER DEFAULT 0,
            metadata JSONB DEFAULT ''{}''::jsonb,
            created_at TIMESTAMPTZ DEFAULT NOW()
        )', schema_name);
    
    -- Tabela de analytics
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.analytics (
            id BIGSERIAL PRIMARY KEY,
            date DATE NOT NULL,
            messages_in INTEGER DEFAULT 0,
            messages_out INTEGER DEFAULT 0,
            tokens_used BIGINT DEFAULT 0,
            unique_users INTEGER DEFAULT 0,
            avg_response_time_ms INTEGER DEFAULT 0,
            errors INTEGER DEFAULT 0,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            UNIQUE(date)
        )', schema_name);
    
    -- Indexes
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_messages_session ON %I.messages(session_id, created_at DESC)', 
        regexp_replace(schema_name, '[^a-z0-9]', '', 'g'), schema_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_messages_created ON %I.messages(created_at DESC)', 
        regexp_replace(schema_name, '[^a-z0-9]', '', 'g'), schema_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_memories_key ON %I.memories(key)', 
        regexp_replace(schema_name, '[^a-z0-9]', '', 'g'), schema_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_memories_category ON %I.memories(category)', 
        regexp_replace(schema_name, '[^a-z0-9]', '', 'g'), schema_name);
    
    RETURN schema_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNÇÃO: Registrar novo bot
-- ============================================================================
CREATE OR REPLACE FUNCTION admin.register_bot(
    p_name TEXT,
    p_client_name TEXT DEFAULT NULL,
    p_client_email TEXT DEFAULT NULL,
    p_llm_provider TEXT DEFAULT 'deepseek',
    p_llm_model TEXT DEFAULT 'deepseek-chat'
)
RETURNS UUID AS $$
DECLARE
    v_schema TEXT;
    v_bot_id UUID;
BEGIN
    -- Criar schema isolado
    v_schema := admin.create_bot_schema(p_name);
    
    -- Inserir bot
    INSERT INTO admin.bots (name, client_name, client_email, llm_provider, llm_model, schema_name)
    VALUES (p_name, p_client_name, p_client_email, p_llm_provider, p_llm_model, v_schema)
    RETURNING id INTO v_bot_id;
    
    -- Log
    INSERT INTO admin.logs (bot_id, level, category, message)
    VALUES (v_bot_id, 'info', 'system', format('Bot %s criado com schema %s', p_name, v_schema));
    
    RETURN v_bot_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNÇÃO: Dashboard rápido
-- ============================================================================
CREATE OR REPLACE FUNCTION admin.dashboard()
RETURNS TABLE (
    total_bots BIGINT,
    active_bots BIGINT,
    total_monthly_cost DECIMAL,
    total_monthly_revenue DECIMAL,
    total_profit DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT,
        COUNT(*) FILTER (WHERE status = 'active')::BIGINT,
        COALESCE(SUM(monthly_cost), 0)::DECIMAL,
        COALESCE(SUM(monthly_revenue), 0)::DECIMAL,
        COALESCE(SUM(monthly_revenue - monthly_cost), 0)::DECIMAL
    FROM admin.bots;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGER: Auto-update updated_at
-- ============================================================================
CREATE OR REPLACE FUNCTION admin.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_bots_updated
    BEFORE UPDATE ON admin.bots
    FOR EACH ROW EXECUTE FUNCTION admin.update_timestamp();
