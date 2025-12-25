#!/bin/bash
###############################################################################
# Script: configure-firewall.sh
# Purpose: Configure Oracle Linux 8 firewall for remote database access
# Server: EC1 (80.238.214.217)
# Run as: root
#
# Allows connections from:
#   - EC2 App Server (80.238.234.247)
#   - Your local machine (any IP)
###############################################################################
set -euo pipefail

echo "=============================================="
echo "Oracle Linux 8 Firewall Configuration"
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

# EC2 App Server IP
EC2_IP="80.238.234.247"

echo ""
log_info "Step 1: Ensuring firewalld is running..."
systemctl start firewalld
systemctl enable firewalld
log_info "Firewalld is active ✓"

echo ""
log_info "Step 2: Getting current firewall status..."
firewall-cmd --state
echo ""

echo ""
log_info "Step 3: Opening Oracle Database ports..."

# Oracle Listener port - allow from anywhere for remote access
firewall-cmd --permanent --add-port=1521/tcp
log_info "Port 1521/tcp (Oracle Listener) opened ✓"

# Enterprise Manager Express
firewall-cmd --permanent --add-port=5500/tcp
log_info "Port 5500/tcp (EM Express) opened ✓"

# Additional EM port
firewall-cmd --permanent --add-port=5501/tcp
log_info "Port 5501/tcp opened ✓"

echo ""
log_info "Step 4: Adding Oracle service (if available)..."
firewall-cmd --permanent --add-service=oracle 2>/dev/null || log_warn "Oracle service not predefined, using ports instead"

echo ""
log_info "Step 5: Reloading firewall..."
firewall-cmd --reload
log_info "Firewall reloaded ✓"

echo ""
log_info "Step 6: Verifying configuration..."
echo ""
echo "=== Active Zones ==="
firewall-cmd --get-active-zones
echo ""
echo "=== Open Ports ==="
firewall-cmd --list-ports
echo ""
echo "=== Open Services ==="
firewall-cmd --list-services
echo ""
echo "=== Rich Rules ==="
firewall-cmd --list-rich-rules 2>/dev/null || echo "No rich rules configured"

echo ""
log_info "Step 7: Testing port availability..."
if ss -tlnp | grep -q ":1521"; then
    log_info "Port 1521 is listening ✓"
else
    log_warn "Port 1521 is not listening (Oracle may not be running)"
fi

echo ""
log_info "=============================================="
log_info "Firewall Configuration Complete!"
log_info "=============================================="
echo ""
echo "Remote Connection Details:"
echo "  Host: 80.238.214.217"
echo "  Port: 1521"
echo "  Service Name (CDB): ORCL"
echo "  Service Name (PDB): apex_pdb"
echo ""
echo "Connection String Examples:"
echo ""
echo "  SQL*Plus from local machine:"
echo "    sqlplus sys/Oracle123@80.238.214.217:1521/apex_pdb as sysdba"
echo ""
echo "  SQL Developer / DBeaver:"
echo "    Host: 80.238.214.217"
echo "    Port: 1521"
echo "    Service: apex_pdb"
echo "    User: SYS (as SYSDBA) or SYSTEM"
echo ""
echo "  JDBC URL:"
echo "    jdbc:oracle:thin:@80.238.214.217:1521/apex_pdb"
echo ""
echo "  TNS Entry (add to tnsnames.ora on client):"
cat << 'EOF'
    APEX_PDB_REMOTE =
      (DESCRIPTION =
        (ADDRESS = (PROTOCOL = TCP)(HOST = 80.238.214.217)(PORT = 1521))
        (CONNECT_DATA =
          (SERVER = DEDICATED)
          (SERVICE_NAME = apex_pdb)
        )
      )
EOF
echo ""
log_info "=============================================="
