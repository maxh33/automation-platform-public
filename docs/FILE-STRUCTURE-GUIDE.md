# File Structure Guide - Automation Platform

This document explains the organized directory structure used in the automation-platform repository, the rationale behind this approach, and how it differs from and complements other project structures.

## Repository Organization Philosophy

### Organized vs. Flat Structure

The automation-platform uses an **organized directory structure** designed for:
- **Scalability**: Easy to add new scripts, configurations, and documentation
- **Maintainability**: Clear separation of concerns and logical grouping
- **Team Collaboration**: Intuitive file locations for team members
- **Development Efficiency**: Faster navigation and development workflows

This contrasts with the **flat structure** used in the my-portfolio repository, which prioritizes:
- **VPS Compatibility**: Absolute path reliability for production systems
- **Operational Simplicity**: Predictable file locations for automation
- **Production Stability**: Minimal chance of breaking references

## Directory Structure Overview

```
automation-platform/
├── .claude/                    # Claude Code configuration
├── .github/                    # GitHub Actions workflows
├── configs/                    # Configuration files and templates
│   ├── n8n/                   # N8N-specific configurations
│   ├── tenants/               # Per-tenant configuration files
│   └── templates/             # Configuration templates
├── docs/                      # Comprehensive documentation
│   ├── CLIENT-ONBOARDING.md
│   ├── MULTI-TENANT-ARCHITECTURE.md
│   ├── INFRASTRUCTURE-OPERATIONS-GUIDE.md
│   └── VPS-INFRASTRUCTURE-COMPATIBILITY.md
├── scripts/                   # All operational scripts
│   ├── backup/                # Backup and recovery operations
│   ├── deployment/            # Deployment automation
│   ├── maintenance/           # Platform maintenance
│   ├── monitoring/            # Health checks and auditing
│   ├── setup/                 # Initial setup and configuration
│   └── tenants/               # Multi-tenant management
├── workflows/                 # N8N workflow templates and exports
│   ├── templates/             # Reusable workflow templates
│   └── exports/               # Client workflow exports
├── docker-compose.yml         # Main container orchestration
├── docker-compose.prod.yml    # Production overrides
├── .env.example               # Environment template
├── CLAUDE.md                  # Claude Code guidance
├── DISASTER-RECOVERY.md       # Recovery procedures
└── README.md                  # Project overview
```

## Detailed Directory Breakdown

### 📁 scripts/ - Operational Scripts

**Purpose**: Centralized location for all platform management scripts
**Organization**: Grouped by functional area for easy navigation

#### scripts/setup/
- **initial-setup.sh**: Platform initialization and first-time setup
- **onboard-tenant.sh**: New tenant creation and configuration
- **sync-secrets.sh**: AWS Secrets Manager synchronization
- **configure-environment.sh**: Environment variable setup

#### scripts/backup/
- **backup-platform.sh**: Complete platform backup operations
- **backup-workflows.sh**: N8N workflow-specific backups
- **restore-platform.sh**: Platform restoration procedures
- **verify-backup.sh**: Backup integrity verification

#### scripts/monitoring/
- **health-check.sh**: Platform health monitoring
- **audit-tenants.sh**: Multi-tenant resource auditing
- **get-platform-status.sh**: Real-time status reporting
- **verify-tenant-isolation.sh**: Security isolation verification

#### scripts/maintenance/
- **optimize-database.sh**: Database performance optimization
- **cleanup-temp.sh**: Temporary file cleanup
- **update-n8n.sh**: N8N version updates
- **scale-resources.sh**: Resource scaling operations

#### scripts/tenants/
- **manage-tenant.sh**: Tenant lifecycle management
- **isolate-tenant.sh**: Tenant isolation enforcement
- **migrate-tenant.sh**: Tenant migration procedures
- **tenant-resources.sh**: Per-tenant resource management

#### scripts/deployment/
- **deploy-platform.sh**: Platform deployment automation
- **update-platform.sh**: Platform update procedures
- **rollback-deployment.sh**: Deployment rollback capabilities

### 📁 configs/ - Configuration Management

**Purpose**: Centralized configuration management with templates and tenant-specific settings

#### configs/n8n/
- **config.json**: N8N platform configuration
- **environment.template**: N8N environment template
- **security-settings.json**: Security configuration templates

#### configs/tenants/
```
configs/tenants/
├── tenant-a/
│   ├── database.env
│   ├── limits.json
│   └── workflows.json
├── tenant-b/
│   ├── database.env
│   ├── limits.json
│   └── workflows.json
└── templates/
    ├── default-tenant.env
    ├── tier-standard.json
    └── tier-enterprise.json
```

#### configs/templates/
- **docker-compose.tenant.yml**: Per-tenant Docker Compose template
- **database-init.sql**: Database initialization template
- **secrets-template.json**: AWS Secrets Manager template

### 📁 docs/ - Comprehensive Documentation

**Purpose**: Complete documentation covering all aspects of the platform

#### Architecture Documentation
- **MULTI-TENANT-ARCHITECTURE.md**: Technical architecture details
- **VPS-INFRASTRUCTURE-COMPATIBILITY.md**: VPS deployment and compatibility

#### Operational Documentation
- **INFRASTRUCTURE-OPERATIONS-GUIDE.md**: Detailed script usage and procedures
- **CLIENT-ONBOARDING.md**: Client setup and onboarding procedures

#### Recovery Documentation
- **DISASTER-RECOVERY.md**: Recovery procedures and RTO/RPO specifications

### 📁 workflows/ - N8N Workflow Management

**Purpose**: Workflow templates, exports, and client-specific workflows

#### workflows/templates/
- **social-media-posting.json**: Multi-platform social media automation
- **ecommerce-price-monitoring.json**: Price tracking with markup calculations
- **client-onboarding.json**: Automated client setup workflows

#### workflows/exports/
```
workflows/exports/
├── tenant-a/
│   ├── active-workflows.json
│   └── archived-workflows.json
└── tenant-b/
    ├── active-workflows.json
    └── archived-workflows.json
```

## Advantages of Organized Structure

### 1. **Development Efficiency**
- **Intuitive Navigation**: Developers can quickly locate relevant files
- **Clear Separation**: Scripts, configs, and docs are clearly separated
- **Logical Grouping**: Related functionality grouped together

### 2. **Scalability**
- **Easy Expansion**: New categories can be added without cluttering
- **Tenant Isolation**: Per-tenant configurations clearly organized
- **Script Management**: Easy to add new operational scripts

### 3. **Team Collaboration**
- **Consistent Structure**: Team members know where to find and place files
- **Documentation Proximity**: Related documentation lives near relevant code
- **Onboarding Efficiency**: New team members can navigate the structure quickly

### 4. **Maintenance Benefits**
- **Easier Updates**: Scripts can be updated without affecting other areas
- **Clear Dependencies**: Relationships between files are more apparent
- **Version Control**: Changes are easier to track and review

## Comparison with Flat Structure (my-portfolio)

### When Flat Structure is Better

The my-portfolio repository uses a flat structure because:

1. **VPS Compatibility**: Absolute paths are simple and reliable
   ```bash
   /home/your-user/my-portfolio/backup-manager.sh  # Always works
   ```

2. **Production Reliability**: No subdirectory navigation in scripts
3. **Automation Simplicity**: Cron jobs and external scripts have predictable paths
4. **Historical Reliability**: Proven structure that works in production

### When Organized Structure is Better

The automation-platform uses organized structure because:

1. **Multi-Tenant Complexity**: Need to organize tenant-specific configurations
2. **Script Volume**: Many operational scripts benefit from categorization
3. **Team Development**: Multiple developers need clear navigation
4. **Future Expansion**: Platform will grow and needs scalable organization

## Best Practices for Organized Structure

### 1. **Maintain Clear Categories**
```bash
# Good: Clear functional grouping
scripts/backup/backup-platform.sh
scripts/monitoring/health-check.sh

# Bad: Unclear or overlapping categories
scripts/misc/backup-and-health-check.sh
```

### 2. **Use Consistent Naming**
```bash
# Good: Consistent verb-noun pattern
scripts/backup/backup-platform.sh
scripts/backup/backup-workflows.sh
scripts/backup/restore-platform.sh

# Bad: Inconsistent naming
scripts/backup/platform-backup.sh
scripts/backup/do-workflow-backup.sh
scripts/backup/restore.sh
```

### 3. **Document File Locations**
- Update `CLAUDE.md` when adding new directories
- Maintain this file structure guide
- Include file locations in script comments

### 4. **Preserve VPS Compatibility**
- Use relative paths within organized structure
- Maintain absolute path compatibility for VPS references
- Document critical file dependencies in `VPS-INFRASTRUCTURE-COMPATIBILITY.md`

## Migration Strategy (If Needed)

### Safe Directory Reorganization

If reorganization becomes necessary:

1. **Backup Everything**:
   ```bash
   ./scripts/backup/backup-platform.sh --full --tag="pre-reorganization"
   ```

2. **Create Symlinks for Compatibility**:
   ```bash
   # Maintain old paths during transition
   ln -s scripts/backup/backup-platform.sh backup-platform.sh
   ```

3. **Update External References Gradually**:
   - Update cron jobs
   - Update GitHub Actions
   - Update VPS automation scripts

4. **Test Thoroughly**:
   - Verify all scripts work with new paths
   - Test backup and restore procedures
   - Validate tenant operations

## Integration with VPS Infrastructure

### Shared Infrastructure Considerations

The automation-platform integrates with the my-portfolio VPS infrastructure:

- **Shared Monitoring**: Both services monitored via same Grafana/Prometheus
- **Shared Backup**: Cross-platform backup coordination
- **Network Integration**: Both use shared Docker networks
- **Disaster Recovery**: Both covered in VPS disaster recovery procedures

### Deployment Paths

**Production Deployment**:
```bash
# VPS deployment maintains organized structure
/home/your-user/automation-platform/scripts/backup/backup-platform.sh
/home/your-user/automation-platform/configs/tenants/client-a/
```

**Cross-Platform References**:
```bash
# Portfolio backup system can backup automation-platform
/home/your-user/my-portfolio/backup-manager.sh --include-automation-platform
```

## Summary

The organized directory structure in automation-platform provides:

### ✅ **Benefits**
- Clear navigation and development efficiency
- Scalable architecture for growing platform
- Logical separation of concerns
- Team collaboration advantages
- Easier maintenance and updates

### ✅ **Maintained Compatibility**
- VPS deployment compatibility preserved
- Integration with shared infrastructure
- Cross-platform backup and monitoring
- Production reliability maintained

### 🎯 **Best Use Cases**
- Multi-tenant platforms with complex operations
- Team development environments
- Platforms requiring frequent script additions
- Projects with extensive configuration management

The key is choosing the right structure for the specific project needs:
- **Flat structure** for production-critical infrastructure with external dependencies
- **Organized structure** for complex platforms requiring scalability and team development

Both approaches are valid and serve different purposes within the shared VPS infrastructure.