#!/bin/bash
###############################################################################
# Script: reset-all.sh
# Purpose: Reset EC2 to clean state (remove ORDS, Tomcat, optionally JDK)
# Server: EC2 (80.238.234.247) - Ubuntu 24.04
# Run as: root
###############################################################################
set -euo pipefail

echo "=============================================="
echo "EC2 Application Server RESET"
echo "=============================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

echo ""
log_warn "This will remove ORDS, Tomcat configuration, and deployments"
echo ""
echo "Options:"
echo "  1) Reset ORDS only (keep Tomcat)"
echo "  2) Reset ORDS and Tomcat (keep JDK)"
echo "  3) Full reset (remove everything)"
echo "  0) Cancel"
echo ""
read -p "Select option [0-3]: " OPTION

case $OPTION in
    1)
        echo ""
        log_info "Resetting ORDS only..."
        
        # Stop Tomcat
        systemctl stop tomcat 2>/dev/null || true
        
        # Remove ORDS deployments
        rm -rf /opt/tomcat/webapps/ords*
        rm -rf /opt/tomcat/webapps/i
        rm -f /opt/tomcat/conf/Catalina/localhost/ords.xml
        
        # Remove ORDS configuration (keep binaries)
        rm -rf /opt/ords/config/*
        
        # Restart Tomcat
        systemctl start tomcat
        
        log_info "ORDS reset complete ✓"
        log_info "Restart from: 04-install-ords.sh"
        ;;
        
    2)
        echo ""
        log_info "Resetting ORDS and Tomcat..."
        
        # Stop and disable Tomcat
        systemctl stop tomcat 2>/dev/null || true
        systemctl disable tomcat 2>/dev/null || true
        
        # Remove Tomcat
        rm -rf /opt/tomcat
        rm -f /etc/systemd/system/tomcat.service
        userdel -r tomcat 2>/dev/null || true
        
        # Remove ORDS
        rm -rf /opt/ords
        
        # Reload systemd
        systemctl daemon-reload
        
        log_info "ORDS and Tomcat reset complete ✓"
        log_info "Restart from: 03-install-tomcat.sh"
        ;;
        
    3)
        echo ""
        log_warn "This will remove JDK as well. Continue? (yes/no)"
        read -p "Confirm: " CONFIRM
        
        if [[ "$CONFIRM" != "yes" ]]; then
            log_info "Aborted"
            exit 0
        fi
        
        log_info "Full reset in progress..."
        
        # Stop services
        systemctl stop tomcat 2>/dev/null || true
        systemctl disable tomcat 2>/dev/null || true
        
        # Remove Tomcat
        rm -rf /opt/tomcat
        rm -f /etc/systemd/system/tomcat.service
        userdel -r tomcat 2>/dev/null || true
        
        # Remove ORDS
        rm -rf /opt/ords
        
        # Remove JDK
        apt remove -y openjdk-17-jdk 2>/dev/null || true
        apt autoremove -y
        
        # Clean environment
        rm -f /etc/profile.d/java.sh
        sed -i '/JAVA_HOME/d' /etc/environment
        
        # Reload systemd
        systemctl daemon-reload
        
        log_info "Full reset complete ✓"
        log_info "Restart from: 01-prerequisites.sh"
        ;;
        
    0|*)
        log_info "Cancelled"
        exit 0
        ;;
esac

echo ""
log_info "Reset completed!"
