#!/bin/bash
#===============================================================================
# Script: 03_mw_install_ords.sh
# Server: EC2 (Middleware Server - 80.238.234.247)
# OS: Ubuntu 24.04
# OS User: root (will switch to ords user for installation)
# Description: Install and configure ORDS 24.3
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
# Configuration - MODIFY THESE VALUES
#===============================================================================
# Database connection
DB_HOST="80.238.214.217"
DB_PORT="1521"
DB_SERVICE="PDB1"

# ORDS paths
ORDS_USER="ords"
ORDS_HOME="/opt/ords"
ORDS_VERSION="24.3"
ORDS_ZIP_PATH="/tmp/ords-24.3.0.*.zip"  # Will find the zip file

# Config paths
ORDS_CONFIG="${ORDS_HOME}/config"
ORDS_LOGS="${ORDS_HOME}/logs"
ORDS_DOC_ROOT="${ORDS_HOME}/doc_root"

#===============================================================================
# Pre-flight Checks
#===============================================================================

log_info "============================================================"
log_info "ORDS ${ORDS_VERSION} Installation Script"
log_info "============================================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root or with sudo"
    exit 1
fi

# Find ORDS zip file
ORDS_ZIP=$(ls ${ORDS_ZIP_PATH} 2>/dev/null | head -1)
if [ -z "${ORDS_ZIP}" ]; then
    log_error "ORDS zip file not found in /tmp/"
    log_error "Please upload ords-24.3.0.xxx.zip to /tmp/ using WinSCP"
    exit 1
fi
log_info "Found ORDS zip: ${ORDS_ZIP}"

# Test database connectivity
log_step "Testing database connectivity..."
if timeout 5 bash -c "echo >/dev/tcp/${DB_HOST}/${DB_PORT}" 2>/dev/null; then
    log_info "Database port ${DB_HOST}:${DB_PORT} is reachable"
else
    log_error "Cannot connect to database at ${DB_HOST}:${DB_PORT}"
    log_error "Please verify:"
    log_error "  1. Database is running"
    log_error "  2. Listener is started"
    log_error "  3. Firewall port 1521 is open on EC1"
    exit 1
fi

#===============================================================================
# Installation
#===============================================================================

log_step "Step 1: Extract ORDS zip file"
if [ -d "${ORDS_HOME}/ords-${ORDS_VERSION}/bin" ]; then
    log_warn "ORDS already extracted. Skipping..."
else
    sudo -u ${ORDS_USER} unzip -o "${ORDS_ZIP}" -d "${ORDS_HOME}/ords-${ORDS_VERSION}"
    log_info "ORDS extracted to ${ORDS_HOME}/ords-${ORDS_VERSION}"
fi

# Verify extraction
if [ ! -f "${ORDS_HOME}/ords-${ORDS_VERSION}/bin/ords" ]; then
    log_error "ORDS binary not found after extraction"
    log_error "Directory contents:"
    ls -la "${ORDS_HOME}/ords-${ORDS_VERSION}/"
    exit 1
fi

log_step "Step 2: Set permissions"
chown -R ${ORDS_USER}:${ORDS_USER} ${ORDS_HOME}
chmod +x ${ORDS_HOME}/ords-${ORDS_VERSION}/bin/ords

log_step "Step 3: Create ORDS environment script"
cat > /etc/profile.d/ords.sh << 'EOF'
# ORDS Environment Variables
export ORDS_HOME="/opt/ords"
export ORDS_CONFIG="/opt/ords/config"
export PATH="${ORDS_HOME}/ords-24.3/bin:${PATH}"
EOF
chmod 644 /etc/profile.d/ords.sh

# Source for current session
source /etc/profile.d/ords.sh

log_step "Step 4: Verify ORDS version"
sudo -u ${ORDS_USER} ${ORDS_HOME}/ords-${ORDS_VERSION}/bin/ords --version

log_info "============================================================"
log_info "ORDS Extraction Complete!"
log_info "============================================================"
log_info ""
log_info "ORDS Binary: ${ORDS_HOME}/ords-${ORDS_VERSION}/bin/ords"
log_info "ORDS Config: ${ORDS_CONFIG}"
log_info ""
log_warn "============================================================"
log_warn "NEXT: Run ORDS Installation Interactively"
log_warn "============================================================"
log_info ""
log_info "Switch to ords user and run the installation:"
log_info ""
echo -e "${YELLOW}sudo su - ords${NC}"
echo -e "${YELLOW}cd /opt/ords/ords-24.3${NC}"
echo -e "${YELLOW}./bin/ords --config /opt/ords/config install${NC}"
log_info ""
log_info "During installation, provide:"
log_info "  - Connection Type: Basic"
log_info "  - Hostname: ${DB_HOST}"
log_info "  - Port: ${DB_PORT}"
log_info "  - Service Name: ${DB_SERVICE}"
log_info "  - Administrator: SYS AS SYSDBA"
log_info "  - SYS Password: (your SYS password)"
log_info ""
log_info "============================================================"
log_info "Alternative: Non-Interactive Installation"
log_info "============================================================"
log_info ""
log_info "Create a password file first:"
echo -e "${YELLOW}cat > /tmp/ords_passwords.txt << 'PASSEOF'"
echo "SYS_PASSWORD_HERE"
echo "ORDS_PUBLIC_USER_PASSWORD_HERE"
echo -e "PASSEOF${NC}"
log_info ""
log_info "Then run:"
echo -e "${YELLOW}sudo -u ords ${ORDS_HOME}/ords-${ORDS_VERSION}/bin/ords --config ${ORDS_CONFIG} install \\
  --admin-user SYS \\
  --db-hostname ${DB_HOST} \\
  --db-port ${DB_PORT} \\
  --db-servicename ${DB_SERVICE} \\
  --feature-sdw true \\
  --gateway-mode proxied \\
  --gateway-user APEX_PUBLIC_USER \\
  --proxy-user \\
  --password-stdin < /tmp/ords_passwords.txt${NC}"
log_info ""
log_info "After installation, secure the password file:"
echo -e "${YELLOW}rm -f /tmp/ords_passwords.txt${NC}"
log_info "============================================================"
