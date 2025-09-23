-- Odoo Multi-Tenant Integration Database Schema Extensions
-- This file extends the existing N8N database with Odoo-specific tables
-- Run this after the base N8N database setup

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table for managing Odoo tenant configurations
CREATE TABLE IF NOT EXISTS odoo_tenant_configs (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(255) UNIQUE NOT NULL,
    tenant_name VARCHAR(255) NOT NULL,
    business_type VARCHAR(50) NOT NULL CHECK (business_type IN ('jewelry', 'retail', 'manufacturing', 'services', 'base')),
    database_name VARCHAR(255) NOT NULL,
    subdomain VARCHAR(255) NOT NULL,
    api_endpoint TEXT NOT NULL,
    config JSONB DEFAULT '{}',
    status VARCHAR(20) DEFAULT 'provisioning' CHECK (status IN ('provisioning', 'active', 'suspended', 'archived')),
    created_at TIMESTAMP DEFAULT NOW(),
    activated_at TIMESTAMP,
    suspended_at TIMESTAMP,
    archived_at TIMESTAMP,
    last_activity TIMESTAMP DEFAULT NOW(),

    -- Indexes for performance
    CONSTRAINT unique_database_name UNIQUE (database_name),
    CONSTRAINT unique_subdomain UNIQUE (subdomain)
);

-- Create indexes for odoo_tenant_configs
CREATE INDEX IF NOT EXISTS idx_odoo_tenant_configs_tenant_id ON odoo_tenant_configs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_odoo_tenant_configs_business_type ON odoo_tenant_configs(business_type);
CREATE INDEX IF NOT EXISTS idx_odoo_tenant_configs_status ON odoo_tenant_configs(status);
CREATE INDEX IF NOT EXISTS idx_odoo_tenant_configs_created_at ON odoo_tenant_configs(created_at);

-- Table for logging product synchronization between Odoo and e-commerce platforms
CREATE TABLE IF NOT EXISTS product_sync_log (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(255) NOT NULL REFERENCES odoo_tenant_configs(tenant_id) ON DELETE CASCADE,
    odoo_product_id INTEGER,
    platform VARCHAR(50) NOT NULL, -- 'woocommerce', 'shopify', etc.
    platform_product_id VARCHAR(255),
    sync_action VARCHAR(20) NOT NULL CHECK (sync_action IN ('create', 'update', 'delete')),
    sync_status VARCHAR(20) NOT NULL CHECK (sync_status IN ('success', 'failed', 'pending')),
    sync_data JSONB,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    -- Unique constraint to prevent duplicate syncs
    CONSTRAINT unique_tenant_product_platform UNIQUE (tenant_id, odoo_product_id, platform)
);

-- Create indexes for product_sync_log
CREATE INDEX IF NOT EXISTS idx_product_sync_log_tenant_id ON product_sync_log(tenant_id);
CREATE INDEX IF NOT EXISTS idx_product_sync_log_platform ON product_sync_log(platform);
CREATE INDEX IF NOT EXISTS idx_product_sync_log_status ON product_sync_log(sync_status);
CREATE INDEX IF NOT EXISTS idx_product_sync_log_created_at ON product_sync_log(created_at);

-- Table for tracking price updates across all platforms
CREATE TABLE IF NOT EXISTS price_update_log (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(255) NOT NULL REFERENCES odoo_tenant_configs(tenant_id) ON DELETE CASCADE,
    platform VARCHAR(50) NOT NULL, -- 'odoo', 'woocommerce', 'shopify', etc.
    product_sku VARCHAR(255),
    product_name VARCHAR(255),
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    price_change DECIMAL(10,2) GENERATED ALWAYS AS (new_price - old_price) STORED,
    price_change_percent DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE
            WHEN old_price > 0 THEN ((new_price - old_price) / old_price) * 100
            ELSE 0
        END
    ) STORED,
    currency VARCHAR(10) DEFAULT 'BRL',
    update_source VARCHAR(50), -- 'automated_price_monitoring', 'manual_update', 'market_sync'
    market_data JSONB, -- Store gold prices, exchange rates, etc.
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for price_update_log
CREATE INDEX IF NOT EXISTS idx_price_update_log_tenant_id ON price_update_log(tenant_id);
CREATE INDEX IF NOT EXISTS idx_price_update_log_platform ON price_update_log(platform);
CREATE INDEX IF NOT EXISTS idx_price_update_log_sku ON price_update_log(product_sku);
CREATE INDEX IF NOT EXISTS idx_price_update_log_created_at ON price_update_log(created_at);

-- Table for storing Odoo workflow deployment status
CREATE TABLE IF NOT EXISTS odoo_workflow_deployments (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(255) NOT NULL REFERENCES odoo_tenant_configs(tenant_id) ON DELETE CASCADE,
    workflow_template VARCHAR(255) NOT NULL,
    workflow_name VARCHAR(255) NOT NULL,
    n8n_workflow_id VARCHAR(255),
    webhook_url TEXT,
    deployment_status VARCHAR(20) DEFAULT 'pending' CHECK (deployment_status IN ('pending', 'deployed', 'failed', 'disabled')),
    deployment_config JSONB DEFAULT '{}',
    last_execution TIMESTAMP,
    execution_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    -- Unique constraint for tenant + template combination
    CONSTRAINT unique_tenant_workflow_template UNIQUE (tenant_id, workflow_template)
);

-- Create indexes for odoo_workflow_deployments
CREATE INDEX IF NOT EXISTS idx_odoo_workflow_deployments_tenant_id ON odoo_workflow_deployments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_odoo_workflow_deployments_template ON odoo_workflow_deployments(workflow_template);
CREATE INDEX IF NOT EXISTS idx_odoo_workflow_deployments_status ON odoo_workflow_deployments(deployment_status);

-- Table for storing business-type specific pricing rules and configurations
CREATE TABLE IF NOT EXISTS tenant_pricing_rules (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(255) NOT NULL REFERENCES odoo_tenant_configs(tenant_id) ON DELETE CASCADE,
    business_type VARCHAR(50) NOT NULL,
    pricing_config JSONB NOT NULL DEFAULT '{}',
    market_sources JSONB DEFAULT '{}', -- Gold API, exchange rate sources, etc.
    markup_rules JSONB DEFAULT '{}',
    threshold_rules JSONB DEFAULT '{}', -- When to trigger price updates
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    -- Ensure one active pricing rule per tenant
    CONSTRAINT unique_active_tenant_pricing UNIQUE (tenant_id, active) DEFERRABLE INITIALLY DEFERRED
);

-- Create indexes for tenant_pricing_rules
CREATE INDEX IF NOT EXISTS idx_tenant_pricing_rules_tenant_id ON tenant_pricing_rules(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_pricing_rules_business_type ON tenant_pricing_rules(business_type);
CREATE INDEX IF NOT EXISTS idx_tenant_pricing_rules_active ON tenant_pricing_rules(active);

-- Table for Odoo API integration logs and performance monitoring
CREATE TABLE IF NOT EXISTS odoo_api_logs (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(255) NOT NULL REFERENCES odoo_tenant_configs(tenant_id) ON DELETE CASCADE,
    api_endpoint TEXT NOT NULL,
    http_method VARCHAR(10) NOT NULL,
    request_data JSONB,
    response_status INTEGER,
    response_data JSONB,
    response_time_ms INTEGER,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for odoo_api_logs
CREATE INDEX IF NOT EXISTS idx_odoo_api_logs_tenant_id ON odoo_api_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_odoo_api_logs_endpoint ON odoo_api_logs(api_endpoint);
CREATE INDEX IF NOT EXISTS idx_odoo_api_logs_status ON odoo_api_logs(response_status);
CREATE INDEX IF NOT EXISTS idx_odoo_api_logs_created_at ON odoo_api_logs(created_at);

-- Table for tracking tenant usage and analytics
CREATE TABLE IF NOT EXISTS tenant_usage_analytics (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(255) NOT NULL REFERENCES odoo_tenant_configs(tenant_id) ON DELETE CASCADE,
    metric_date DATE NOT NULL DEFAULT CURRENT_DATE,
    products_synced INTEGER DEFAULT 0,
    price_updates INTEGER DEFAULT 0,
    api_calls INTEGER DEFAULT 0,
    workflow_executions INTEGER DEFAULT 0,
    data_volume_mb DECIMAL(10,2) DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),

    -- Unique constraint for one record per tenant per day
    CONSTRAINT unique_tenant_daily_analytics UNIQUE (tenant_id, metric_date)
);

-- Create indexes for tenant_usage_analytics
CREATE INDEX IF NOT EXISTS idx_tenant_usage_analytics_tenant_id ON tenant_usage_analytics(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_usage_analytics_date ON tenant_usage_analytics(metric_date);

-- Create a view for tenant overview with latest activity
CREATE OR REPLACE VIEW tenant_overview AS
SELECT
    otc.tenant_id,
    otc.tenant_name,
    otc.business_type,
    otc.status,
    otc.created_at,
    otc.last_activity,

    -- Count of deployed workflows
    COALESCE(wd.workflow_count, 0) as deployed_workflows,

    -- Latest price update
    pu.latest_price_update,

    -- Product sync stats
    COALESCE(ps.total_syncs, 0) as total_product_syncs,
    COALESCE(ps.successful_syncs, 0) as successful_product_syncs,

    -- Usage analytics for current month
    COALESCE(ua.monthly_api_calls, 0) as monthly_api_calls,
    COALESCE(ua.monthly_workflow_executions, 0) as monthly_workflow_executions

FROM odoo_tenant_configs otc
LEFT JOIN (
    SELECT tenant_id, COUNT(*) as workflow_count
    FROM odoo_workflow_deployments
    WHERE deployment_status = 'deployed'
    GROUP BY tenant_id
) wd ON otc.tenant_id = wd.tenant_id
LEFT JOIN (
    SELECT tenant_id, MAX(created_at) as latest_price_update
    FROM price_update_log
    GROUP BY tenant_id
) pu ON otc.tenant_id = pu.tenant_id
LEFT JOIN (
    SELECT tenant_id,
           COUNT(*) as total_syncs,
           COUNT(CASE WHEN sync_status = 'success' THEN 1 END) as successful_syncs
    FROM product_sync_log
    WHERE created_at >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY tenant_id
) ps ON otc.tenant_id = ps.tenant_id
LEFT JOIN (
    SELECT tenant_id,
           SUM(api_calls) as monthly_api_calls,
           SUM(workflow_executions) as monthly_workflow_executions
    FROM tenant_usage_analytics
    WHERE metric_date >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY tenant_id
) ua ON otc.tenant_id = ua.tenant_id;

-- Function to update tenant last activity
CREATE OR REPLACE FUNCTION update_tenant_activity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE odoo_tenant_configs
    SET last_activity = NOW()
    WHERE tenant_id = NEW.tenant_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to automatically update tenant activity
CREATE OR REPLACE TRIGGER trigger_update_tenant_activity_product_sync
    AFTER INSERT ON product_sync_log
    FOR EACH ROW
    EXECUTE FUNCTION update_tenant_activity();

CREATE OR REPLACE TRIGGER trigger_update_tenant_activity_price_update
    AFTER INSERT ON price_update_log
    FOR EACH ROW
    EXECUTE FUNCTION update_tenant_activity();

CREATE OR REPLACE TRIGGER trigger_update_tenant_activity_api_log
    AFTER INSERT ON odoo_api_logs
    FOR EACH ROW
    EXECUTE FUNCTION update_tenant_activity();

-- Function to clean up old logs (data retention)
CREATE OR REPLACE FUNCTION cleanup_old_logs()
RETURNS void AS $$
BEGIN
    -- Keep only last 90 days of API logs
    DELETE FROM odoo_api_logs
    WHERE created_at < NOW() - INTERVAL '90 days';

    -- Keep only last 180 days of product sync logs
    DELETE FROM product_sync_log
    WHERE created_at < NOW() - INTERVAL '180 days';

    -- Keep only last 365 days of price update logs
    DELETE FROM price_update_log
    WHERE created_at < NOW() - INTERVAL '365 days';

    -- Keep only last 730 days of usage analytics
    DELETE FROM tenant_usage_analytics
    WHERE metric_date < CURRENT_DATE - INTERVAL '730 days';
END;
$$ LANGUAGE plpgsql;

-- Sample data for testing (remove in production)
-- INSERT INTO odoo_tenant_configs (
--     tenant_id, tenant_name, business_type, database_name,
--     subdomain, api_endpoint, status
-- ) VALUES
-- (
--     'jewelry-store-demo',
--     'Demo Jewelry Store',
--     'jewelry',
--     'tenant_jewelry_demo',
--     'jewelry-demo.odoo.your-domain.com',
--     'https://api.odoo.your-domain.com/tenant/jewelry-store-demo',
--     'active'
-- ),
-- (
--     'retail-shop-demo',
--     'Demo Retail Shop',
--     'retail',
--     'tenant_retail_demo',
--     'retail-demo.odoo.your-domain.com',
--     'https://api.odoo.your-domain.com/tenant/retail-shop-demo',
--     'active'
-- );

-- Grant necessary permissions to N8N user
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO n8n;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO n8n;
GRANT SELECT ON tenant_overview TO n8n;

-- Comments for documentation
COMMENT ON TABLE odoo_tenant_configs IS 'Configuration and metadata for each Odoo tenant instance';
COMMENT ON TABLE product_sync_log IS 'Log of product synchronization between Odoo and e-commerce platforms';
COMMENT ON TABLE price_update_log IS 'Log of all price updates across platforms with change tracking';
COMMENT ON TABLE odoo_workflow_deployments IS 'Status and configuration of deployed N8N workflows for each tenant';
COMMENT ON TABLE tenant_pricing_rules IS 'Business-type specific pricing rules and market data sources';
COMMENT ON TABLE odoo_api_logs IS 'API interaction logs for performance monitoring and debugging';
COMMENT ON TABLE tenant_usage_analytics IS 'Daily usage metrics and analytics per tenant';
COMMENT ON VIEW tenant_overview IS 'Comprehensive overview of tenant status, activity, and performance metrics';

-- Create procedure for tenant onboarding
CREATE OR REPLACE FUNCTION create_tenant_with_defaults(
    p_tenant_id VARCHAR(255),
    p_tenant_name VARCHAR(255),
    p_business_type VARCHAR(50),
    p_admin_email VARCHAR(255)
)
RETURNS TABLE(tenant_id VARCHAR, status VARCHAR, message TEXT) AS $$
DECLARE
    v_database_name VARCHAR(255);
    v_subdomain VARCHAR(255);
    v_api_endpoint TEXT;
BEGIN
    -- Generate derived values
    v_database_name := 'tenant_' || p_business_type || '_' || p_tenant_id;
    v_subdomain := p_tenant_id || '.odoo.your-domain.com';
    v_api_endpoint := 'https://api.odoo.your-domain.com/tenant/' || p_tenant_id;

    -- Insert tenant configuration
    INSERT INTO odoo_tenant_configs (
        tenant_id, tenant_name, business_type, database_name,
        subdomain, api_endpoint, config, status
    ) VALUES (
        p_tenant_id, p_tenant_name, p_business_type, v_database_name,
        v_subdomain, v_api_endpoint,
        jsonb_build_object('admin_email', p_admin_email),
        'provisioning'
    );

    -- Insert default pricing rules based on business type
    INSERT INTO tenant_pricing_rules (tenant_id, business_type, pricing_config, active)
    VALUES (
        p_tenant_id,
        p_business_type,
        CASE p_business_type
            WHEN 'jewelry' THEN jsonb_build_object(
                'markup_rules', jsonb_build_object('18', 2.5, '14', 2.3, '10', 2.1),
                'labor_costs', jsonb_build_object('18', 25, '14', 20, '10', 15)
            )
            WHEN 'retail' THEN jsonb_build_object(
                'markup_rules', jsonb_build_object('electronics', 1.15, 'clothing', 1.25, 'default', 1.18)
            )
            ELSE jsonb_build_object('default_markup', 1.2)
        END,
        true
    );

    RETURN QUERY SELECT p_tenant_id, 'success'::VARCHAR, 'Tenant created successfully'::TEXT;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT p_tenant_id, 'error'::VARCHAR, SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql;