#!/bin/bash
###############################################################################
# Script: reset-all.sh
# Purpose: Reset Oracle installation to clean state
# Server: EC1 (80.238.214.217)
# Run as: root
###############################################################################
set -euo pipefail

echo "=============================================="
echo "Oracle Database FULL RESET"
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
log_warn "!!! WARNING !!!"
log_warn "This will COMPLETELY REMOVE Oracle Database and ALL DATA!"
log_warn "This action CANNOT be undone!"
echo ""
read -p "Type 'RESET' to confirm: " CONFIRM
if [[ "$CONFIRM" != "RESET" ]]; then
    log_info "Aborted by user"
    exit 0
fi

echo ""
log_info "Step 1: Stopping Oracle services..."
systemctl stop oracle-database.service 2>/dev/null || true
systemctl stop oracle-listener.service 2>/dev/null || true
systemctl disable oracle-database.service 2>/dev/null || true
systemctl disable oracle-listener.service 2>/dev/null || true

echo ""
log_info "Step 2: Stopping Oracle processes..."
su - oracle -c "lsnrctl stop" 2>/dev/null || true
su - oracle -c "sqlplus / as sysdba <<< 'SHUTDOWN ABORT;'" 2>/dev/null || true
sleep 3

echo ""
log_info "Step 3: Killing remaining processes..."
pkill -9 -u oracle 2>/dev/null || true
sleep 2

echo ""
log_info "Step 4: Removing Oracle directories..."
rm -rf /u01/app/oracle/product 2>/dev/null || true
rm -rf /u01/app/oracle/apex 2>/dev/null || true
rm -rf /u01/app/oracle/diag 2>/dev/null || true
rm -rf /u01/app/oracle/admin 2>/dev/null || true
rm -rf /u01/app/oracle/cfgtoollogs 2>/dev/null || true
rm -rf /u01/app/oracle/checkpoints 2>/dev/null || true
rm -rf /u01/app/oraInventory 2>/dev/null || true
rm -rf /u02/oradata 2>/dev/null || true
rm -rf /u02/fast_recovery_area 2>/dev/null || true

echo ""
log_info "Step 5: Removing service files..."
rm -f /etc/systemd/system/oracle-database.service 2>/dev/null || true
rm -f /etc/systemd/system/oracle-listener.service 2>/dev/null || true
rm -f /etc/oratab 2>/dev/null || true
systemctl daemon-reload

echo ""
log_info "Step 6: Recreating directories..."
mkdir -p /u01/app/oracle/product/19.3.0/dbhome_1
mkdir -p /u01/app/oraInventory
mkdir -p /u02/oradata
mkdir -p /u02/fast_recovery_area
chown -R oracle:oinstall /u01
chown -R oracle:oinstall /u02
chmod -R 775 /u01
chmod -R 775 /u02

echo ""
log_info "=============================================="
log_info "RESET COMPLETE!"
log_info "=============================================="
echo ""
echo "Directories reset:"
echo "  /u01/app/oracle/product/19.3.0/dbhome_1 (empty)"
echo "  /u01/app/oraInventory (empty)"
echo "  /u02/oradata (empty)"
echo ""
log_info "You can now restart from step 03-install-oracle.sh"
log_info "Make sure installation files are still in /home/oracle/stage/"
