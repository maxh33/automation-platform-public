#!/bin/bash

# N8N Health Monitor with Automatic Recovery
# Community version - monitors your N8N automation platform and auto-recovers from issues
# Sanitized for public use

set -euo pipefail

# Configuration - Customize these for your setup
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="/var/log/n8n-health-monitor.log"
readonly PID_FILE="/var/run/n8n-health-monitor.pid"
readonly CHECK_INTERVAL=300  # 5 minutes
readonly TIMEOUT=30
readonly MAX_RETRIES=3
readonly RECOVERY_COOLDOWN=600  # 10 minutes between recoveries

# Service configuration - Update for your environment
readonly N8N_URL="${N8N_URL:-http://localhost:5678}"
readonly HEALTH_ENDPOINT="${N8N_URL}/healthz"
readonly COMPOSE_FILES="-f docker-compose.yml"

# Notification configuration (customize as needed)
readonly NOTIFICATION_ENABLED=false
readonly SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
readonly EMAIL_ENABLED=false
readonly EMAIL_TO="${EMAIL_TO:-admin@localhost}"

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
last_recovery_time=0
consecutive_failures=0
total_recoveries=0
start_time=$(date +%s)

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# Utility functions
cleanup() {
    log_info "Health monitor stopping (PID: $$)"
    rm -f "$PID_FILE"
    exit 0
}

send_notification() {
    local title="$1"
    local message="$2"
    local color="${3:-warning}"

    if [[ "$NOTIFICATION_ENABLED" == "true" && -n "$SLACK_WEBHOOK_URL" ]]; then
        local emoji="⚠️"
        case "$color" in
            "good") emoji="✅" ;;
            "danger") emoji="🚨" ;;
            "warning") emoji="⚠️" ;;
        esac

        local payload=$(cat <<EOF
{
    "text": "$emoji $title",
    "attachments": [
        {
            "color": "$color",
            "fields": [
                {
                    "title": "Service",
                    "value": "N8N Automation Platform",
                    "short": true
                },
                {
                    "title": "URL",
                    "value": "$N8N_URL",
                    "short": true
                },
                {
                    "title": "Details",
                    "value": "$message",
                    "short": false
                },
                {
                    "title": "Timestamp",
                    "value": "$(date '+%Y-%m-%d %H:%M:%S UTC')",
                    "short": true
                }
            ]
        }
    ]
}
EOF
        )

        curl -X POST -H 'Content-type: application/json' \
             --data "$payload" \
             "$SLACK_WEBHOOK_URL" &>/dev/null || true
    fi
}

# Health check functions
check_service_health() {
    local http_code
    local response_time

    # Test the main health endpoint
    local health_result=$(curl -s -o /dev/null -w "%{http_code}|%{time_total}" \
                         --max-time "$TIMEOUT" \
                         --connect-timeout 10 \
                         "$HEALTH_ENDPOINT" 2>/dev/null || echo "000|0")

    http_code="${health_result%|*}"
    response_time="${health_result#*|}"

    case "$http_code" in
        "200")
            log_info "✅ Health check passed (${response_time}s response time)"
            consecutive_failures=0
            return 0
            ;;
        "504")
            log_error "🚨 504 Gateway Timeout detected"
            ((consecutive_failures++))
            return 1
            ;;
        "000")
            log_error "❌ Connection failed (timeout or DNS failure)"
            ((consecutive_failures++))
            return 1
            ;;
        *)
            log_warn "⚠️ Unexpected HTTP status: $http_code"
            ((consecutive_failures++))
            return 1
            ;;
    esac
}

verify_local_service() {
    # Check if N8N container is running and healthy locally
    if ! docker ps --filter "name=n8n_automation" --filter "status=running" --quiet | grep -q .; then
        log_error "N8N container is not running"
        return 1
    fi

    # Test local health endpoint
    local local_health=$(curl -s --max-time 5 "http://127.0.0.1:5678/healthz" 2>/dev/null || echo "")
    if [[ "$local_health" != *'"status":"ok"'* ]]; then
        log_error "N8N local health check failed"
        return 1
    fi

    log_info "✅ N8N container is healthy locally"
    return 0
}

perform_recovery() {
    local current_time=$(date +%s)

    # Check recovery cooldown
    if (( current_time - last_recovery_time < RECOVERY_COOLDOWN )); then
        local remaining=$((RECOVERY_COOLDOWN - (current_time - last_recovery_time)))
        log_warn "Recovery in cooldown, ${remaining}s remaining"
        return 1
    fi

    log_warn "🔄 Starting automatic recovery process..."
    send_notification "N8N Recovery Started" "Detected $consecutive_failures consecutive failures, starting recovery" "warning"

    # Change to project directory
    cd "$PROJECT_DIR" || {
        log_error "Failed to change to project directory: $PROJECT_DIR"
        return 1
    }

    # Verify we can access Docker
    if ! docker ps &>/dev/null; then
        log_error "Cannot access Docker daemon"
        return 1
    fi

    # Perform the recovery
    log_info "Recreating N8N container..."
    if docker compose $COMPOSE_FILES up -d --force-recreate n8n &>> "$LOG_FILE"; then
        log_success "✅ Container recreation completed"

        # Wait for service to be ready
        log_info "Waiting for service to become ready..."
        local attempts=0
        while (( attempts < 12 )); do  # 2 minutes max
            sleep 10
            if check_service_health; then
                ((total_recoveries++))
                last_recovery_time=$current_time
                consecutive_failures=0

                local uptime=$((current_time - start_time))
                log_success "🎉 Recovery successful! Service restored in $((10 * attempts))s"
                send_notification "N8N Recovery Successful" \
                    "Service restored successfully after $((10 * attempts))s. Total recoveries: $total_recoveries. Monitor uptime: ${uptime}s" \
                    "good"
                return 0
            fi
            ((attempts++))
        done

        log_error "Recovery failed: Service did not become healthy within 2 minutes"
        send_notification "N8N Recovery Failed" \
            "Container recreated but service did not become healthy within 2 minutes" \
            "danger"
        return 1
    else
        log_error "Failed to recreate N8N container"
        send_notification "N8N Recovery Failed" \
            "Failed to recreate N8N container. Manual intervention required." \
            "danger"
        return 1
    fi
}

# Main monitoring loop
monitor_service() {
    log_info "🚀 N8N Health Monitor started (PID: $$)"
    log_info "Monitoring: $N8N_URL"
    log_info "Check interval: ${CHECK_INTERVAL}s"
    log_info "Recovery cooldown: ${RECOVERY_COOLDOWN}s"

    # Store PID
    echo $$ > "$PID_FILE"

    # Set up signal handlers
    trap cleanup SIGTERM SIGINT

    while true; do
        if check_service_health; then
            # Service is healthy
            if (( consecutive_failures > 0 )); then
                log_success "Service recovered naturally after $consecutive_failures failures"
                consecutive_failures=0
            fi
        else
            # Service is unhealthy
            log_warn "Health check failed (consecutive failures: $consecutive_failures)"

            # Verify local service health
            if verify_local_service; then
                log_info "Local service is healthy, issue might be with reverse proxy"

                # Attempt recovery after 2 consecutive failures
                if (( consecutive_failures >= 2 )); then
                    perform_recovery
                fi
            else
                log_error "Local service is also unhealthy, may need manual intervention"
                send_notification "N8N Service Critical" \
                    "Both external and local health checks failing. Manual intervention may be required." \
                    "danger"
            fi
        fi

        # Wait for next check
        sleep "$CHECK_INTERVAL"
    done
}

# Status and control functions
show_status() {
    echo -e "${BLUE}🔍 N8N Health Monitor Status${NC}"
    echo "=============================="

    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            local uptime=$(($(date +%s) - $(stat -c %Y "$PID_FILE")))
            echo -e "${GREEN}✅ Monitor is running (PID: $pid, uptime: ${uptime}s)${NC}"
        else
            echo -e "${RED}❌ Monitor is not running (stale PID file)${NC}"
            rm -f "$PID_FILE"
        fi
    else
        echo -e "${RED}❌ Monitor is not running${NC}"
    fi

    echo ""
    echo "Configuration:"
    echo "  Service URL: $N8N_URL"
    echo "  Check interval: ${CHECK_INTERVAL}s"
    echo "  Recovery cooldown: ${RECOVERY_COOLDOWN}s"
    echo "  Log file: $LOG_FILE"
    echo ""

    # Show recent log entries
    if [[ -f "$LOG_FILE" ]]; then
        echo "Recent log entries:"
        tail -10 "$LOG_FILE"
    fi
}

stop_monitor() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping health monitor (PID: $pid)"
            kill "$pid"
            # Wait for graceful shutdown
            local attempts=0
            while kill -0 "$pid" 2>/dev/null && (( attempts < 10 )); do
                sleep 1
                ((attempts++))
            done
            if kill -0 "$pid" 2>/dev/null; then
                log_warn "Force killing monitor process"
                kill -9 "$pid"
            fi
            rm -f "$PID_FILE"
            echo -e "${GREEN}✅ Monitor stopped${NC}"
        else
            echo -e "${YELLOW}⚠️ Monitor was not running${NC}"
            rm -f "$PID_FILE"
        fi
    else
        echo -e "${YELLOW}⚠️ Monitor is not running${NC}"
    fi
}

# Test functions
test_notifications() {
    echo "Testing notification system..."
    send_notification "N8N Monitor Test" "This is a test notification from the health monitor" "good"
    echo "Test notification sent (if configured)"
}

test_recovery() {
    echo -e "${YELLOW}⚠️ Testing recovery process (this will restart the N8N container)${NC}"
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        perform_recovery
    else
        echo "Recovery test cancelled"
    fi
}

# Main script logic
main() {
    case "${1:-}" in
        "start")
            if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
                echo -e "${YELLOW}⚠️ Monitor is already running${NC}"
                exit 1
            fi
            monitor_service
            ;;
        "stop")
            stop_monitor
            ;;
        "restart")
            stop_monitor
            sleep 2
            monitor_service
            ;;
        "status")
            show_status
            ;;
        "test-notifications")
            test_notifications
            ;;
        "test-recovery")
            test_recovery
            ;;
        "check")
            # Single health check
            if check_service_health; then
                echo -e "${GREEN}✅ Service is healthy${NC}"
                exit 0
            else
                echo -e "${RED}❌ Service is unhealthy${NC}"
                exit 1
            fi
            ;;
        "--help"|"help"|"")
            cat << EOF
N8N Health Monitor - Automatic Recovery System (Community Edition)

Usage: $0 <command>

Commands:
  start              Start the health monitor daemon
  stop               Stop the health monitor daemon
  restart            Restart the health monitor daemon
  status             Show monitor status and recent logs
  check              Perform single health check
  test-notifications Test notification system
  test-recovery      Test recovery process (restarts container)
  help               Show this help message

Configuration:
  Service URL: $N8N_URL
  Check interval: ${CHECK_INTERVAL}s (5 minutes)
  Recovery cooldown: ${RECOVERY_COOLDOWN}s (10 minutes)

Environment Variables:
  N8N_URL           URL to monitor (default: http://localhost:5678)
  SLACK_WEBHOOK_URL Slack webhook for notifications
  EMAIL_TO          Email address for notifications

Log files:
  $LOG_FILE

Examples:
  $0 start           # Start monitoring in background
  $0 status          # Check if monitor is running
  $0 check           # Test current service health
  $0 test-recovery   # Test the recovery mechanism

EOF
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Ensure we have proper permissions for log file
if ! touch "$LOG_FILE" 2>/dev/null && ! sudo touch "$LOG_FILE" 2>/dev/null; then
    # Use fallback log file if we can't create in /var/log
    LOG_FILE="$HOME/n8n-health-monitor.log"
    echo "Using fallback log file: $LOG_FILE" >&2
fi

# Run main function with all arguments
main "$@"