# Contributing to N8N Multi-Tenant Automation Platform

Thank you for your interest in contributing to the N8N Multi-Tenant Automation Platform! This document provides guidelines and information for contributors.

## 🚀 Quick Start

1. **Fork the Repository**: Click the "Fork" button on GitHub
2. **Clone Your Fork**: `git clone https://github.com/your-username/automation-platform.git`
3. **Create a Branch**: `git checkout -b feature/your-feature-name`
4. **Make Changes**: Implement your feature or fix
5. **Test Thoroughly**: Ensure all services work correctly
6. **Submit Pull Request**: Open a PR with a clear description

## 🎯 Ways to Contribute

### Code Contributions
- **Bug Fixes**: Fix issues in the platform or workflows
- **New Features**: Add functionality to enhance the platform
- **Workflow Templates**: Create new automation templates
- **Documentation**: Improve guides and documentation
- **Performance**: Optimize services and resource usage

### Non-Code Contributions
- **Issue Reports**: Report bugs or suggest improvements
- **Testing**: Test new features and provide feedback
- **Documentation**: Write tutorials and guides
- **Community Support**: Help other users in discussions

## 📋 Development Setup

### Prerequisites
- Docker Desktop 4.0+
- Git
- Code editor (VS Code recommended)
- 8GB RAM minimum

### Local Setup
```bash
# Clone your fork
git clone https://github.com/your-username/automation-platform.git
cd automation-platform

# Copy environment template
cp .env.example .env

# Configure required environment variables
# Edit .env with your settings

# Start development environment
docker compose up -d

# Verify services are running
docker compose ps
curl http://localhost:5678/healthz
```

### Environment Configuration
Minimum required configuration for development:
```bash
N8N_ENCRYPTION_KEY=your-32-character-key  # Generate with: openssl rand -base64 32
POSTGRES_PASSWORD=dev-password
REDIS_PASSWORD=dev-password
SESSION_SECRET=your-session-secret        # Generate with: openssl rand -base64 32
```

## 🛠️ Development Guidelines

### Code Style
- **Shell Scripts**: Use bash with strict error handling (`set -euo pipefail`)
- **Documentation**: Use clear, concise language
- **Docker**: Follow multi-stage builds and security best practices
- **Environment Variables**: Use consistent naming conventions

### Workflow Templates
When creating new workflow templates:
- **Generic Design**: Make templates adaptable for multiple clients
- **Documentation**: Include clear setup instructions
- **Error Handling**: Implement robust error handling
- **Security**: Never hardcode credentials or sensitive data

### Testing Requirements
Before submitting a pull request:
1. **Docker Validation**: `docker compose config --quiet`
2. **Service Health**: All services must pass health checks
3. **Template Testing**: Verify workflow templates can be imported
4. **Documentation**: Test setup instructions work correctly

## 📝 Pull Request Process

### Before Submitting
1. **Update Documentation**: Ensure docs reflect your changes
2. **Test Thoroughly**: Test in clean Docker environment
3. **Check Dependencies**: Verify no unnecessary dependencies added
4. **Sanitize Content**: Remove any sensitive or personal information

### PR Description Template
```markdown
## Description
Brief description of the changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Workflow template addition

## Testing
- [ ] Docker Compose configuration validates
- [ ] All services start and pass health checks
- [ ] Workflow templates import successfully
- [ ] Documentation is accurate and complete

## Checklist
- [ ] My code follows the project's coding standards
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have tested that my fix is effective or that my feature works
```

## 🏗️ Architecture Guidelines

### Multi-Tenant Considerations
- **Data Isolation**: Ensure tenant data remains separated
- **Scalability**: Design for multiple tenants per instance
- **Security**: Implement proper access controls
- **Performance**: Consider resource usage per tenant

### Docker Best Practices
- **Health Checks**: Include health checks for all services
- **Resource Limits**: Define appropriate CPU and memory limits
- **Secrets Management**: Use external secret management
- **Network Security**: Minimize exposed ports

### Workflow Design Patterns
- **Parameterization**: Use environment variables for configuration
- **Error Handling**: Implement comprehensive error handling
- **Logging**: Include appropriate logging for debugging
- **Retry Logic**: Add retry mechanisms for external API calls

## 📚 Documentation Standards

### Code Documentation
- **Scripts**: Include header comments explaining purpose
- **Complex Logic**: Add inline comments for clarity
- **Configuration**: Document all configuration options
- **Examples**: Provide usage examples

### User Documentation
- **Clear Instructions**: Step-by-step setup guides
- **Prerequisites**: List all requirements clearly
- **Troubleshooting**: Include common issues and solutions
- **Screenshots**: Use visuals where helpful

## 🐛 Issue Reporting

### Bug Reports
Include the following information:
- **Environment**: OS, Docker version, system specs
- **Steps to Reproduce**: Clear reproduction steps
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **Logs**: Relevant error messages or logs
- **Screenshots**: Visual evidence if applicable

### Feature Requests
Provide:
- **Use Case**: Why this feature is needed
- **Proposed Solution**: How it should work
- **Alternatives**: Other solutions considered
- **Impact**: Who would benefit from this feature

## 🔒 Security Considerations

### Sensitive Information
- **Never commit**: API keys, passwords, or personal data
- **Use Examples**: Provide template values in examples
- **Sanitize Logs**: Ensure logs don't contain sensitive data
- **Review Carefully**: Check for accidental sensitive data inclusion

### Vulnerability Reporting
If you discover a security vulnerability:
1. **Do Not** create a public issue
2. **Email** the maintainers privately
3. **Provide Details**: Clear description and reproduction steps
4. **Wait for Response**: Allow time for assessment and fix

## 🤝 Community Guidelines

### Code of Conduct
- **Be Respectful**: Treat all community members with respect
- **Be Inclusive**: Welcome contributors of all backgrounds
- **Be Constructive**: Provide helpful, actionable feedback
- **Be Patient**: Understand that reviews take time

### Communication
- **GitHub Issues**: For bug reports and feature requests
- **Pull Requests**: For code discussions and reviews
- **Discussions**: For general questions and community support

## 🎉 Recognition

Contributors are recognized through:
- **Contributors List**: Listed in project documentation
- **Release Notes**: Mentioned in relevant release notes
- **Community Highlights**: Featured in community updates

## 📖 Resources

### Documentation
- [Multi-Tenant Architecture](docs/MULTI-TENANT-ARCHITECTURE.md)
- [Client Onboarding Guide](docs/CLIENT-ONBOARDING.md)
- [File Structure Guide](docs/FILE-STRUCTURE-GUIDE.md)

### External Resources
- [N8N Documentation](https://docs.n8n.io/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## ❓ Questions?

If you have questions about contributing:
1. Check existing documentation
2. Search existing issues
3. Create a new discussion thread
4. Tag maintainers if urgent

---

Thank you for contributing to the N8N Multi-Tenant Automation Platform! 🚀