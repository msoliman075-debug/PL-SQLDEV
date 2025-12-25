#!/bin/bash
###############################################################################
# Script: 03-install-oracle.sh
# Purpose: Install Oracle Database 19c Software
# Server: EC1 (80.238.214.217)
# Run as: oracle
###############################################################################
set -eo pipefail

echo "=============================================="
echo "Oracle Database 19c Software Installation"
echo "=============================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as oracle
if [[ "$(whoami)" != "oracle" ]]; then
   log_error "This script must be run as oracle user"
   log_info "Switch to oracle: su - oracle"
   exit 1
fi

# Source environment
source ~/.bash_profile

echo ""
log_info "Environment variables:"
echo "  ORACLE_BASE: $ORACLE_BASE"
echo "  ORACLE_HOME: $ORACLE_HOME"
echo "  ORACLE_SID:  $ORACLE_SID"

echo ""
log_info "Step 1: Checking installation files..."
if [[ ! -f "/home/oracle/stage/LINUX.X64_193000_db_home.zip" ]]; then
    log_error "Oracle installation file not found!"
    log_error "Please upload LINUX.X64_193000_db_home.zip to /home/oracle/stage/"
    exit 1
fi
log_info "Installation file found ✓"

echo ""
log_info "Step 2: Extracting Oracle software to ORACLE_HOME..."
cd $ORACLE_HOME
unzip -oq /home/oracle/stage/LINUX.X64_193000_db_home.zip
log_info "Extraction complete ✓"

echo ""
log_info "Step 3: Creating response file..."
cat > /home/oracle/stage/db_install.rsp << 'EOF'
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/u01/app/oraInventory
ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1
ORACLE_BASE=/u01/app/oracle
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.rootconfig.executeRootScript=false
EOF
log_info "Response file created ✓"

echo ""
log_info "Step 4: Running Oracle Installer (silent mode)..."
log_warn "This may take 10-15 minutes..."

# Set CV_ASSUME_DISTID to bypass Oracle Linux 8 detection issue
export CV_ASSUME_DISTID=OEL7.8

cd $ORACLE_HOME
./runInstaller -silent -responseFile /home/oracle/stage/db_install.rsp \
    -ignorePrereqFailure -waitforcompletion

INSTALLER_EXIT=$?

echo ""
if [[ $INSTALLER_EXIT -eq 0 ]] || [[ $INSTALLER_EXIT -eq 6 ]]; then
    log_info "Oracle software installation complete ✓"
    echo ""
    log_warn "=============================================="
    log_warn "IMPORTANT: Run the following as ROOT:"
    log_warn "=============================================="
    echo ""
    echo "  sudo /u01/app/oraInventory/orainstRoot.sh"
    echo "  sudo /u01/app/oracle/product/19.3.0/dbhome_1/root.sh"
    echo ""
    log_info "After running root scripts, execute: 04-create-database.sh"
else
    log_error "Installation failed with exit code: $INSTALLER_EXIT"
    log_error "Check log files in: $ORACLE_BASE/oraInventory/logs/"
    exit 1
fi
