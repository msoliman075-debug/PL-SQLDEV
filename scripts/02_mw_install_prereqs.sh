#!/bin/bash
#===============================================================================
# Script: 02_mw_install_prereqs.sh
# Server: EC2 (Middleware Server - 80.238.234.247)
# OS: Ubuntu 24.04
# OS User: root or sudo user
# Description: Install prerequisites for ORDS and Tomcat
#===============================================================================
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#===============================================================================
# Configuration
#===============================================================================
ORDS_USER="ords"
ORDS_HOME="/opt/ords"
TOMCAT_USER="tomcat"
TOMCAT_HOME="/opt/tomcat"
JAVA_VERSION="17"

#===============================================================================
# Main Installation
#===============================================================================

log_info "============================================================"
log_info "Starting Middleware Prerequisites Installation"
log_info "============================================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root or with sudo"
    exit 1
fi

log_info "Step 1: Update system packages"
apt update && apt upgrade -y

log_info "Step 2: Install required utilities"
apt install -y \
    unzip \
    wget \
    curl \
    net-tools \
    libaio1 \
    telnet \
    vim \
    htop

log_info "Step 3: Install OpenJDK ${JAVA_VERSION}"
apt install -y openjdk-${JAVA_VERSION}-jdk

# Verify Java installation
java -version
javac -version

log_info "Step 4: Configure JAVA_HOME"
JAVA_HOME_PATH="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64"

# Add to /etc/environment if not present
if ! grep -q "JAVA_HOME" /etc/environment; then
    echo "JAVA_HOME=\"${JAVA_HOME_PATH}\"" >> /etc/environment
    log_info "JAVA_HOME added to /etc/environment"
else
    log_warn "JAVA_HOME already configured in /etc/environment"
fi

# Export for current session
export JAVA_HOME="${JAVA_HOME_PATH}"
export PATH="${JAVA_HOME}/bin:${PATH}"

log_info "Step 5: Create ORDS system user"
if id "${ORDS_USER}" &>/dev/null; then
    log_warn "User ${ORDS_USER} already exists"
else
    useradd -r -m -U -d ${ORDS_HOME} -s /bin/bash ${ORDS_USER}
    log_info "User ${ORDS_USER} created"
fi

log_info "Step 6: Create ORDS directory structure"
mkdir -p ${ORDS_HOME}/ords-24.3
mkdir -p ${ORDS_HOME}/config
mkdir -p ${ORDS_HOME}/logs
mkdir -p ${ORDS_HOME}/doc_root/i
chown -R ${ORDS_USER}:${ORDS_USER} ${ORDS_HOME}

log_info "Step 7: Create Tomcat system user"
if id "${TOMCAT_USER}" &>/dev/null; then
    log_warn "User ${TOMCAT_USER} already exists"
else
    useradd -r -m -U -d ${TOMCAT_HOME} -s /bin/false ${TOMCAT_USER}
    log_info "User ${TOMCAT_USER} created"
fi

log_info "Step 8: Create Tomcat directory structure"
mkdir -p ${TOMCAT_HOME}
chown -R ${TOMCAT_USER}:${TOMCAT_USER} ${TOMCAT_HOME}

log_info "Step 9: Configure firewall (UFW)"
# Enable UFW if not enabled
ufw --force enable || true

# Allow SSH (important!)
ufw allow 22/tcp

# Allow Tomcat ports
ufw allow 8080/tcp
ufw allow 8443/tcp

# Show status
ufw status

log_info "============================================================"
log_info "Prerequisites Installation Complete!"
log_info "============================================================"
log_info ""
log_info "JAVA_HOME: ${JAVA_HOME_PATH}"
log_info "ORDS_HOME: ${ORDS_HOME}"
log_info "TOMCAT_HOME: ${TOMCAT_HOME}"
log_info ""
log_info "Next Steps:"
log_info "1. Upload ORDS 24.3 zip file to /tmp/ using WinSCP"
log_info "2. Run: ./03_mw_install_ords.sh"
log_info "============================================================"

# Verify installations
log_info ""
log_info "Verification:"
echo "Java Version:"
java -version 2>&1 | head -1
echo ""
echo "Users created:"
id ${ORDS_USER}
id ${TOMCAT_USER}
echo ""
echo "Directories:"
ls -la ${ORDS_HOME}
echo ""
ls -la ${TOMCAT_HOME} 2>/dev/null || echo "Tomcat directory ready"
