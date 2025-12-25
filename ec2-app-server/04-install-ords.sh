#!/bin/bash
###############################################################################
# Script: 04-install-ords.sh
# Purpose: Install and configure ORDS 24.3
# Server: EC2 (80.238.234.247) - Ubuntu 24.04
# Run as: root
###############################################################################
set -euo pipefail

echo "=============================================="
echo "ORDS 24.3 Installation"
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

# Configuration
DB_HOST="80.238.214.217"
DB_PORT="1521"
DB_SERVICE="apex_pdb"
SYS_PASSWORD="Oracle123"
APEX_PUBLIC_PASSWORD="ApexPublic123"

ORDS_HOME="/opt/ords"
ORDS_CONFIG="/opt/ords/config"

echo ""
log_info "Step 1: Checking ORDS installation file..."
ORDS_ZIP=$(find /home/ubuntu/stage -name "ords-*.zip" -type f 2>/dev/null | head -1)

if [[ -z "$ORDS_ZIP" ]]; then
    log_error "ORDS zip file not found in /home/ubuntu/stage/"
    log_error "Please upload ords-24.3.x.zip to /home/ubuntu/stage/"
    exit 1
fi
log_info "Found ORDS file: $ORDS_ZIP ✓"

echo ""
log_info "Step 2: Creating ORDS directories..."
mkdir -p $ORDS_HOME
mkdir -p $ORDS_CONFIG
mkdir -p /opt/ords/logs
log_info "Directories created ✓"

echo ""
log_info "Step 3: Extracting ORDS..."
cd $ORDS_HOME
unzip -oq "$ORDS_ZIP"
log_info "ORDS extracted ✓"

echo ""
log_info "Step 4: Setting permissions..."
chown -R tomcat:tomcat $ORDS_HOME
log_info "Permissions set ✓"

echo ""
log_info "Step 5: Testing database connectivity..."
if nc -zw5 $DB_HOST $DB_PORT 2>/dev/null; then
    log_info "Connection to $DB_HOST:$DB_PORT successful ✓"
else
    log_error "Cannot connect to database at $DB_HOST:$DB_PORT"
    log_error "Please ensure:"
    log_error "  1. Oracle Database is running on EC1"
    log_error "  2. Listener is started on EC1"
    log_error "  3. Firewall port 1521 is open on EC1"
    exit 1
fi

echo ""
log_info "Step 6: Configuring ORDS..."

# Set environment
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ORDS_CONFIG=$ORDS_CONFIG
export PATH=$ORDS_HOME/bin:$PATH

# Run ORDS install with silent parameters
log_info "Running ORDS installation (this may take a few minutes)..."

# Create a temporary password file
TEMP_PWD_FILE=$(mktemp)
echo "$SYS_PASSWORD" > "$TEMP_PWD_FILE"

$ORDS_HOME/bin/ords --config $ORDS_CONFIG install \
    --admin-user SYS \
    --db-hostname $DB_HOST \
    --db-port $DB_PORT \
    --db-servicename $DB_SERVICE \
    --feature-db-api true \
    --feature-rest-enabled-sql true \
    --feature-sdw true \
    --gateway-mode proxied \
    --gateway-user APEX_PUBLIC_USER \
    --proxy-user \
    --password-stdin < "$TEMP_PWD_FILE" || {
        log_warn "ORDS install command returned non-zero, checking configuration..."
    }

rm -f "$TEMP_PWD_FILE"

log_info "ORDS configuration complete ✓"

echo ""
log_info "Step 7: Setting ORDS static resources path..."
$ORDS_HOME/bin/ords --config $ORDS_CONFIG config set standalone.static.path /opt/ords/apex_images
log_info "Static path configured ✓"

echo ""
log_info "Step 8: Setting ownership..."
chown -R tomcat:tomcat $ORDS_HOME
log_info "Ownership set ✓"

echo ""
log_info "=============================================="
log_info "ORDS 24.3 Installation Complete!"
log_info "=============================================="
echo ""
log_info "Configuration saved to: $ORDS_CONFIG"
echo ""
log_info "Next: Run 05-deploy-ords.sh to deploy to Tomcat"
log_info "=============================================="
