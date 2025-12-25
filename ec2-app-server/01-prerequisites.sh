#!/bin/bash
###############################################################################
# Script: 01-prerequisites.sh
# Purpose: Install system prerequisites for ORDS
# Server: EC2 (80.238.234.247) - Ubuntu 24.04
# Run as: root (sudo su -)
###############################################################################
set -euo pipefail

echo "=============================================="
echo "EC2 System Prerequisites Setup"
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
   log_error "This script must be run as root (sudo su -)"
   exit 1
fi

echo ""
log_info "Step 1: Updating system packages..."
apt update && apt upgrade -y
log_info "System updated ✓"

echo ""
log_info "Step 2: Installing required packages..."
apt install -y wget curl unzip vim net-tools netcat-openbsd
log_info "Packages installed ✓"

echo ""
log_info "Step 3: Creating staging directory..."
mkdir -p /home/ubuntu/stage
chown ubuntu:ubuntu /home/ubuntu/stage
log_info "Staging directory created ✓"

echo ""
log_info "Step 4: Configuring firewall..."
# Enable UFW if not enabled
if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
fi

# Allow SSH (important!)
ufw allow 22/tcp

# Allow Tomcat/ORDS ports
ufw allow 8080/tcp
ufw allow 8443/tcp

log_info "Firewall configured ✓"
ufw status verbose

echo ""
log_info "Step 5: Testing connectivity to EC1 Database..."
DB_HOST="80.238.214.217"
DB_PORT="1521"

if nc -zw5 $DB_HOST $DB_PORT 2>/dev/null; then
    log_info "Connection to $DB_HOST:$DB_PORT successful ✓"
else
    log_warn "Cannot connect to $DB_HOST:$DB_PORT"
    log_warn "This might be because:"
    log_warn "  - EC1 database is not running yet"
    log_warn "  - Firewall on EC1 is blocking port 1521"
    log_warn "Continuing anyway..."
fi

echo ""
log_info "=============================================="
log_info "Prerequisites installed!"
log_info ""
log_info "Next steps:"
log_info "1. Upload ords-24.3.x.zip to /home/ubuntu/stage/"
log_info "2. Upload apex_24.2.zip to /home/ubuntu/stage/ (for images)"
log_info "3. Run 02-install-jdk.sh"
log_info "=============================================="
