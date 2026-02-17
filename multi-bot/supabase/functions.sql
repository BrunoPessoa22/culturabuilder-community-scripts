-- ============================================================================
-- 🦅 FUNÇÕES ÚTEIS — Supabase
-- ============================================================================

-- Buscar memórias por categoria
CREATE OR REPLACE FUNCTION admin.get_bot_memories(p_schema TEXT, p_category TEXT DEFAULT NULL)
RETURNS TABLE (key VARCHAR, value TEXT, category VARCHAR, importance INTEGER) AS $$
BEGIN
    IF p_category IS NOT NULL THEN
        RETURN QUERY EXECUTE format(
            'SELECT key, value, category, importance FROM %I.memories WHERE category = $1 ORDER BY importance DESC',
            p_schema
        ) USING p_category;
    ELSE
        RETURN QUERY EXECUTE format(
            'SELECT key, value, category, importance FROM %I.memories ORDER BY importance DESC',
            p_schema
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Estatísticas de um bot
CREATE OR REPLACE FUNCTION admin.bot_stats(p_bot_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_schema TEXT;
    v_result JSONB;
BEGIN
    SELECT schema_name INTO v_schema FROM admin.bots WHERE id = p_bot_id;
    
    EXECUTE format('
        SELECT jsonb_build_object(
            ''total_messages'', (SELECT COUNT(*) FROM %I.messages),
            ''total_sessions'', (SELECT COUNT(*) FROM %I.sessions),
            ''total_memories'', (SELECT COUNT(*) FROM %I.memories),
            ''last_message'', (SELECT MAX(created_at) FROM %I.messages),
            ''messages_today'', (SELECT COUNT(*) FROM %I.messages WHERE created_at > CURRENT_DATE)
        )
    ', v_schema, v_schema, v_schema, v_schema, v_schema) INTO v_result;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Limpar mensagens antigas (manutenção)
CREATE OR REPLACE FUNCTION admin.cleanup_old_messages(p_schema TEXT, p_days INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    EXECUTE format(
        'DELETE FROM %I.messages WHERE created_at < NOW() - interval ''%s days''',
        p_schema, p_days
    );
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;
