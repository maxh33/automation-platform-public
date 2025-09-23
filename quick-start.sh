#!/bin/bash

# =========================================
# N8N Automation Platform Quick Start
# Automated setup script for new users
# =========================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log_info() { log "${BLUE}[INFO]${NC} $1"; }
log_warn() { log "${YELLOW}[WARN]${NC} $1"; }
log_error() { log "${RED}[ERROR]${NC} $1"; }
log_success() { log "${GREEN}[SUCCESS]${NC} $1"; }

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              N8N Multi-Tenant Automation Platform           ║"
    echo "║                        Quick Start                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker Desktop first."
        log_info "Download from: https://www.docker.com/products/docker-desktop"
        exit 1
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available. Please update Docker Desktop."
        exit 1
    fi

    # Check if Docker is running
    if ! docker ps &> /dev/null; then
        log_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi

    log_success "Prerequisites check passed"
}

generate_secrets() {
    log_info "Generating secure secrets..."

    # Check if openssl is available
    if command -v openssl &> /dev/null; then
        N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
        SESSION_SECRET=$(openssl rand -base64 32)
        # Use alphanumeric passwords for better PostgreSQL compatibility
        POSTGRES_PASSWORD=$(openssl rand -hex 16)
        REDIS_PASSWORD=$(openssl rand -hex 16)
    else
        log_warn "OpenSSL not available, using fallback method"
        N8N_ENCRYPTION_KEY="dGVzdC1lbmNyeXB0aW9uLWtleS0xMjM0NTY3ODkwYWJjZGVm"
        SESSION_SECRET="dGVzdC1zZXNzaW9uLXNlY3JldC0xMjM0NTY3ODkwYWJjZGVm"
        POSTGRES_PASSWORD="testdbpassword123"
        REDIS_PASSWORD="testredispassword123"
    fi

    log_success "Secrets generated"
}

setup_environment() {
    log_info "Setting up environment configuration..."

    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            log_info "Created .env from template"
        else
            log_error ".env.example not found. Please ensure you're in the correct directory."
            exit 1
        fi
    else
        log_warn ".env already exists, backing up to .env.backup"
        cp .env .env.backup
    fi

    # Update .env with generated secrets using sed with proper escaping
    sed -i "s|N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY|" .env
    sed -i "s|SESSION_SECRET=.*|SESSION_SECRET=$SESSION_SECRET|" .env
    sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env
    sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|" .env

    log_success "Environment configured"
}

start_services() {
    log_info "Starting N8N Automation Platform..."

    # Pull latest images
    log_info "Pulling Docker images (this may take a few minutes)..."
    docker compose pull

    # Start services
    log_info "Starting services..."
    docker compose up -d

    # Wait for services to be healthy
    log_info "Waiting for services to become healthy..."
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker compose ps --format "table {{.Service}}\t{{.Status}}" | grep -q "healthy"; then
            local healthy_count=$(docker compose ps --format "{{.Status}}" | grep -c "healthy" || echo "0")
            local total_services=4  # n8n, postgres, redis, crawl4ai

            if [ "$healthy_count" -eq "$total_services" ]; then
                log_success "All services are healthy!"
                break
            fi
        fi

        log_info "Services starting... ($((attempt + 1))/$max_attempts)"
        sleep 10
        ((attempt++))
    done

    if [ $attempt -eq $max_attempts ]; then
        log_warn "Services took longer than expected to start. Checking status..."
        docker compose ps
    fi
}

verify_installation() {
    log_info "Verifying installation..."

    # Test N8N health endpoint
    if curl -f http://localhost:5678/healthz &> /dev/null; then
        log_success "N8N is responding on http://localhost:5678"
    else
        log_error "N8N health check failed"
        return 1
    fi

    # Test Crawl4AI health endpoint
    if curl -f http://localhost:11235/health &> /dev/null; then
        log_success "Crawl4AI is responding on http://localhost:11235"
    else
        log_warn "Crawl4AI health check failed (this is optional for basic functionality)"
    fi

    log_success "Installation verification completed"
}

show_next_steps() {
    echo -e "\n${GREEN}🎉 N8N Automation Platform is ready!${NC}\n"

    echo -e "${BLUE}📍 Access Points:${NC}"
    echo "   N8N Web Interface: http://localhost:5678"
    echo "   Crawl4AI Service:  http://localhost:11235"
    echo ""

    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo "1. Open your browser and go to: http://localhost:5678"
    echo "2. Set up your N8N account (first time only)"
    echo "3. Import workflow templates from: ./workflows/templates/"
    echo "4. Configure your first automation workflow"
    echo ""

    echo -e "${BLUE}📚 Quick Actions:${NC}"
    echo "   View logs:           docker compose logs -f"
    echo "   Stop services:       docker compose down"
    echo "   Restart services:    docker compose restart"
    echo "   Check status:        docker compose ps"
    echo ""

    echo -e "${BLUE}📖 Documentation:${NC}"
    echo "   README:              ./README.md"
    echo "   Multi-tenant Guide:  ./docs/MULTI-TENANT-ARCHITECTURE.md"
    echo "   Client Onboarding:   ./docs/CLIENT-ONBOARDING.md"
    echo ""

    echo -e "${BLUE}🔧 Configuration Files:${NC}"
    echo "   Environment:         ./.env"
    echo "   Docker Compose:      ./docker-compose.yml"
    echo "   Workflow Templates:  ./workflows/templates/"
    echo ""

    echo -e "${YELLOW}💡 Tips:${NC}"
    echo "   - Import the social media automation template to get started quickly"
    echo "   - Configure webhook endpoints following the pattern: /webhook/{tenant-id}-{service}"
    echo "   - Check the workflows/templates/ directory for pre-built automation examples"
    echo ""
}

show_troubleshooting() {
    echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
    echo ""
    echo "If you encounter issues:"
    echo "1. Check Docker Desktop is running"
    echo "2. Ensure ports 5678 and 11235 are not in use"
    echo "3. View logs: docker compose logs"
    echo "4. Restart services: docker compose down && docker compose up -d"
    echo ""
    echo "For more help, check the GitHub issues or create a new one."
    echo ""
}

cleanup_on_error() {
    log_error "Setup failed. Cleaning up..."
    docker compose down &> /dev/null || true
    exit 1
}

main() {
    # Set up error handling
    trap cleanup_on_error ERR

    print_banner

    log_info "Starting N8N Automation Platform quick setup..."

    check_prerequisites
    generate_secrets
    setup_environment
    start_services
    verify_installation
    show_next_steps

    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        show_troubleshooting
    fi

    log_success "Quick start completed successfully!"
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        print_banner
        echo "N8N Automation Platform Quick Start"
        echo ""
        echo "Usage: $0 [--help]"
        echo ""
        echo "This script will:"
        echo "1. Check prerequisites (Docker, Docker Compose)"
        echo "2. Generate secure configuration"
        echo "3. Set up environment variables"
        echo "4. Start all services"
        echo "5. Verify installation"
        echo ""
        show_troubleshooting
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac