# Multi-Tenant Architecture Guide

## Overview

The N8N Automation Platform implements a multi-tenant architecture that allows multiple clients to securely share the same N8N instance while maintaining complete data isolation and customization capabilities.

This document details the technical architecture and should be read alongside:
- [INFRASTRUCTURE-OPERATIONS-GUIDE.md](INFRASTRUCTURE-OPERATIONS-GUIDE.md) - Operational procedures and script usage
- [VPS-INFRASTRUCTURE-COMPATIBILITY.md](VPS-INFRASTRUCTURE-COMPATIBILITY.md) - VPS deployment considerations
- [FILE-STRUCTURE-GUIDE.md](FILE-STRUCTURE-GUIDE.md) - Project organization and file structure
- [CLIENT-ONBOARDING.md](CLIENT-ONBOARDING.md) - Client setup procedures

## Architecture Principles

### Tenant Isolation Strategy
- **Data Isolation**: Logical separation at the database level using tenant identifiers
- **Credential Isolation**: AWS Secrets Manager for external API credentials
- **Workflow Isolation**: Tenant-specific workflow namespacing and validation
- **Execution Isolation**: Separate execution contexts and logging per tenant

### Security Model
- **Principle of Least Privilege**: Each tenant only accesses their own resources
- **Defense in Depth**: Multiple layers of validation and access control
- **Audit Trail**: Complete logging of all tenant operations
- **Encrypted Storage**: All sensitive data encrypted at rest and in transit

## Technical Implementation

### 1. Database Schema Design

#### Tenant Configuration Table
```sql
CREATE TABLE tenant_config (
    tenant_id VARCHAR(255) PRIMARY KEY,
    tenant_name VARCHAR(255) NOT NULL,
    config JSONB NOT NULL DEFAULT '{}',
    limits JSONB NOT NULL DEFAULT '{"workflows": 10, "executions": 1000}',
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Audit Logging Table
```sql
CREATE TABLE tenant_audit_log (
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
```

### 2. Workflow-Level Isolation

#### Tenant Validation Node Pattern
Every client workflow includes a validation node that checks the tenant ID:

```json
{
  "parameters": {
    "conditions": {
      "conditions": [
        {
          "leftValue": "={{ $json.tenant_id }}",
          "rightValue": "{{ $env.CLIENT_TENANT_ID || 'default' }}",
          "operator": {
            "type": "string",
            "operation": "equals"
          }
        }
      ]
    }
  },
  "name": "Validate Tenant",
  "type": "n8n-nodes-base.if"
}
```

#### Webhook Isolation
- **Unique Endpoints**: Each tenant gets unique webhook URLs
- **Format**: `https://automation.your-domain.com/webhook/{tenant_id}-{workflow_type}`
- **Validation**: Incoming requests validated against tenant configuration

### 3. Credential Management

#### AWS Secrets Manager Structure
```
n8n/
├── clients/
│   ├── tenant1/
│   │   ├── instagram      # Instagram API credentials
│   │   ├── linkedin       # LinkedIn API credentials
│   │   └── twitter        # Twitter API credentials
│   ├── tenant2/
│   │   ├── instagram
│   │   └── linkedin
│   └── ...
└── system/
    ├── database           # Database credentials
    ├── smtp              # Email service credentials
    └── monitoring        # Monitoring service credentials
```

#### Dynamic Credential Loading
```javascript
// N8N External Hook Implementation
const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager();

async function loadTenantCredentials(tenantId, service) {
    const secretName = `n8n/clients/${tenantId}/${service}`;
    try {
        const result = await secretsManager.getSecretValue({
            SecretId: secretName
        }).promise();
        return JSON.parse(result.SecretString);
    } catch (error) {
        throw new Error(`Failed to load credentials for ${tenantId}/${service}`);
    }
}
```

### 4. Resource Limits and Quotas

#### Tenant Limits Configuration
```json
{
  "workflows": 25,
  "executions": 5000,
  "storage_mb": 1000,
  "webhook_requests_per_minute": 100,
  "concurrent_executions": 5,
  "data_retention_days": 30
}
```

#### Quota Enforcement
```sql
-- Function to check tenant limits
CREATE OR REPLACE FUNCTION check_tenant_quota(
    tenant_id TEXT,
    resource_type TEXT,
    current_usage INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    tenant_limit INTEGER;
BEGIN
    SELECT (limits->resource_type)::INTEGER INTO tenant_limit
    FROM tenant_config
    WHERE tenant_config.tenant_id = check_tenant_quota.tenant_id
    AND status = 'active';

    RETURN current_usage < COALESCE(tenant_limit, 0);
END;
$$ LANGUAGE plpgsql;
```

## Deployment Architecture

### Container Structure
```yaml
services:
  n8n_automation:
    # Single N8N instance serving all tenants
    # Tenant isolation handled at application level

  postgres:
    # Shared PostgreSQL with logical tenant separation
    # Row-level security policies for data isolation

  redis_automation:
    # Shared Redis with tenant-prefixed keys
    # Used for session management and caching

  crawl4ai:
    # AI-powered web scraping service
    # Shared across tenants with request isolation
```

### Network Isolation
```yaml
networks:
  automation_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

## Data Flow and Request Lifecycle

### 1. Incoming Webhook Request
```
Client Request → Traefik → N8N → Tenant Validation → Workflow Execution
```

### 2. Tenant Validation Process
1. **URL Parsing**: Extract tenant ID from webhook URL
2. **Database Lookup**: Verify tenant exists and is active
3. **Quota Check**: Validate current usage against limits
4. **Credential Loading**: Fetch tenant-specific API credentials
5. **Workflow Execution**: Execute with tenant context

### 3. Data Storage Pattern
```sql
-- All tenant data includes tenant_id for isolation
INSERT INTO social_posts (
    tenant_id,
    platform,
    post_id,
    content,
    status,
    published_at
) VALUES (
    $tenant_id,
    $platform,
    $post_id,
    $content,
    'published',
    NOW()
);
```

## Monitoring and Observability

### Per-Tenant Metrics
```sql
-- Tenant usage statistics view
CREATE VIEW tenant_usage_stats AS
SELECT
    tc.tenant_id,
    tc.tenant_name,
    COUNT(DISTINCT w.id) as active_workflows,
    COUNT(e.id) as total_executions,
    COUNT(CASE WHEN e."finishedAt" IS NOT NULL THEN 1 END) as successful_executions,
    AVG(EXTRACT(EPOCH FROM (e."finishedAt" - e."startedAt"))) as avg_execution_time,
    MAX(e."startedAt") as last_execution,
    SUM(LENGTH(e.data::TEXT)) / 1024 / 1024 as storage_mb_used
FROM tenant_config tc
LEFT JOIN workflow_entity w ON w.settings::TEXT LIKE '%' || tc.tenant_id || '%'
LEFT JOIN execution_entity e ON e."workflowId" = w.id
WHERE tc.status = 'active'
GROUP BY tc.tenant_id, tc.tenant_name;
```

### Prometheus Metrics
```yaml
# Tenant-specific metrics for monitoring
n8n_tenant_workflows_total{tenant_id="client1"} 15
n8n_tenant_executions_total{tenant_id="client1"} 1250
n8n_tenant_execution_duration_seconds{tenant_id="client1"} 2.5
n8n_tenant_quota_usage_ratio{tenant_id="client1",resource="workflows"} 0.6
```

### Alerting Rules
```yaml
groups:
  - name: tenant_alerts
    rules:
      - alert: TenantQuotaExceeded
        expr: n8n_tenant_quota_usage_ratio > 0.9
        for: 5m
        annotations:
          summary: "Tenant {{ $labels.tenant_id }} approaching quota limit"

      - alert: TenantExecutionFailures
        expr: rate(n8n_tenant_execution_failures_total[5m]) > 0.1
        for: 2m
        annotations:
          summary: "High failure rate for tenant {{ $labels.tenant_id }}"
```

## Security Considerations

### Access Control
- **Authentication**: N8N built-in user management system
- **Authorization**: Role-based access control per tenant
- **API Security**: Webhook validation and rate limiting
- **Data Encryption**: TLS in transit, encrypted storage at rest

### Tenant Isolation Validation
```bash
# Security audit script
./scripts/validate-tenant-isolation.sh
```

```sql
-- Verify no cross-tenant data access
SELECT DISTINCT tenant_id, COUNT(*)
FROM social_posts
GROUP BY tenant_id
HAVING COUNT(*) > 0;

-- Check for workflows without tenant isolation
SELECT id, name
FROM workflow_entity
WHERE settings::TEXT NOT LIKE '%tenant_id%';
```

### Data Privacy Compliance
- **GDPR Compliance**: Right to deletion and data portability
- **Data Residency**: All data stored in specified geographic regions
- **Audit Trail**: Complete logging for compliance reporting
- **Encryption**: End-to-end encryption for sensitive data

## Scaling Considerations

### Horizontal Scaling Strategy
1. **Database Sharding**: Partition tenants across multiple databases
2. **Service Mesh**: Implement per-tenant service instances
3. **Geographic Distribution**: Deploy regional instances for global clients
4. **Caching Strategy**: Tenant-aware caching with Redis

### Vertical Scaling Limits
- **Single Instance Limit**: ~100 active tenants
- **Database Connections**: Limited by PostgreSQL connection pool
- **Memory Usage**: Scales with concurrent workflow executions
- **Storage Growth**: Linear growth with tenant data retention

### Migration Path to Dedicated Instances
```bash
# Enterprise client migration to dedicated instance using organized scripts
./scripts/tenants/migrate-tenant.sh --tenant="ENTERPRISE_TENANT_ID" --target="dedicated-instance"

# Alternative: Legacy script
./scripts/migrate-tenant-to-dedicated.sh ENTERPRISE_TENANT_ID
```

## Backup and Recovery

### Tenant-Specific Backups
```bash
# Backup specific tenant data using organized scripts
./scripts/backup/backup-platform.sh --tenant="TENANT_ID"

# Backup only workflows for specific tenant
./scripts/backup/backup-workflows.sh --tenant="TENANT_ID"

# Restore tenant data
./scripts/backup/restore-platform.sh --backup-id="backup-date" --tenant="TENANT_ID"

# Legacy scripts (still supported)
./scripts/backup-automation.sh --client TENANT_ID
./scripts/restore-tenant-data.sh TENANT_ID backup-date
```

### Cross-Tenant Consistency
- **Atomic Operations**: All tenant operations are transactional
- **Consistency Checks**: Regular validation of tenant data integrity
- **Recovery Procedures**: Tenant-aware disaster recovery processes

## Cost Optimization

### Resource Allocation
- **Shared Infrastructure**: Cost-effective resource utilization
- **Usage-Based Pricing**: Fair pricing based on actual resource consumption
- **Automated Scaling**: Dynamic resource allocation based on demand

### Tenant Cost Tracking
```sql
-- Calculate per-tenant infrastructure costs
SELECT
    tenant_id,
    (executions_count * 0.001) + (storage_mb * 0.01) as monthly_cost
FROM tenant_usage_stats;
```

## Future Enhancements

### Planned Improvements
1. **Container-Level Isolation**: Dedicated containers per enterprise client
2. **Advanced Workflow Isolation**: Separate N8N instances for sensitive workloads
3. **Real-Time Analytics**: Live tenant usage dashboards
4. **Auto-Scaling**: Automatic resource allocation based on tenant growth
5. **Advanced Security**: Zero-trust networking and enhanced encryption

### Migration Roadmap
- **Phase 1**: Current logical isolation (implemented)
- **Phase 2**: Enhanced monitoring and alerting (Q4 2025)
- **Phase 3**: Container-level isolation for enterprise (Q1 2025)
- **Phase 4**: Geographic distribution (Q2 2025)

---

## Related Documentation

For comprehensive platform operations and management:
- [INFRASTRUCTURE-OPERATIONS-GUIDE.md](INFRASTRUCTURE-OPERATIONS-GUIDE.md) - Detailed script usage for tenant management, monitoring, and maintenance
- [VPS-INFRASTRUCTURE-COMPATIBILITY.md](VPS-INFRASTRUCTURE-COMPATIBILITY.md) - VPS deployment considerations and file dependencies
- [CLIENT-ONBOARDING.md](CLIENT-ONBOARDING.md) - Step-by-step client setup procedures
- [FILE-STRUCTURE-GUIDE.md](FILE-STRUCTURE-GUIDE.md) - Understanding the organized project structure

---

**Document Version**: 1.1
**Last Updated**: September 2025 (Updated with infrastructure documentation references)
**Review Schedule**: Quarterly
**Owner**: Platform Engineering Team