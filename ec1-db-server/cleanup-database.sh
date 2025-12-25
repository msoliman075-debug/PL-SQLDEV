#!/bin/bash
###############################################################################
# Script: cleanup-database.sh
# Purpose: Remove existing Oracle database to allow fresh install
# Server: EC1 (80.238.214.217)
# Run as: oracle (some steps need root)
###############################################################################
set -eo pipefail

echo "=============================================="
echo "Oracle Database Cleanup Script"
echo "=============================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Source environment
if [[ -f ~/.bash_profile ]]; then
    source ~/.bash_profile
fi

export CV_ASSUME_DISTID=OEL7.8

echo ""
log_warn "This will DELETE the existing ORCL database!"
read -p "Continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    log_info "Aborted"
    exit 0
fi

echo ""
log_info "Step 1: Attempting to delete database using DBCA..."

# Try dbca delete first
dbca -silent -deleteDatabase -sourceDB ORCL 2>/dev/null && {
    log_info "Database deleted via DBCA ✓"
} || {
    log_warn "DBCA delete failed, performing manual cleanup..."
}

echo ""
log_info "Step 2: Stopping any running Oracle processes..."

# Try graceful shutdown
sqlplus -s / as sysdba << 'EOF' 2>/dev/null || true
SHUTDOWN ABORT;
EXIT;
EOF

# Kill any remaining processes
pkill -9 -f "ora_.*_ORCL" 2>/dev/null || true
sleep 2

echo ""
log_info "Step 3: Removing database files..."

# Remove data files
rm -rf /u02/oradata/ORCL 2>/dev/null || true
rm -rf /u02/oradata/apex_pdb 2>/dev/null || true
rm -rf /u02/fast_recovery_area/ORCL 2>/dev/null || true

# Remove admin files
rm -rf /u01/app/oracle/admin/ORCL 2>/dev/null || true

# Remove audit files
rm -rf /u01/app/oracle/audit/ORCL 2>/dev/null || true

# Remove diag files
rm -rf /u01/app/oracle/diag/rdbms/orcl 2>/dev/null || true

# Remove config backup
rm -rf /u01/app/oracle/cfgtoollogs/dbca/ORCL 2>/dev/null || true

log_info "Database files removed ✓"

echo ""
log_info "Step 4: Cleaning oratab..."
if [[ -f /etc/oratab ]]; then
    # Need root for this - try sudo or skip
    if [[ $EUID -eq 0 ]]; then
        sed -i '/ORCL/d' /etc/oratab
        log_info "oratab cleaned ✓"
    else
        log_warn "Run as root to clean /etc/oratab:"
        echo "  sudo sed -i '/ORCL/d' /etc/oratab"
    fi
fi

echo ""
log_info "Step 5: Recreating directories..."
mkdir -p /u02/oradata
mkdir -p /u02/fast_recovery_area

echo ""
log_info "=============================================="
log_info "Cleanup complete!"
log_info ""
log_info "Now run: ./04-create-database.sh"
log_info "=============================================="
