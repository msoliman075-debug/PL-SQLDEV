#!/bin/bash
###############################################################################
# Script: verify-remote-access.sh
# Purpose: Verify Oracle Database is accessible remotely
# Server: EC1 (80.238.214.217)
# Run as: oracle or root
###############################################################################
set -euo pipefail

echo "=============================================="
echo "Remote Access Verification"
echo "=============================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

echo "=== 1. Checking Oracle Listener Status ==="
if pgrep -x tnslsnr > /dev/null; then
    log_pass "Oracle Listener is running"
else
    log_fail "Oracle Listener is NOT running"
    echo "  Fix: su - oracle -c 'lsnrctl start'"
fi
echo ""

echo "=== 2. Checking Listener Port (1521) ==="
if ss -tlnp | grep -q ":1521"; then
    log_pass "Port 1521 is listening"
    ss -tlnp | grep ":1521"
else
    log_fail "Port 1521 is NOT listening"
fi
echo ""

echo "=== 3. Checking Firewall Status ==="
if systemctl is-active --quiet firewalld; then
    log_info "Firewalld is running"
    
    if firewall-cmd --list-ports | grep -q "1521/tcp"; then
        log_pass "Port 1521/tcp is open in firewall"
    else
        log_fail "Port 1521/tcp is NOT open in firewall"
        echo "  Fix: firewall-cmd --permanent --add-port=1521/tcp && firewall-cmd --reload"
    fi
else
    log_warn "Firewalld is not running (all ports may be open)"
fi
echo ""

echo "=== 4. Checking SELinux Status ==="
SELINUX_STATUS=$(getenforce 2>/dev/null || echo "Unknown")
if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
    log_warn "SELinux is Enforcing - may block Oracle"
    echo "  Fix: setenforce 0"
else
    log_pass "SELinux is $SELINUX_STATUS"
fi
echo ""

echo "=== 5. Checking Database Instance ==="
if pgrep -f "ora_pmon_ORCL" > /dev/null; then
    log_pass "Oracle Database instance ORCL is running"
else
    log_fail "Oracle Database instance is NOT running"
    echo "  Fix: su - oracle -c 'sqlplus / as sysdba <<< \"STARTUP;\"'"
fi
echo ""

echo "=== 6. Checking Listener Services ==="
if command -v lsnrctl &> /dev/null; then
    echo "Registered Services:"
    su - oracle -c "lsnrctl status 2>/dev/null | grep -E 'Service|Instance'" || echo "  Unable to query listener"
else
    log_warn "lsnrctl not in PATH"
fi
echo ""

echo "=== 7. Checking PDB Status ==="
if [[ "$(whoami)" == "oracle" ]] || [[ $EUID -eq 0 ]]; then
    su - oracle -c "sqlplus -s / as sysdba << 'EOF'
SET PAGESIZE 50
SET LINESIZE 100
SELECT NAME, OPEN_MODE FROM V\$PDBS;
EXIT;
EOF" 2>/dev/null || echo "  Unable to query PDB status"
fi
echo ""

echo "=== 8. Network Interface Check ==="
echo "Server IP addresses:"
hostname -I
echo ""

echo "=== 9. Listener Configuration ==="
LISTENER_ORA="/u01/app/oracle/product/19.3.0/dbhome_1/network/admin/listener.ora"
if [[ -f "$LISTENER_ORA" ]]; then
    echo "Listener listening on:"
    grep -E "HOST|PORT" "$LISTENER_ORA" | head -5
else
    log_warn "listener.ora not found"
fi
echo ""

echo "=============================================="
echo "Connection Test Commands (run from remote):"
echo "=============================================="
echo ""
echo "From EC2 (80.238.234.247):"
echo "  nc -zv 80.238.214.217 1521"
echo ""
echo "From local machine with SQL*Plus:"
echo "  sqlplus sys/Oracle123@80.238.214.217:1521/apex_pdb as sysdba"
echo ""
echo "From local machine with tnsping:"
echo "  tnsping 80.238.214.217:1521/apex_pdb"
echo ""
