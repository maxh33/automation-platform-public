# Odoo Business-Type Template Workflows

This directory contains N8N workflow templates organized by business type for the Odoo multi-tenant platform. Each business type has its own subdirectory with specialized automation workflows.

## Directory Structure

```
workflows/odoo-templates/
├── base-tenant-workflows/          # Core workflows for all business types
├── jewelry-tenant-workflows/       # Jewelry store specific workflows
├── retail-tenant-workflows/        # General retail workflows
├── manufacturing-tenant-workflows/ # Manufacturing business workflows
├── services-tenant-workflows/      # Service business workflows
└── template-deployment/            # Scripts for template deployment
```

## Business Type Templates

### Base Tenant Workflows (All Business Types)
- **basic-inventory-alerts.json** - Low stock notifications
- **financial-reporting.json** - Basic financial reports
- **backup-automation.json** - Automated data backup
- **api-health-monitoring.json** - API endpoint monitoring

### Jewelry Tenant Workflows
- **gold-price-automation.json** - Real-time gold price updates
- **precious-metals-pricing.json** - Multi-metal pricing (gold, silver, platinum)
- **jewelry-inventory-alerts.json** - Jewelry-specific stock management
- **gemstone-tracking.json** - Gemstone inventory and certification tracking
- **craftsmanship-quality.json** - Quality control and craftsmanship tracking

### Retail Tenant Workflows
- **inventory-reorder-automation.json** - Automated reorder point management
- **multi-channel-sync.json** - Multi-platform inventory synchronization
- **sales-analytics-reporting.json** - Sales performance analytics
- **promotional-pricing.json** - Promotional campaign automation
- **customer-segmentation.json** - Customer behavior analysis

### Manufacturing Tenant Workflows
- **bom-cost-tracking.json** - Bill of Materials cost monitoring
- **production-scheduling.json** - Production workflow automation
- **supply-chain-alerts.json** - Supplier and material alerts
- **quality-control-automation.json** - Quality assurance workflows
- **capacity-planning.json** - Production capacity optimization

### Services Tenant Workflows
- **project-milestone-tracking.json** - Project progress monitoring
- **time-billing-automation.json** - Automated time tracking and billing
- **client-reporting.json** - Client-specific performance reports
- **resource-allocation.json** - Staff and resource management
- **contract-management.json** - Service contract automation

## Template Deployment Process

### Automatic Deployment
Templates are automatically deployed when a new tenant is onboarded based on their business type:

1. **Tenant Creation** - Via `odoo-tenant-onboarding.json` workflow
2. **Business Type Detection** - Determines which template set to deploy
3. **Template Selection** - Selects workflows from appropriate business type directory
4. **Customization** - Applies tenant-specific configurations
5. **Deployment** - Activates workflows with tenant-specific webhooks

### Manual Template Deployment
```bash
# Deploy specific template for existing tenant
curl -X POST https://automation.your-domain.com/api/v1/workflows/deploy-template \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "jewelry-store-1",
    "template_name": "gold-price-automation",
    "business_type": "jewelry"
  }'
```

### Template Customization
Each template includes configurable parameters:

- **Tenant-specific endpoints** - Custom webhook URLs
- **Business rules** - Industry-specific logic
- **Integration credentials** - Platform-specific API keys
- **Notification settings** - Alert preferences
- **Schedule configurations** - Timing and frequency

## Template Development Guidelines

### Naming Conventions
- Templates: `{functionality}-{business-context}.json`
- Webhooks: `/{tenant-id}-{template-name}`
- Credentials: `n8n/tenants/{tenant-id}/{service}`

### Template Structure
Each template must include:
- **Business type validation** - Ensure appropriate business context
- **Tenant isolation** - Proper tenant_id validation
- **Error handling** - Graceful failure modes
- **Logging** - Audit trail for all operations
- **Configuration flexibility** - Parameterized business rules

### Required Template Metadata
```json
{
  "template_info": {
    "name": "Template Name",
    "business_types": ["jewelry", "retail"],
    "version": "1.0.0",
    "description": "Template description",
    "required_credentials": ["api_key", "webhook_url"],
    "schedule_type": "cron|webhook|both",
    "dependencies": []
  }
}
```

## Integration Points

### Odoo API Integration
- **Product Management** - Product creation, updates, sync
- **Inventory Control** - Stock levels, reorder points
- **Pricing Management** - Dynamic pricing, markup rules
- **Financial Data** - Sales, costs, profitability

### E-commerce Platform Integration
- **WooCommerce** - Product sync, order management
- **Shopify** - Inventory updates, price synchronization
- **Multi-platform** - Unified product catalog management

### External APIs
- **Market Data** - Gold prices, exchange rates
- **Business Intelligence** - Analytics and reporting
- **Communication** - Email, SMS, messaging platforms
- **File Storage** - Document and media management

## Monitoring and Analytics

### Template Performance Tracking
- **Execution Success Rate** - Workflow completion statistics
- **Response Time Monitoring** - Performance optimization
- **Error Rate Analysis** - Failure pattern identification
- **Resource Usage** - CPU, memory, API call tracking

### Business Metrics
- **Automation ROI** - Cost savings and efficiency gains
- **Process Optimization** - Workflow improvement opportunities
- **Client Satisfaction** - Template effectiveness measurement
- **Platform Growth** - Usage and adoption metrics

## Security and Compliance

### Tenant Isolation
- **Data Separation** - Complete tenant data isolation
- **Credential Security** - AWS Secrets Manager integration
- **Access Control** - Role-based permissions
- **Audit Logging** - Complete activity tracking

### Business Compliance
- **Industry Standards** - Jewelry, retail, manufacturing compliance
- **Data Protection** - GDPR, CCPA compliance
- **Financial Regulations** - Accounting and reporting standards
- **Quality Assurance** - ISO and industry certifications

## Troubleshooting

### Common Issues
- **Template Deployment Failures** - Check tenant configuration
- **Webhook Authentication** - Verify tenant credentials
- **API Rate Limiting** - Monitor external API usage
- **Business Rule Conflicts** - Validate template logic

### Debug Tools
- **Workflow Execution Logs** - N8N execution history
- **Database Query Tools** - Direct database inspection
- **API Testing** - Integration endpoint validation
- **Performance Monitoring** - Resource usage analysis