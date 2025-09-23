# Client Onboarding Guide - N8N Automation Platform

## Overview

This guide outlines the process for onboarding new clients to the N8N Automation Platform, ensuring proper tenant isolation, security, and service delivery.

## Prerequisites

Before onboarding a new client:
- [ ] Platform is deployed and operational
- [ ] AWS Secrets Manager access configured
- [ ] Client contract and requirements documented
- [ ] Unique tenant ID assigned

### Infrastructure Prerequisites
- [ ] Review VPS infrastructure status in [VPS-INFRASTRUCTURE-COMPATIBILITY.md](VPS-INFRASTRUCTURE-COMPATIBILITY.md)
- [ ] Verify platform health using [INFRASTRUCTURE-OPERATIONS-GUIDE.md](INFRASTRUCTURE-OPERATIONS-GUIDE.md)
- [ ] Ensure backup systems are operational
- [ ] Confirm monitoring stack integration

## Client Setup Process

### 1. Tenant Configuration

#### Generate Unique Tenant ID
```bash
# Use client company name + random suffix
TENANT_ID="clientname-$(openssl rand -hex 4)"
echo "New Tenant ID: $TENANT_ID"

# Alternative: Use organized script approach
./scripts/setup/onboard-tenant.sh --tenant-name="Client Company Name" --auto-generate-id
```

#### Add Tenant to Database
```sql
-- Connect to N8N database
docker exec -it postgres psql -U n8n -d n8n

-- Insert tenant configuration
INSERT INTO tenant_config (tenant_id, tenant_name, config, limits) VALUES
(
  '$TENANT_ID',
  'Client Company Name',
  '{"webhook_prefix": "$TENANT_ID", "branding": {"logo": "", "colors": {}}}',
  '{"workflows": 25, "executions": 5000, "storage_mb": 1000}'
);
```

### 2. AWS Secrets Manager Setup

#### Create Client Credential Namespace
```bash
# Option 1: Manual setup
aws secretsmanager create-secret \
  --name "n8n/clients/$TENANT_ID/instagram" \
  --description "Instagram API credentials for $TENANT_ID" \
  --secret-string '{
    "access_token": "CLIENT_PROVIDED_TOKEN",
    "account_id": "CLIENT_ACCOUNT_ID"
  }'

# Option 2: Use automated script (recommended)
./scripts/setup/sync-secrets.sh --tenant="$TENANT_ID" --create-templates

aws secretsmanager create-secret \
  --name "n8n/clients/$TENANT_ID/linkedin" \
  --description "LinkedIn API credentials for $TENANT_ID" \
  --secret-string '{
    "access_token": "CLIENT_PROVIDED_TOKEN",
    "person_id": "CLIENT_PERSON_ID"
  }'

aws secretsmanager create-secret \
  --name "n8n/clients/$TENANT_ID/twitter" \
  --description "Twitter API credentials for $TENANT_ID" \
  --secret-string '{
    "api_key": "CLIENT_API_KEY",
    "api_secret": "CLIENT_API_SECRET",
    "access_token": "CLIENT_ACCESS_TOKEN",
    "access_token_secret": "CLIENT_ACCESS_TOKEN_SECRET"
  }'
```

### 3. Workflow Template Deployment

#### Deploy Social Media Posting Template
```bash
# Copy and customize template
cp workflows/templates/social-media-posting.json workflows/clients/$TENANT_ID-social-media.json

# Update tenant references in workflow
sed -i "s/{{ \$env.CLIENT_TENANT_ID || 'default' }}/$TENANT_ID/g" \
  workflows/clients/$TENANT_ID-social-media.json

# Import workflow to N8N
docker exec n8n_automation n8n import:workflow \
  --input="/data/workflows/clients/$TENANT_ID-social-media.json"
```

#### Deploy Price Monitoring Template (if applicable)
```bash
# Copy and customize template
cp workflows/templates/ecommerce-price-monitoring.json workflows/clients/$TENANT_ID-price-monitoring.json

# Update tenant and client-specific settings
sed -i "s/default/$TENANT_ID/g" workflows/clients/$TENANT_ID-price-monitoring.json
sed -i "s/1\.15/$CLIENT_MARKUP_MULTIPLIER/g" workflows/clients/$TENANT_ID-price-monitoring.json

# Import workflow
docker exec n8n_automation n8n import:workflow \
  --input="/data/workflows/clients/$TENANT_ID-price-monitoring.json"
```

### 4. Client Environment Variables

#### Add to .env file
```bash
# Client-specific environment variables
echo "
# Client: $TENANT_ID
CLIENT_${TENANT_ID^^}_WEBHOOK_URL=https://automation.your-domain.com/webhook/$TENANT_ID
CLIENT_${TENANT_ID^^}_API_PREFIX=$TENANT_ID
" >> .env
```

### 5. Webhook Configuration

#### Set up Client Webhook Endpoints
```bash
# Verify webhook URL is accessible
curl -X POST "https://automation.your-domain.com/webhook/$TENANT_ID-content" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "$TENANT_ID",
    "test": true,
    "image_url": "https://example.com/test.jpg",
    "caption": "Test post from onboarding"
  }'
```

## Client Documentation Package

### 1. API Documentation

Create client-specific API documentation:

```markdown
# API Integration Guide for $TENANT_ID

## Webhook Endpoints

### Social Media Posting
- **URL**: `https://automation.your-domain.com/webhook/$TENANT_ID-content`
- **Method**: POST
- **Authentication**: Tenant ID validation

#### Request Format:
```json
{
  "tenant_id": "$TENANT_ID",
  "image_url": "https://your-domain.com/image.jpg",
  "caption": "Your post content with hashtags",
  "platforms": ["instagram", "linkedin", "twitter"],
  "alt_text": "Image description for accessibility"
}
```

#### Response Format:
```json
{
  "success": true,
  "message": "Content published successfully",
  "platforms": ["instagram", "linkedin", "twitter"],
  "timestamp": "2025-09-17T10:30:00Z",
  "tenant_id": "$TENANT_ID"
}
```

### Price Monitoring (if applicable)
- **URL**: `https://automation.your-domain.com/webhook/$TENANT_ID-price-update`
- **Method**: POST
- **Schedule**: Automatic daily updates at 9 AM UTC
```

### 2. Credential Setup Instructions

```markdown
# Credential Setup Instructions for $TENANT_ID

## Required API Credentials

### Instagram Business API
1. Create Facebook App at developers.facebook.com
2. Add Instagram Basic Display product
3. Generate access token with permissions:
   - `instagram_basic`
   - `instagram_content_publish`
4. Provide to our team:
   - Access Token
   - Instagram Account ID

### LinkedIn API
1. Create LinkedIn App at developer.linkedin.com
2. Request access to LinkedIn Marketing Developer Platform
3. Generate OAuth 2.0 credentials
4. Provide to our team:
   - Access Token
   - Person/Company ID

### Twitter API (X)
1. Apply for Twitter Developer account
2. Create app with Read/Write permissions
3. Generate API keys and tokens
4. Provide to our team:
   - API Key
   - API Secret
   - Access Token
   - Access Token Secret
```

## Testing and Validation

### 1. Functional Testing

```bash
# Use organized script structure for testing
./scripts/monitoring/health-check.sh --tenant="$TENANT_ID"

# Verify database isolation
docker exec postgres psql -U n8n -d n8n -c "
  SELECT COUNT(*) as workflow_count
  FROM workflow_entity
  WHERE settings::TEXT LIKE '%$TENANT_ID%';"

# Test backup isolation
./scripts/backup/backup-platform.sh --tenant="$TENANT_ID"
```

### 2. Security Validation

```bash
# Comprehensive tenant isolation verification
./scripts/monitoring/verify-tenant-isolation.sh --tenant="$TENANT_ID"

# Test credential access
aws secretsmanager get-secret-value \
  --secret-id "n8n/clients/$TENANT_ID/instagram" \
  --query SecretString --output text

# Full security audit
./scripts/monitoring/audit-tenants.sh --tenant="$TENANT_ID" --security-focus
```

## Client Limits and Monitoring

### Resource Limits
- **Workflows**: 25 per tenant
- **Monthly Executions**: 5,000
- **Storage**: 1GB per tenant
- **Webhook Rate Limit**: 100 requests/minute

### Monitoring Setup
```bash
# Add client to monitoring dashboard
echo "
# Client Monitoring: $TENANT_ID
CLIENT_${TENANT_ID^^}_WORKFLOWS_LIMIT=25
CLIENT_${TENANT_ID^^}_EXECUTIONS_LIMIT=5000
CLIENT_${TENANT_ID^^}_STORAGE_LIMIT_MB=1000
" >> monitoring/.env
```

## Billing and Usage Tracking

### Usage Metrics Collection
```sql
-- Create client usage view
CREATE VIEW client_${TENANT_ID}_usage AS
SELECT
    COUNT(DISTINCT w.id) as active_workflows,
    COUNT(e.id) as monthly_executions,
    SUM(LENGTH(e.data::TEXT)) / 1024 / 1024 as storage_mb_used,
    DATE_TRUNC('month', e."startedAt") as usage_month
FROM workflow_entity w
LEFT JOIN execution_entity e ON e."workflowId" = w.id
WHERE w.settings::TEXT LIKE '%$TENANT_ID%'
  AND e."startedAt" >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY DATE_TRUNC('month', e."startedAt");
```

### Monthly Reports
```bash
# Generate monthly usage report using organized scripts
./scripts/monitoring/audit-tenants.sh --tenant="$TENANT_ID" --report --period="month"

# Alternative: Legacy script
./scripts/generate-client-report.sh $TENANT_ID $(date +%Y-%m)
```

## Support and Maintenance

### Client Support Procedures
1. **Monitoring**: Automated alerts for failed executions
2. **Logging**: All client activities logged with tenant ID
3. **Backup**: Daily automated backups with client isolation
4. **Updates**: Managed updates with zero downtime
5. **Support**: 24/7 monitoring with 4-hour response SLA

### Escalation Process
1. **Level 1**: Automated recovery and notifications
2. **Level 2**: Manual intervention and client communication
3. **Level 3**: Platform engineer involvement for complex issues

## Offboarding Process

When a client needs to be removed:

```bash
# 1. Export client data using organized scripts
./scripts/backup/backup-platform.sh --tenant="$TENANT_ID" --tag="offboarding"

# 2. Use tenant management script for safe removal
./scripts/tenants/manage-tenant.sh suspend --name="$TENANT_ID" --reason="offboarding"

# 3. Disable workflows
docker exec n8n_automation n8n workflow:deactivate --all --filter="$TENANT_ID"

# 4. Remove credentials (after backup)
aws secretsmanager delete-secret --secret-id "n8n/clients/$TENANT_ID/instagram"
aws secretsmanager delete-secret --secret-id "n8n/clients/$TENANT_ID/linkedin"
aws secretsmanager delete-secret --secret-id "n8n/clients/$TENANT_ID/twitter"

# 5. Archive tenant data
docker exec postgres psql -U n8n -d n8n -c "
  UPDATE tenant_config
  SET status = 'archived', updated_at = CURRENT_TIMESTAMP
  WHERE tenant_id = '$TENANT_ID';"

# 6. Final cleanup (after retention period)
./scripts/tenants/manage-tenant.sh delete --name="$TENANT_ID" --confirm-delete
```

## Troubleshooting

### Common Issues

1. **Webhook Not Responding**
   ```bash
   # Check tenant validation
   docker logs n8n_automation | grep $TENANT_ID
   ```

2. **Credential Access Errors**
   ```bash
   # Verify AWS Secrets Manager access
   aws secretsmanager describe-secret --secret-id "n8n/clients/$TENANT_ID/instagram"
   ```

3. **Database Connection Issues**
   ```bash
   # Test database connectivity
   docker exec postgres pg_isready -U n8n
   ```

## Checklist for Client Onboarding

### Pre-Onboarding
- [ ] Client contract signed
- [ ] Technical requirements documented
- [ ] Tenant ID generated and reserved
- [ ] Service limits agreed upon
- [ ] Infrastructure health verified using [INFRASTRUCTURE-OPERATIONS-GUIDE.md](INFRASTRUCTURE-OPERATIONS-GUIDE.md)

### Technical Setup
- [ ] Tenant configuration added to database
- [ ] AWS Secrets Manager namespaces created
- [ ] Workflow templates customized and deployed
- [ ] Environment variables configured
- [ ] Webhook endpoints tested
- [ ] Tenant isolation verified using `./scripts/monitoring/verify-tenant-isolation.sh`

### Client Delivery
- [ ] API documentation provided
- [ ] Credential setup instructions sent
- [ ] Test account/sandbox access provided
- [ ] Initial workflow testing completed
- [ ] Monitoring and alerting configured
- [ ] Backup procedures tested

### Post-Onboarding
- [ ] Client training session conducted
- [ ] Production workflows deployed
- [ ] First month monitoring review scheduled
- [ ] Success metrics baseline established
- [ ] Monthly audit scheduled using `./scripts/monitoring/audit-tenants.sh`

**Average Onboarding Time**: 2-4 hours
**Client Go-Live**: Same day (after credential setup)
**First Month Review**: Scheduled automatically

### Additional Resources
For comprehensive operational guidance, refer to:
- [INFRASTRUCTURE-OPERATIONS-GUIDE.md](INFRASTRUCTURE-OPERATIONS-GUIDE.md) - Detailed script usage and procedures
- [VPS-INFRASTRUCTURE-COMPATIBILITY.md](VPS-INFRASTRUCTURE-COMPATIBILITY.md) - VPS deployment considerations
- [FILE-STRUCTURE-GUIDE.md](FILE-STRUCTURE-GUIDE.md) - Understanding the organized project structure
- [MULTI-TENANT-ARCHITECTURE.md](MULTI-TENANT-ARCHITECTURE.md) - Technical architecture details