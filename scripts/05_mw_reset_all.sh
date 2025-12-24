#!/bin/bash
#===============================================================================
# Script: 05_mw_reset_all.sh
# Server: EC2 (Middleware Server - 80.238.234.247)
# OS: Ubuntu 24.04
# OS User: root
# Description: Complete reset of ORDS and Tomcat installation
#===============================================================================
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

#===============================================================================
# Configuration
#===============================================================================
TOMCAT_USER="tomcat"
TOMCAT_HOME="/opt/tomcat"
ORDS_USER="ords"
ORDS_HOME="/opt/ords"

#===============================================================================
# Script Arguments
#===============================================================================
RESET_LEVEL="${1:-soft}"  # soft, hard, or complete

usage() {
    echo "Usage: $0 [reset_level]"
    echo ""
    echo "Reset Levels:"
    echo "  soft      - Reset ORDS configuration only (keeps Tomcat and ORDS binaries)"
    echo "  hard      - Reset ORDS and Tomcat (keeps users and ORDS zip)"
    echo "  complete  - Complete removal (removes everything including users)"
    echo ""
    echo "Examples:"
    echo "  $0 soft      # Re-configure ORDS without reinstalling"
    echo "  $0 hard      # Fresh install keeping ORDS zip"
    echo "  $0 complete  # Complete cleanup for fresh start"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root or with sudo"
    exit 1
fi

#===============================================================================
# Confirmation
#===============================================================================
log_warn "============================================================"
log_warn "ORDS/Tomcat Reset Script - Level: ${RESET_LEVEL}"
log_warn "============================================================"
echo ""

case ${RESET_LEVEL} in
    soft)
        echo "This will:"
        echo "  - Stop Tomcat"
        echo "  - Remove ORDS configuration"
        echo "  - Remove ORDS deployment from Tomcat"
        echo "  - Clear Tomcat work/logs directories"
        echo "  - Restart Tomcat"
        ;;
    hard)
        echo "This will:"
        echo "  - Stop and remove Tomcat service"
        echo "  - Remove Tomcat installation"
        echo "  - Remove ORDS configuration and extracted files"
        echo "  - Keep ORDS zip file and users"
        ;;
    complete)
        echo "This will:"
        echo "  - Stop and remove Tomcat service"
        echo "  - Remove Tomcat installation and user"
        echo "  - Remove complete ORDS installation and user"
        echo "  - Remove all related files"
        ;;
    *)
        usage
        ;;
esac

echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
    log_info "Reset cancelled."
    exit 0
fi

#===============================================================================
# Soft Reset - ORDS Configuration Only
#===============================================================================
soft_reset() {
    log_step "Performing SOFT reset..."
    
    # Stop Tomcat
    log_info "Stopping Tomcat..."
    systemctl stop tomcat 2>/dev/null || true
    sleep 3
    
    # Remove ORDS deployment
    log_info "Removing ORDS deployment..."
    rm -rf ${TOMCAT_HOME}/webapps/ords* 2>/dev/null || true
    rm -f ${TOMCAT_HOME}/conf/Catalina/localhost/ords.xml 2>/dev/null || true
    
    # Remove ORDS configuration
    log_info "Removing ORDS configuration..."
    rm -rf ${ORDS_HOME}/config/* 2>/dev/null || true
    mkdir -p ${ORDS_HOME}/config
    chown -R ${ORDS_USER}:${ORDS_USER} ${ORDS_HOME}/config
    
    # Clear Tomcat work and cache
    log_info "Clearing Tomcat work directory..."
    rm -rf ${TOMCAT_HOME}/work/* 2>/dev/null || true
    
    # Clear logs (optional)
    log_info "Clearing logs..."
    rm -rf ${TOMCAT_HOME}/logs/* 2>/dev/null || true
    rm -rf ${ORDS_HOME}/logs/* 2>/dev/null || true
    
    # Restart Tomcat
    log_info "Starting Tomcat..."
    systemctl start tomcat
    
    log_info "Soft reset complete!"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Run ORDS installation: sudo su - ords"
    log_info "     cd /opt/ords/ords-24.3 && ./bin/ords --config /opt/ords/config install"
    log_info "  2. Redeploy ORDS WAR and restart Tomcat"
}

#===============================================================================
# Hard Reset - ORDS and Tomcat
#===============================================================================
hard_reset() {
    log_step "Performing HARD reset..."
    
    # Stop and disable Tomcat
    log_info "Stopping Tomcat service..."
    systemctl stop tomcat 2>/dev/null || true
    systemctl disable tomcat 2>/dev/null || true
    sleep 3
    
    # Kill any remaining Tomcat processes
    pkill -f "catalina" 2>/dev/null || true
    pkill -f "tomcat" 2>/dev/null || true
    
    # Remove Tomcat service
    log_info "Removing Tomcat service..."
    rm -f /etc/systemd/system/tomcat.service
    systemctl daemon-reload
    
    # Remove Tomcat installation
    log_info "Removing Tomcat installation..."
    rm -rf ${TOMCAT_HOME}
    mkdir -p ${TOMCAT_HOME}
    chown -R ${TOMCAT_USER}:${TOMCAT_USER} ${TOMCAT_HOME}
    
    # Remove ORDS configuration and extracted files
    log_info "Removing ORDS configuration and files..."
    rm -rf ${ORDS_HOME}/config/*
    rm -rf ${ORDS_HOME}/ords-24.3
    rm -f ${ORDS_HOME}/ords.war
    rm -rf ${ORDS_HOME}/logs/*
    
    # Keep doc_root for APEX images
    
    # Recreate directories
    mkdir -p ${ORDS_HOME}/config
    mkdir -p ${ORDS_HOME}/ords-24.3
    mkdir -p ${ORDS_HOME}/logs
    chown -R ${ORDS_USER}:${ORDS_USER} ${ORDS_HOME}
    
    # Remove environment script
    rm -f /etc/profile.d/ords.sh
    
    log_info "Hard reset complete!"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Run: ./02_mw_install_prereqs.sh (if needed)"
    log_info "  2. Run: ./03_mw_install_ords.sh"
    log_info "  3. Configure ORDS: ords --config /opt/ords/config install"
    log_info "  4. Run: ./04_mw_install_tomcat.sh"
}

#===============================================================================
# Complete Reset - Everything
#===============================================================================
complete_reset() {
    log_step "Performing COMPLETE reset..."
    
    # First do hard reset
    log_info "Stopping all services..."
    systemctl stop tomcat 2>/dev/null || true
    systemctl disable tomcat 2>/dev/null || true
    
    # Kill any remaining processes
    pkill -f "catalina" 2>/dev/null || true
    pkill -f "tomcat" 2>/dev/null || true
    pkill -f "ords" 2>/dev/null || true
    sleep 3
    
    # Remove Tomcat service
    log_info "Removing Tomcat service..."
    rm -f /etc/systemd/system/tomcat.service
    systemctl daemon-reload
    
    # Remove Tomcat installation and user
    log_info "Removing Tomcat installation..."
    rm -rf ${TOMCAT_HOME}
    
    log_info "Removing Tomcat user..."
    userdel -r ${TOMCAT_USER} 2>/dev/null || true
    groupdel ${TOMCAT_USER} 2>/dev/null || true
    
    # Remove ORDS installation and user
    log_info "Removing ORDS installation..."
    rm -rf ${ORDS_HOME}
    
    log_info "Removing ORDS user..."
    userdel -r ${ORDS_USER} 2>/dev/null || true
    groupdel ${ORDS_USER} 2>/dev/null || true
    
    # Remove environment scripts
    rm -f /etc/profile.d/ords.sh
    
    # Remove downloaded files
    log_info "Cleaning up temp files..."
    rm -f /tmp/apache-tomcat-*.tar.gz 2>/dev/null || true
    # Keep ORDS zip for reinstallation
    # rm -f /tmp/ords-*.zip 2>/dev/null || true
    
    log_info "Complete reset finished!"
    log_info ""
    log_info "The system is now clean. ORDS zip file preserved in /tmp/"
    log_info ""
    log_info "To reinstall from scratch:"
    log_info "  1. Run: ./02_mw_install_prereqs.sh"
    log_info "  2. Run: ./03_mw_install_ords.sh"
    log_info "  3. Configure ORDS interactively"
    log_info "  4. Run: ./04_mw_install_tomcat.sh"
}

#===============================================================================
# Execute Reset
#===============================================================================
case ${RESET_LEVEL} in
    soft)
        soft_reset
        ;;
    hard)
        hard_reset
        ;;
    complete)
        complete_reset
        ;;
esac

log_info "============================================================"
log_info "Reset completed successfully!"
log_info "============================================================"
