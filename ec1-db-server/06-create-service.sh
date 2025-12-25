#!/bin/bash
###############################################################################
# Script: 06-create-service.sh
# Purpose: Create Oracle Database systemd service
# Server: EC1 (80.238.214.217)
# Run as: root
###############################################################################
set -euo pipefail

echo "=============================================="
echo "Oracle Database Systemd Service Setup"
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
log_info "Step 1: Updating oratab for auto-start..."
if [[ -f /etc/oratab ]]; then
    sed -i 's/:N$/:Y/' /etc/oratab
    log_info "oratab updated ✓"
    cat /etc/oratab
else
    log_warn "/etc/oratab not found, creating..."
    echo "ORCL:/u01/app/oracle/product/19.3.0/dbhome_1:Y" > /etc/oratab
fi

echo ""
log_info "Step 2: Creating systemd service file..."

cat > /etc/systemd/system/oracle-database.service << 'EOF'
[Unit]
Description=Oracle Database Service
After=network.target

[Service]
Type=forking
User=oracle
Group=oinstall

Environment="ORACLE_BASE=/u01/app/oracle"
Environment="ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1"
Environment="ORACLE_SID=ORCL"
Environment="PATH=/u01/app/oracle/product/19.3.0/dbhome_1/bin:/usr/local/bin:/bin:/usr/bin"
Environment="LD_LIBRARY_PATH=/u01/app/oracle/product/19.3.0/dbhome_1/lib"

ExecStart=/u01/app/oracle/product/19.3.0/dbhome_1/bin/dbstart /u01/app/oracle/product/19.3.0/dbhome_1
ExecStop=/u01/app/oracle/product/19.3.0/dbhome_1/bin/dbshut /u01/app/oracle/product/19.3.0/dbhome_1

TimeoutStartSec=600
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
EOF

log_info "Service file created ✓"

echo ""
log_info "Step 3: Creating listener service..."

cat > /etc/systemd/system/oracle-listener.service << 'EOF'
[Unit]
Description=Oracle Listener Service
After=network.target
Before=oracle-database.service

[Service]
Type=forking
User=oracle
Group=oinstall

Environment="ORACLE_BASE=/u01/app/oracle"
Environment="ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1"
Environment="PATH=/u01/app/oracle/product/19.3.0/dbhome_1/bin:/usr/local/bin:/bin:/usr/bin"
Environment="LD_LIBRARY_PATH=/u01/app/oracle/product/19.3.0/dbhome_1/lib"

ExecStart=/u01/app/oracle/product/19.3.0/dbhome_1/bin/lsnrctl start
ExecStop=/u01/app/oracle/product/19.3.0/dbhome_1/bin/lsnrctl stop

[Install]
WantedBy=multi-user.target
EOF

log_info "Listener service file created ✓"

echo ""
log_info "Step 4: Reloading systemd and enabling services..."
systemctl daemon-reload
systemctl enable oracle-listener.service
systemctl enable oracle-database.service
log_info "Services enabled ✓"

echo ""
log_info "Step 5: Starting services..."
# First ensure database is running before managing services
su - oracle -c "sqlplus / as sysdba <<< 'SELECT STATUS FROM V\$INSTANCE;'" || true

systemctl start oracle-listener.service
systemctl start oracle-database.service

echo ""
log_info "Step 6: Verifying services..."
systemctl status oracle-listener.service --no-pager
echo ""
systemctl status oracle-database.service --no-pager

echo ""
log_info "=============================================="
log_info "Oracle Services configured!"
log_info "=============================================="
echo ""
echo "Service Commands:"
echo "  Start:   systemctl start oracle-database"
echo "  Stop:    systemctl stop oracle-database"
echo "  Status:  systemctl status oracle-database"
echo "  Restart: systemctl restart oracle-database"
echo ""
log_info "EC1 Setup Complete! Proceed to EC2 setup."
log_info "=============================================="
