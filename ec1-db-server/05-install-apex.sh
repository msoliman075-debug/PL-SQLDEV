#!/bin/bash
###############################################################################
# Script: 05-install-apex.sh
# Purpose: Install Oracle APEX 24.2 in apex_pdb
# Server: EC1 (80.238.214.217)
# Run as: oracle
###############################################################################
set -euo pipefail

echo "=============================================="
echo "Oracle APEX 24.2 Installation"
echo "=============================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ "$(whoami)" != "oracle" ]]; then
   log_error "This script must be run as oracle user"
   exit 1
fi

source ~/.bash_profile

APEX_ZIP="/home/oracle/stage/apex_24.2.zip"
APEX_DIR="/u01/app/oracle/apex"

echo ""
log_info "Step 1: Checking APEX installation file..."
if [[ ! -f "$APEX_ZIP" ]]; then
    log_error "APEX zip file not found at $APEX_ZIP"
    log_error "Please upload apex_24.2.zip to /home/oracle/stage/"
    exit 1
fi
log_info "APEX file found ✓"

echo ""
log_info "Step 2: Extracting APEX..."
mkdir -p $APEX_DIR
cd $APEX_DIR
unzip -oq "$APEX_ZIP"
log_info "APEX extracted to $APEX_DIR/apex ✓"

echo ""
log_info "Step 3: Installing APEX in apex_pdb..."
log_warn "This will take 30-60 minutes. Please be patient..."

cd $APEX_DIR/apex

sqlplus / as sysdba << 'EOSQL'
-- Switch to apex_pdb
ALTER SESSION SET CONTAINER = apex_pdb;

-- Verify container
SHOW CON_NAME

-- Run APEX installation
-- Parameters: APEX tablespace, APEX files tablespace, TEMP tablespace, Images path
@apexins.sql SYSAUX SYSAUX TEMP /i/

EXIT;
EOSQL

echo ""
log_info "Step 4: Configuring APEX Admin password..."
cd $APEX_DIR/apex

# Non-interactive admin password setup
sqlplus / as sysdba << 'EOSQL'
ALTER SESSION SET CONTAINER = apex_pdb;

BEGIN
    APEX_UTIL.SET_SECURITY_GROUP_ID( 10 );
    
    APEX_UTIL.CREATE_USER(
        p_user_name       => 'ADMIN',
        p_email_address   => 'admin@localhost',
        p_web_password    => 'Admin123!',
        p_developer_privs => 'ADMIN',
        p_change_password_on_first_use => 'N');
        
    APEX_UTIL.SET_SECURITY_GROUP_ID( null );
    COMMIT;
END;
/

EXIT;
EOSQL

log_info "APEX Admin account configured ✓"

echo ""
log_info "Step 5: Configuring APEX REST services..."
cd $APEX_DIR/apex

sqlplus / as sysdba << 'EOSQL'
ALTER SESSION SET CONTAINER = apex_pdb;

-- Create APEX REST users with passwords
@apex_rest_config_core.sql @ Listener123 RestPublic123

EXIT;
EOSQL

log_info "APEX REST configuration complete ✓"

echo ""
log_info "Step 6: Configuring APEX_PUBLIC_USER..."
sqlplus / as sysdba << 'EOSQL'
ALTER SESSION SET CONTAINER = apex_pdb;

-- Unlock and set password for APEX_PUBLIC_USER
ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK;
ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "ApexPublic123";

-- Grant connect privilege
GRANT CREATE SESSION TO APEX_PUBLIC_USER;

COMMIT;
EXIT;
EOSQL

log_info "APEX_PUBLIC_USER configured ✓"

echo ""
log_info "Step 7: Configuring Network ACL for APEX..."
sqlplus / as sysdba << 'EOSQL'
ALTER SESSION SET CONTAINER = apex_pdb;

-- Grant network privileges to APEX schema
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect'),
            principal_name => 'APEX_240200',
            principal_type => xs_acl.ptype_db));
END;
/

COMMIT;
EXIT;
EOSQL

log_info "Network ACL configured ✓"

echo ""
log_info "Step 8: Verifying APEX installation..."
sqlplus -s / as sysdba << 'EOSQL'
SET LINESIZE 120
SET PAGESIZE 50
ALTER SESSION SET CONTAINER = apex_pdb;

PROMPT
PROMPT === APEX Version ===
SELECT VERSION_NO, API_COMPATIBILITY FROM APEX_RELEASE;

PROMPT
PROMPT === APEX Users Status ===
SELECT USERNAME, ACCOUNT_STATUS 
FROM DBA_USERS 
WHERE USERNAME LIKE 'APEX%'
ORDER BY USERNAME;

PROMPT
PROMPT === APEX Workspaces ===
SELECT WORKSPACE_ID, WORKSPACE FROM APEX_WORKSPACES;

EXIT;
EOSQL

echo ""
log_info "=============================================="
log_info "APEX 24.2 Installation Complete!"
log_info "=============================================="
echo ""
log_info "APEX Credentials:"
echo "  Admin User:           ADMIN"
echo "  Admin Password:       Admin123!"
echo "  APEX_PUBLIC_USER:     ApexPublic123"
echo "  APEX_LISTENER:        Listener123"
echo "  APEX_REST_PUBLIC_USER: RestPublic123"
echo ""
log_info "Next: Run 06-create-service.sh as ROOT"
log_info "=============================================="
