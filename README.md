# N8N Multi-Tenant Automation Platform

A production-ready, containerized N8N platform designed for building and deploying automation services at scale. This platform supports multi-tenant architecture, extensive workflow templates, and enterprise-grade features for automation service providers.

[![Docker](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://www.docker.com/)
[![N8N](https://img.shields.io/badge/N8N-Latest-orange.svg)](https://n8n.io/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue.svg)](https://www.postgresql.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🚀 Features

### Core Platform
- **Multi-Tenant Architecture**: Logical tenant isolation with per-client data separation
- **Containerized Deployment**: Docker Compose orchestration with health checks
- **Production Ready**: Resource limits, logging, monitoring, and backup systems
- **Auto-Recovery**: Built-in health monitoring with automatic service recovery
- **Scalable Storage**: PostgreSQL database with Redis for queue management

### AI-Powered Capabilities
- **Web Scraping**: Crawl4AI integration for intelligent content extraction
- **Content Generation**: Multi-provider AI support (Gemini, Cohere, Mistral)
- **Smart Automation**: AI-enhanced workflow templates for various industries

### Pre-Built Workflow Templates
- 🌐 **Social Media Automation**: Multi-platform posting and analytics
- 📱 **WhatsApp Business**: AI-powered customer support automation
- 🛒 **E-commerce Integration**: Price monitoring and product synchronization
- 📧 **Email Marketing**: Automated campaigns and analytics reports
- 🔍 **Web Scraping**: AI-powered data extraction at scale
- 💼 **ERP Integration**: Odoo multi-tenant business process automation

## 📋 Quick Start

### Prerequisites
- Docker Desktop 4.0+
- 8GB RAM minimum (16GB recommended for production)
- 20GB available disk space

### 1. Clone and Setup
```bash
git clone https://github.com/your-username/automation-platform.git
cd automation-platform
cp .env.example .env
```

### 2. Configure Environment
Edit `.env` file with your settings:
```bash
# Required: Generate secure keys
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 16)
REDIS_PASSWORD=$(openssl rand -base64 16)
SESSION_SECRET=$(openssl rand -base64 32)

# Basic configuration for local development
N8N_HOST=localhost
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:5678
```

### 3. Start the Platform
```bash
# Development environment
docker compose up -d

# Production environment
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 4. Access N8N
- **Web Interface**: http://localhost:5678
- **Health Check**: http://localhost:5678/healthz
- **Crawl4AI Service**: http://localhost:11235

## 🏗️ Architecture

### Service Components
- **N8N**: Workflow automation engine (port 5678)
- **PostgreSQL**: Primary database for workflows and executions
- **Redis**: Session management and queue processing
- **Crawl4AI**: AI-powered web scraping service (port 11235)

### Multi-Tenant Design
```
Webhook Request → Tenant Validation → N8N Workflow → External APIs
                                                   ↓
                                             AWS Secrets Manager
```

### Network Architecture
- **Internal Network**: Secure container communication
- **Health Monitoring**: Automated recovery and alerting
- **Data Isolation**: Tenant-specific data separation

## 📚 Workflow Templates

### Social Media Automation
Perfect for agencies managing multiple client accounts:
- **Content Generation**: AI-powered trending content creation
- **Multi-Platform Posting**: Instagram, Facebook, LinkedIn automation
- **Analytics Reporting**: Weekly performance reports via email
- **Hashtag Optimization**: Trending topic integration

### E-commerce Automation
Comprehensive e-commerce workflow collection:
- **Price Monitoring**: Intelligent competitor price tracking
- **Product Synchronization**: Multi-platform inventory management
- **Customer Support**: WhatsApp Business automation with AI
- **Order Processing**: Automated fulfillment workflows

### Business Process Automation
Enterprise-grade business workflows:
- **ERP Integration**: Odoo multi-tenant business automation
- **Email Campaigns**: Automated marketing sequences
- **Data Processing**: AI-enhanced web scraping and analysis
- **Reporting**: Automated business intelligence reports

## 🎯 Use Cases

### For Automation Agencies
- **Client Onboarding**: Rapid deployment of client-specific workflows
- **Service Scaling**: Multi-tenant platform supporting hundreds of clients
- **White-label Solutions**: Customizable branding and domain configuration
- **Revenue Optimization**: Usage tracking and billing integration

### For SaaS Providers
- **API Integration**: Connect disparate business systems
- **Workflow Marketplace**: Pre-built industry-specific templates
- **Customer Success**: Automated onboarding and support workflows
- **Data Synchronization**: Real-time business data management

### For Enterprise Teams
- **Internal Automation**: Streamline business processes
- **Integration Hub**: Connect existing business tools
- **Compliance Automation**: Audit trails and data governance
- **Cost Reduction**: Reduce manual operational overhead

## 🔧 Configuration

### Environment Variables
Key configuration options in `.env`:

```bash
# Core N8N Settings
N8N_ENCRYPTION_KEY=your-32-character-key
N8N_HOST=your-domain.com
WEBHOOK_URL=https://your-domain.com

# Database Configuration
POSTGRES_PASSWORD=secure-password
REDIS_PASSWORD=secure-password

# AI Provider Keys (Optional)
GEMINI_API_KEY=your-gemini-key
COHERE_API_KEY=your-cohere-key
MISTRAL_API_KEY=your-mistral-key

# AWS Integration (Optional)
AWS_ACCESS_KEY_ID=your-aws-key
AWS_SECRET_ACCESS_KEY=your-aws-secret
```

### Multi-Tenant Setup
Each tenant requires:
1. **Database Entry**: Tenant configuration in `tenant_config` table
2. **Webhook Endpoints**: Pattern: `/webhook/{tenant-id}-{service}`
3. **Credential Management**: Secure storage for API keys and tokens

### Production Deployment
For production environments:
- Use `docker-compose.prod.yml` overlay
- Configure SSL/TLS termination
- Set up monitoring and alerting
- Implement backup strategies
- Configure log aggregation

## 📊 Monitoring and Management

### Health Monitoring
Automated service monitoring with recovery:
```bash
# Start health monitor
./scripts/monitoring/n8n-health-monitor.sh start

# Check status
./scripts/monitoring/n8n-health-monitor.sh status

# Manual health check
./scripts/monitoring/n8n-health-monitor.sh check
```

### Backup Management
Comprehensive backup solution:
```bash
# Full platform backup
./scripts/backup/backup-platform.sh

# Tenant-specific backup
./scripts/backup/backup-platform.sh --tenant client-id

# Workflow-only backup
./scripts/backup/backup-platform.sh backup-workflows
```

### Performance Optimization
- **Resource Limits**: Container memory and CPU constraints
- **Database Tuning**: Optimized PostgreSQL configuration
- **Cache Management**: Redis-based session and data caching
- **Log Rotation**: Automated log management and cleanup

## 🔐 Security Features

### Data Protection
- **Tenant Isolation**: Logical separation of client data
- **Credential Security**: External credential storage support
- **Audit Logging**: Comprehensive activity tracking
- **Rate Limiting**: API and webhook protection

### Access Control
- **Authentication**: Basic auth and JWT token support
- **Authorization**: Role-based access control
- **Network Security**: Container network isolation
- **SSL/TLS**: Production-ready encryption

## 🚀 Getting Started with Templates

### Import Workflow Templates
1. Access N8N web interface at http://localhost:5678
2. Navigate to **Workflows** → **Import from File**
3. Select templates from `./workflows/templates/`
4. Configure tenant-specific settings and credentials

### Popular Templates to Try First
1. **Social Media Content Automation**: `social-media-content-automation.json`
2. **WhatsApp Business Automation**: `whatsapp-business-automation.json`
3. **AI Web Scraper**: `ai-web-scraper-automation.json`

### Webhook Configuration
Configure webhooks using the pattern:
```
http://localhost:5678/webhook/{tenant-id}-{service}
```

Example endpoints:
- Content posting: `/webhook/demo-content`
- Price monitoring: `/webhook/demo-price-update`
- AI scraping: `/webhook/ai-scraper`

## 📖 Documentation

### Core Documentation
- [Multi-Tenant Architecture](docs/MULTI-TENANT-ARCHITECTURE.md)
- [Client Onboarding Guide](docs/CLIENT-ONBOARDING.md)
- [File Structure Guide](docs/FILE-STRUCTURE-GUIDE.md)

### Operational Guides
- Health monitoring and auto-recovery setup
- Backup and disaster recovery procedures
- Performance tuning and optimization
- Security best practices and compliance

## 🤝 Contributing

We welcome contributions! Please read our contributing guidelines:

1. **Fork the Repository**: Create your feature branch
2. **Follow Conventions**: Maintain code style and documentation standards
3. **Test Thoroughly**: Ensure all workflows and scripts function correctly
4. **Submit Pull Requests**: Include detailed descriptions and test results

### Development Setup
```bash
# Clone repository
git clone https://github.com/your-username/automation-platform.git
cd automation-platform

# Set up development environment
cp .env.example .env
# Configure .env for development

# Start in development mode
docker compose up -d

# Access logs
docker compose logs -f n8n
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Community Support
- **GitHub Issues**: Bug reports and feature requests
- **Discussions**: Community Q&A and best practices
- **Wiki**: Extended documentation and tutorials

### Professional Support
For enterprise deployments and custom development:
- Custom workflow development
- Infrastructure consulting
- Training and onboarding services
- SLA-backed production support

## 🔗 Related Projects

- [N8N](https://n8n.io/) - The core workflow automation platform
- [Crawl4AI](https://github.com/unclecode/crawl4ai) - AI-powered web scraping
- [Traefik](https://traefik.io/) - Modern reverse proxy for production deployments

## 📈 Roadmap

### Upcoming Features
- **Kubernetes Support**: Helm charts for container orchestration
- **Advanced Analytics**: Business intelligence dashboards
- **Marketplace Integration**: Community workflow sharing
- **Enhanced AI**: More AI providers and capabilities
- **Mobile App**: Mobile dashboard for monitoring and management

### Version History
- **v1.0**: Initial release with core multi-tenant features
- **v1.1**: AI integration and enhanced workflow templates
- **v1.2**: Production hardening and monitoring improvements
- **v2.0**: Kubernetes support and advanced analytics (planned)

---

**Made with ❤️ for the automation community**

Start building powerful automation solutions today with our comprehensive, production-ready platform!