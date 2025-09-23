-- N8N Multi-Tenant Automation Platform Database Initialization
-- This script sets up the database for multi-tenant N8N deployment

-- Create extensions if they don't exist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Set timezone to UTC for consistency
SET timezone = 'UTC';

-- Grant permissions to n8n user
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO n8n;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO n8n;

-- Create custom functions for multi-tenant operations
CREATE OR REPLACE FUNCTION get_tenant_workflows(tenant_id TEXT)
RETURNS TABLE(workflow_id TEXT, workflow_name TEXT, active BOOLEAN, created_at TIMESTAMP) AS $$
BEGIN
    -- This function can be used to filter workflows by tenant
    -- Implementation depends on how tenant isolation is handled in workflows
    RETURN QUERY
    SELECT
        w.id::TEXT as workflow_id,
        w.name as workflow_name,
        w.active,
        w."createdAt" as created_at
    FROM workflow_entity w
    WHERE w.settings::TEXT LIKE '%' || tenant_id || '%'
    ORDER BY w."createdAt" DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to clean old executions per tenant
CREATE OR REPLACE FUNCTION cleanup_tenant_executions(tenant_id TEXT, days_to_keep INTEGER DEFAULT 7)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Clean up old executions for a specific tenant
    DELETE FROM execution_entity
    WHERE "startedAt" < NOW() - INTERVAL '1 day' * days_to_keep
    AND "workflowData"::TEXT LIKE '%' || tenant_id || '%';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create audit logging table for multi-tenant operations
CREATE TABLE IF NOT EXISTS tenant_audit_log (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(255) NOT NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id VARCHAR(255),
    user_id VARCHAR(255),
    details JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET
);

-- Create index for audit log queries
CREATE INDEX IF NOT EXISTS idx_tenant_audit_log_tenant_id ON tenant_audit_log(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_audit_log_created_at ON tenant_audit_log(created_at);

-- Create tenant configuration table
CREATE TABLE IF NOT EXISTS tenant_config (
    tenant_id VARCHAR(255) PRIMARY KEY,
    tenant_name VARCHAR(255) NOT NULL,
    config JSONB NOT NULL DEFAULT '{}',
    limits JSONB NOT NULL DEFAULT '{"workflows": 10, "executions": 1000}',
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create trigger to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tenant_config_updated_at BEFORE UPDATE ON tenant_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default tenant configurations
INSERT INTO tenant_config (tenant_id, tenant_name, config, limits) VALUES
('default', 'Default Tenant', '{"webhook_prefix": "default"}', '{"workflows": 10, "executions": 1000}'),
('demo', 'Demo Client', '{"webhook_prefix": "demo"}', '{"workflows": 5, "executions": 100}'),
('example', 'Example Corporation', '{"webhook_prefix": "example"}', '{"workflows": 25, "executions": 5000}')
ON CONFLICT (tenant_id) DO NOTHING;

-- Create view for workflow statistics per tenant
CREATE OR REPLACE VIEW tenant_workflow_stats AS
SELECT
    tc.tenant_id,
    tc.tenant_name,
    COUNT(DISTINCT w.id) as total_workflows,
    COUNT(DISTINCT CASE WHEN w.active THEN w.id END) as active_workflows,
    COUNT(DISTINCT e.id) as total_executions,
    COUNT(DISTINCT CASE WHEN e."finishedAt" IS NOT NULL AND e."stoppedAt" IS NULL THEN e.id END) as successful_executions,
    MAX(e."startedAt") as last_execution
FROM tenant_config tc
LEFT JOIN workflow_entity w ON w.settings::TEXT LIKE '%' || tc.tenant_id || '%'
LEFT JOIN execution_entity e ON e."workflowId" = w.id
GROUP BY tc.tenant_id, tc.tenant_name;

-- Set up monitoring for database performance
CREATE OR REPLACE VIEW n8n_db_stats AS
SELECT
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;

-- Log initialization completion
INSERT INTO tenant_audit_log (tenant_id, action, resource_type, details)
VALUES ('system', 'database_initialized', 'database', '{"version": "1.0", "timestamp": "' || CURRENT_TIMESTAMP || '"}');

-- Optimization settings for N8N workload
-- Note: These settings require database restart to take effect
-- ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
-- ALTER SYSTEM SET log_statement = 'mod';
-- ALTER SYSTEM SET log_min_duration_statement = 1000;