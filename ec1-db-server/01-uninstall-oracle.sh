#!/bin/bash
###############################################################################
# Script: 01-uninstall-oracle.sh
# Purpose: Uninstall existing Oracle Database 19c from Oracle Linux 8
# Server: EC1 (80.238.214.217)
# Run as: root
###############################################################################
set -eo pipefail

echo "=============================================="
echo "Oracle Database 19c Uninstallation Script"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

echo ""
log_warn "This will COMPLETELY REMOVE Oracle Database and all data!"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    log_info "Aborted by user"
    exit 0
fi

echo ""
log_info "Step 1: Stopping Oracle Services..."
systemctl stop oracle-database* 2>/dev/null || true
systemctl disable oracle-database* 2>/dev/null || true

echo ""
log_info "Step 2: Stopping Listener and Database..."
su - oracle -c "lsnrctl stop" 2>/dev/null || true
su - oracle -c "sqlplus / as sysdba <<< 'SHUTDOWN ABORT;'" 2>/dev/null || true

echo ""
log_info "Step 3: Killing remaining Oracle processes..."
pkill -9 -u oracle 2>/dev/null || true
sleep 3

echo ""
log_info "Step 4: Removing Oracle RPM packages..."
dnf remove -y oracle-database-ee-19c 2>/dev/null || true
dnf remove -y oracle-database-* 2>/dev/null || true

echo ""
log_info "Step 5: Removing Oracle directories..."
rm -rf /opt/oracle 2>/dev/null || true
rm -rf /u01/app/oracle 2>/dev/null || true
rm -rf /u01/app/oraInventory 2>/dev/null || true
rm -rf /u02/oradata 2>/dev/null || true
rm -rf /u02/fast_recovery_area 2>/dev/null || true

echo ""
log_info "Step 6: Removing configuration files..."
rm -f /etc/oratab 2>/dev/null || true
rm -f /etc/init.d/dbora 2>/dev/null || true
rm -f /etc/systemd/system/oracle* 2>/dev/null || true
systemctl daemon-reload

echo ""
log_info "Step 7: Verifying cleanup..."

echo ""
echo "=== Verification Results ==="
if [[ -d "/opt/oracle" ]]; then
    log_warn "/opt/oracle still exists"
else
    log_info "/opt/oracle removed ✓"
fi

if [[ -d "/u01/app/oracle" ]]; then
    log_warn "/u01/app/oracle still exists"
else
    log_info "/u01/app/oracle removed ✓"
fi

if pgrep -u oracle > /dev/null 2>&1; then
    log_warn "Oracle processes still running"
else
    log_info "No Oracle processes running ✓"
fi

echo ""
log_info "=============================================="
log_info "Oracle Database uninstallation complete!"
log_info "Run 02-prerequisites.sh next"
log_info "=============================================="
