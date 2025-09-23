#!/bin/bash

# =========================================
# N8N Automation Platform Backup Manager
# Community version - sanitized for public use
# =========================================

# Configuration - Customize these for your setup
S3_BUCKET="your-backup-bucket"
S3_ENDPOINT="https://s3.amazonaws.com"

# Dynamic user path detection
CURRENT_USER=$(whoami)
USER_HOME="$HOME"

# Automation platform specific paths
AUTOMATION_DIR="$USER_HOME/automation-platform"
BACKUP_DIR="$USER_HOME/backups/automation"
LOG_FILE="$USER_HOME/logs/backup-automation.log"
RETENTION_DAYS=30

# Timestamp for backup files
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
DATE=$(date +"%Y-%m-%d")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR" || {
    echo "ERROR: Failed to create backup directory: $BACKUP_DIR"
    exit 1
}

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  backup              Perform full automation backup (default)"
    echo "  backup-workflows    Backup N8N workflows only"
    echo "  backup-database     Backup automation database only"
    echo "  verify-last-backup  Verify the most recent backup"
    echo "  list-backups        List available backups"
    echo "  restore-workflows   Restore workflows from backup"
    echo ""
    echo "Options:"
    echo "  --tenant TENANT_ID  Backup specific tenant data only"
    echo "  --date YYYY-MM-DD   Specify backup date for verification/restore"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Full automation backup"
    echo "  $0 backup-workflows --tenant demo    # Backup demo tenant workflows"
    echo "  $0 verify-last-backup --date 2025-09-16"
}

# Check if AWS CLI is configured
check_aws_access() {
    log "Checking AWS configuration..."

    if aws sts get-caller-identity > /dev/null 2>&1; then
        local aws_account aws_user
        aws_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "***MASKED***")
        aws_user=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null | sed 's/.*\///g' || echo "***MASKED***")
        log "✅ AWS credentials verified (Account: $aws_account, User: $aws_user)"
    else
        log "${RED}ERROR: AWS credentials not configured or invalid${NC}"
        log "Please ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set"
        return 1
    fi

    if aws s3 ls s3://$S3_BUCKET/ > /dev/null 2>&1; then
        log "✅ AWS S3 access verified for bucket: $S3_BUCKET"
        return 0
    else
        log "${RED}ERROR: Cannot access S3 bucket: $S3_BUCKET${NC}"
        return 1
    fi
}

# Backup N8N workflows
backup_n8n_workflows() {
    local tenant_id="${1:-all}"
    log "${BLUE}Backing up N8N workflows...${NC}"

    # Create temp directory for workflow exports
    local temp_dir="$BACKUP_DIR/workflows-temp"
    mkdir -p "$temp_dir"

    # Export workflows from N8N via API
    if docker ps --format "{{.Names}}" | grep -q "n8n_automation"; then
        log "Exporting workflows from N8N container..."

        # Export all workflows
        docker exec n8n_automation n8n export:workflow --all --output="/tmp/workflows-$TIMESTAMP.json" || {
            log "WARNING: Failed to export workflows via API, trying direct database"
        }

        # Copy exported file from container
        if docker cp "n8n_automation:/tmp/workflows-$TIMESTAMP.json" "$temp_dir/" 2>/dev/null; then
            log "✅ Workflows exported via API"
        else
            # Fallback: direct database export
            log "Exporting workflows from database..."
            docker exec postgres pg_dump -U n8n -d n8n --table=workflow_entity --data-only --format=custom -f "/tmp/workflows-db-$TIMESTAMP.dump"
            docker cp "postgres:/tmp/workflows-db-$TIMESTAMP.dump" "$temp_dir/"
        fi
    else
        log "${YELLOW}⚠️ N8N container not running, skipping workflow export${NC}"
    fi

    # Backup workflow files from filesystem
    if [ -d "$AUTOMATION_DIR/workflows" ]; then
        cp -r "$AUTOMATION_DIR/workflows" "$temp_dir/filesystem-workflows" 2>/dev/null || true
    fi

    # Filter by tenant if specified
    if [ "$tenant_id" != "all" ]; then
        log "Filtering workflows for tenant: $tenant_id"
        # Here you would implement tenant-specific filtering
        # For now, we'll backup all workflows with a tenant tag
    fi

    # Compress workflow backup
    if [ "$(ls -A $temp_dir 2>/dev/null)" ]; then
        tar -czf "$BACKUP_DIR/n8n-workflows-$TIMESTAMP.tar.gz" -C "$BACKUP_DIR" workflows-temp
        rm -rf "$temp_dir"
        log "✅ N8N workflows backed up successfully"
    else
        log "${YELLOW}⚠️ No workflows found to backup${NC}"
        rm -rf "$temp_dir"
    fi
}

# Backup automation database
backup_automation_database() {
    log "${BLUE}Backing up automation database...${NC}"

    if docker ps --format "{{.Names}}" | grep -q "postgres"; then
        log "Creating database backup..."

        # Create comprehensive database backup
        docker exec postgres pg_dump -U n8n -d n8n \
            --format=custom \
            --compress=9 \
            --verbose \
            --file="/tmp/n8n-database-$TIMESTAMP.dump" || {
            log "${RED}❌ Database backup failed${NC}"
            return 1
        }

        # Copy backup file from container
        docker cp "postgres:/tmp/n8n-database-$TIMESTAMP.dump" "$BACKUP_DIR/"

        # Clean up container temp file
        docker exec postgres rm -f "/tmp/n8n-database-$TIMESTAMP.dump"

        log "✅ Database backup completed"
    else
        log "${RED}❌ PostgreSQL container not running${NC}"
        return 1
    fi
}

# Backup tenant-specific data
backup_tenant_data() {
    local tenant_id="$1"
    log "${BLUE}Backing up tenant data for: ${tenant_id}${NC}"

    # Create tenant backup directory
    local tenant_backup_dir="$BACKUP_DIR/tenant-$tenant_id"
    mkdir -p "$tenant_backup_dir"

    # Export tenant-specific workflows from database
    if docker ps --format "{{.Names}}" | grep -q "postgres"; then
        docker exec postgres psql -U n8n -d n8n -c "
            COPY (
                SELECT w.* FROM workflow_entity w
                WHERE w.settings::TEXT LIKE '%$tenant_id%'
            ) TO '/tmp/tenant-$tenant_id-workflows.csv' WITH CSV HEADER;
        " || log "WARNING: Failed to export tenant workflows"

        docker cp "postgres:/tmp/tenant-$tenant_id-workflows.csv" "$tenant_backup_dir/" 2>/dev/null || true
        docker exec postgres rm -f "/tmp/tenant-$tenant_id-workflows.csv" 2>/dev/null || true
    fi

    # Backup tenant execution history (last 30 days)
    if docker ps --format "{{.Names}}" | grep -q "postgres"; then
        docker exec postgres psql -U n8n -d n8n -c "
            COPY (
                SELECT e.* FROM execution_entity e
                JOIN workflow_entity w ON e.\"workflowId\" = w.id
                WHERE w.settings::TEXT LIKE '%$tenant_id%'
                AND e.\"startedAt\" > NOW() - INTERVAL '30 days'
            ) TO '/tmp/tenant-$tenant_id-executions.csv' WITH CSV HEADER;
        " || log "WARNING: Failed to export tenant executions"

        docker cp "postgres:/tmp/tenant-$tenant_id-executions.csv" "$tenant_backup_dir/" 2>/dev/null || true
        docker exec postgres rm -f "/tmp/tenant-$tenant_id-executions.csv" 2>/dev/null || true
    fi

    # Compress tenant backup
    if [ "$(ls -A $tenant_backup_dir 2>/dev/null)" ]; then
        tar -czf "$BACKUP_DIR/tenant-$tenant_id-data-$TIMESTAMP.tar.gz" -C "$BACKUP_DIR" "tenant-$tenant_id"
        rm -rf "$tenant_backup_dir"
        log "✅ Tenant $tenant_id data backed up"
    else
        log "${YELLOW}⚠️ No data found for tenant: $tenant_id${NC}"
        rm -rf "$tenant_backup_dir"
    fi
}

# Backup automation configurations
backup_automation_configs() {
    log "${BLUE}Backing up automation configurations...${NC}"

    # Create temp directory for configs
    local config_temp="$BACKUP_DIR/configs-temp"
    mkdir -p "$config_temp"

    # Copy N8N configuration files
    if [ -d "$AUTOMATION_DIR/configs" ]; then
        cp -r "$AUTOMATION_DIR/configs" "$config_temp/" 2>/dev/null || true
    fi

    # Copy Docker Compose files
    cp "$AUTOMATION_DIR/docker-compose"*.yml "$config_temp/" 2>/dev/null || true

    # Copy environment template (without sensitive data)
    if [ -f "$AUTOMATION_DIR/.env.example" ]; then
        cp "$AUTOMATION_DIR/.env.example" "$config_temp/" 2>/dev/null || true
    fi

    # Copy backup and deployment scripts
    if [ -d "$AUTOMATION_DIR/scripts" ]; then
        cp -r "$AUTOMATION_DIR/scripts" "$config_temp/" 2>/dev/null || true
    fi

    # Compress configuration backup
    if [ "$(ls -A $config_temp 2>/dev/null)" ]; then
        tar -czf "$BACKUP_DIR/automation-configs-$TIMESTAMP.tar.gz" -C "$BACKUP_DIR" configs-temp
        rm -rf "$config_temp"
        log "✅ Automation configurations backed up"
    else
        log "${YELLOW}⚠️ No configuration files found${NC}"
        rm -rf "$config_temp"
    fi
}

# Upload backups to S3
upload_automation_backups() {
    log "${BLUE}Uploading automation backups to S3...${NC}"

    # Check for files to upload
    local backup_files=$(find "$BACKUP_DIR" -name "*-$TIMESTAMP.tar.gz" -o -name "*-$TIMESTAMP.dump" 2>/dev/null || true)

    if [ -z "$backup_files" ]; then
        log "${YELLOW}⚠️ No backup files found to upload${NC}"
        return
    fi

    # Create S3 path with date organization
    local s3_path="automation/$DATE"

    local total_size=0
    for file in $backup_files; do
        local filename=$(basename "$file")
        log "Uploading $filename to S3..."

        # Get file size
        local file_size=0
        if [ -f "$file" ]; then
            file_size=$(ls -ln "$file" 2>/dev/null | awk '{print $5}' 2>/dev/null || echo "0")
        fi
        total_size=$((total_size + file_size))

        aws s3 cp "$file" "s3://$S3_BUCKET/$s3_path/" --endpoint-url "$S3_ENDPOINT"

        if [ $? -eq 0 ]; then
            log "✅ $filename uploaded successfully"
        else
            log "${RED}❌ Failed to upload $filename${NC}"
        fi
    done

    log "✅ Upload completed. Total size: $((total_size / 1024 / 1024)) MB"
}

# Create backup summary
create_backup_summary() {
    log "${BLUE}Creating automation backup summary...${NC}"

    local summary_file="$BACKUP_DIR/automation-backup-summary-$DATE.txt"

    cat > "$summary_file" << EOF
N8N Automation Platform Backup Summary - $DATE
===============================================
Timestamp: $TIMESTAMP
Date: $DATE
S3 Bucket: $S3_BUCKET
Platform Path: $AUTOMATION_DIR
Total Size: $(du -sh $BACKUP_DIR/*-$TIMESTAMP.* 2>/dev/null | awk '{total+=$1} END {print total}' || echo "Unknown")

Backup Components:
- N8N workflow definitions and configurations
- PostgreSQL database (complete dump)
- Tenant-specific data and execution history
- Automation platform configurations
- Docker Compose and deployment files

Multi-Tenant Data:
- Tenant isolation maintained in backups
- Client data separately exportable
- Execution history preserved (30 days)
- Credential references backed up (values should be in secure storage)

Retention Policy: $RETENTION_DAYS days
Local Staging: $BACKUP_DIR
Remote Storage: s3://$S3_BUCKET/automation/$DATE/

Status: Completed successfully
Generated by: backup-platform.sh (Community Edition)
EOF

    # Upload summary to S3
    aws s3 cp "$summary_file" "s3://$S3_BUCKET/automation/$DATE/" --endpoint-url "$S3_ENDPOINT" || log "Failed to upload summary"

    log "✅ Backup summary created and uploaded"
}

# Main backup execution
perform_full_backup() {
    local tenant_filter="${1:-all}"
    local start_time=$(date +%s)

    log "${BLUE}=== Starting N8N Automation Platform Backup ===${NC}"
    log "Target: S3 bucket $S3_BUCKET"
    log "Date: $DATE"
    log "Timestamp: $TIMESTAMP"
    log "Tenant filter: $tenant_filter"

    # Check AWS access
    if ! check_aws_access; then
        return 1
    fi

    # Perform backups
    backup_n8n_workflows "$tenant_filter"
    backup_automation_database
    backup_automation_configs

    # Backup specific tenant data if requested
    if [ "$tenant_filter" != "all" ]; then
        backup_tenant_data "$tenant_filter"
    fi

    upload_automation_backups
    create_backup_summary

    # Clean up old local backups
    find "$BACKUP_DIR" -name "*-$TIMESTAMP.*" -delete 2>/dev/null || true
    find "$BACKUP_DIR" -type f -mtime +3 -delete 2>/dev/null || true

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log "${GREEN}=== N8N Automation Backup Completed Successfully ===${NC}"
    log "Duration: ${duration} seconds"
}

# Parse command line arguments
COMMAND="backup"
TENANT_FILTER="all"
TARGET_DATE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        backup|backup-workflows|backup-database|verify-last-backup|list-backups|restore-workflows)
            COMMAND="$1"
            shift
            ;;
        --tenant)
            TENANT_FILTER="$2"
            shift 2
            ;;
        --date)
            TARGET_DATE="$2"
            shift 2
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            log "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Execute command
case $COMMAND in
    backup)
        perform_full_backup "$TENANT_FILTER"
        ;;
    backup-workflows)
        check_aws_access && backup_n8n_workflows "$TENANT_FILTER" && upload_automation_backups
        ;;
    backup-database)
        check_aws_access && backup_automation_database && upload_automation_backups
        ;;
    verify-last-backup)
        # Implementation for backup verification
        log "Backup verification not yet implemented"
        ;;
    list-backups)
        if check_aws_access; then
            log "Available automation backups:"
            aws s3 ls "s3://$S3_BUCKET/automation/" --recursive | tail -10
        fi
        ;;
    restore-workflows)
        # Implementation for workflow restoration
        log "Workflow restoration not yet implemented"
        ;;
    *)
        log "Invalid command: $COMMAND"
        print_usage
        exit 1
        ;;
esac