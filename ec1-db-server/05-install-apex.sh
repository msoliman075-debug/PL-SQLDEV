#!/bin/bash
###############################################################################
# Script: 05-install-apex.sh
# Purpose: Install Oracle APEX 24.2 in apex_pdb with dedicated tablespace
# Server: EC1 (80.238.214.217)
# Run as: oracle
###############################################################################
set -eo pipefail

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

# Configuration
APEX_ZIP="/home/oracle/stage/apex_24.2.zip"
APEX_DIR="/u01/app/oracle/apex"
APEX_TABLESPACE="APEX_TS"
APEX_DATAFILE="/u02/oradata/ORCL/apex_pdb/apex_ts01.dbf"

# Passwords - CHANGE THESE!
APEX_ADMIN_PASSWORD="Admin123!"
APEX_PUBLIC_USER_PWD="ApexPublic123"
APEX_LISTENER_PWD="Listener123"
APEX_REST_PUBLIC_PWD="RestPublic123"

echo ""
log_info "Configuration:"
echo "  PDB Name:          apex_pdb"
echo "  APEX Tablespace:   $APEX_TABLESPACE"
echo "  APEX Datafile:     $APEX_DATAFILE"
echo ""

# Step 1: Check APEX zip file
log_info "Step 1: Checking APEX installation file..."
if [[ ! -f "$APEX_ZIP" ]]; then
    log_error "APEX zip file not found at $APEX_ZIP"
    log_error "Please upload apex_24.2.zip to /home/oracle/stage/"
    exit 1
fi
log_info "APEX file found ✓"

# Step 2: Extract APEX
echo ""
log_info "Step 2: Extracting APEX..."
mkdir -p $APEX_DIR
cd $APEX_DIR

if [[ -d "$APEX_DIR/apex" ]]; then
    log_info "APEX already extracted, skipping..."
else
    unzip -oq "$APEX_ZIP"
    log_info "APEX extracted to $APEX_DIR/apex ✓"
fi

# Step 3: Create APEX tablespace
echo ""
log_info "Step 3: Creating APEX tablespace in apex_pdb..."

sqlplus -s / as sysdba << EOSQL
SET ECHO OFF
SET FEEDBACK ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

-- Switch to apex_pdb
ALTER SESSION SET CONTAINER = apex_pdb;

-- Verify container
SHOW CON_NAME

-- Create directory for datafile if needed
-- Check if tablespace exists
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM DBA_TABLESPACES WHERE TABLESPACE_NAME = '$APEX_TABLESPACE';
    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE TABLESPACE $APEX_TABLESPACE 
            DATAFILE ''$APEX_DATAFILE'' 
            SIZE 500M 
            AUTOEXTEND ON 
            NEXT 100M 
            MAXSIZE UNLIMITED
            EXTENT MANAGEMENT LOCAL
            SEGMENT SPACE MANAGEMENT AUTO';
        DBMS_OUTPUT.PUT_LINE('Tablespace $APEX_TABLESPACE created successfully');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Tablespace $APEX_TABLESPACE already exists');
    END IF;
END;
/

-- Verify tablespace
SELECT TABLESPACE_NAME, STATUS, CONTENTS FROM DBA_TABLESPACES WHERE TABLESPACE_NAME = '$APEX_TABLESPACE';

EXIT;
EOSQL

if [[ $? -ne 0 ]]; then
    log_error "Failed to create tablespace"
    exit 1
fi
log_info "APEX tablespace created ✓"

# Step 4: Install APEX
echo ""
log_info "Step 4: Installing APEX in apex_pdb..."
log_warn "This will take 30-60 minutes. Please be patient..."
log_info "You can monitor progress in another terminal:"
echo "  tail -f $APEX_DIR/apex/apexins*.log"
echo ""

cd $APEX_DIR/apex

sqlplus -s / as sysdba << EOSQL
SET ECHO OFF
WHENEVER SQLERROR CONTINUE

-- Switch to apex_pdb
ALTER SESSION SET CONTAINER = apex_pdb;

-- Verify container
SHOW CON_NAME

-- Run APEX installation
-- Parameters: APEX tablespace, APEX files tablespace, TEMP tablespace, Images virtual path
@apexins.sql $APEX_TABLESPACE $APEX_TABLESPACE TEMP /i/

EXIT;
EOSQL

log_info "APEX core installation complete ✓"

# Step 5: Verify APEX installation
echo ""
log_info "Step 5: Verifying APEX installation..."

sqlplus -s / as sysdba << 'EOSQL'
SET LINESIZE 120
SET PAGESIZE 50
ALTER SESSION SET CONTAINER = apex_pdb;

PROMPT
PROMPT === APEX Version ===
SELECT VERSION_NO, API_COMPATIBILITY, PATCH_APPLIED FROM APEX_RELEASE;

EXIT;
EOSQL

# Step 6: Create APEX Instance Admin
echo ""
log_info "Step 6: Creating APEX Instance Administrator..."

cd $APEX_DIR/apex

sqlplus -s / as sysdba << EOSQL
SET ECHO OFF
SET SERVEROUTPUT ON
ALTER SESSION SET CONTAINER = apex_pdb;

BEGIN
    APEX_UTIL.SET_SECURITY_GROUP_ID(10);
    
    APEX_UTIL.CREATE_USER(
        p_user_name       => 'ADMIN',
        p_email_address   => 'admin@localhost',
        p_web_password    => '$APEX_ADMIN_PASSWORD',
        p_developer_privs => 'ADMIN',
        p_change_password_on_first_use => 'N'
    );
    
    APEX_UTIL.SET_SECURITY_GROUP_ID(NULL);
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('APEX ADMIN user created successfully');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20001 THEN
            DBMS_OUTPUT.PUT_LINE('APEX ADMIN user already exists');
        ELSE
            RAISE;
        END IF;
END;
/

EXIT;
EOSQL

log_info "APEX Admin account configured ✓"

# Step 7: Configure APEX REST services
echo ""
log_info "Step 7: Configuring APEX REST services..."

cd $APEX_DIR/apex

sqlplus -s / as sysdba << EOSQL
SET ECHO OFF
ALTER SESSION SET CONTAINER = apex_pdb;

@apex_rest_config_core.sql @ $APEX_LISTENER_PWD $APEX_REST_PUBLIC_PWD

EXIT;
EOSQL

log_info "APEX REST services configured ✓"

# Step 8: Configure APEX_PUBLIC_USER
echo ""
log_info "Step 8: Configuring APEX_PUBLIC_USER..."

sqlplus -s / as sysdba << EOSQL
SET ECHO OFF
ALTER SESSION SET CONTAINER = apex_pdb;

-- Unlock and set password for APEX_PUBLIC_USER
ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK;
ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "$APEX_PUBLIC_USER_PWD";

-- Grant necessary privileges
GRANT CREATE SESSION TO APEX_PUBLIC_USER;

COMMIT;

PROMPT APEX_PUBLIC_USER configured successfully

EXIT;
EOSQL

log_info "APEX_PUBLIC_USER configured ✓"

# Step 9: Configure Network ACL
echo ""
log_info "Step 9: Configuring Network ACL for APEX..."

sqlplus -s / as sysdba << 'EOSQL'
SET ECHO OFF
SET SERVEROUTPUT ON
ALTER SESSION SET CONTAINER = apex_pdb;

-- Get APEX schema name
DECLARE
    v_apex_schema VARCHAR2(30);
BEGIN
    SELECT SCHEMA INTO v_apex_schema FROM DBA_REGISTRY WHERE COMP_ID = 'APEX';
    
    -- Grant network privileges to APEX schema
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => v_apex_schema,
            principal_type => xs_acl.ptype_db
        )
    );
    
    DBMS_OUTPUT.PUT_LINE('Network ACL configured for ' || v_apex_schema);
    COMMIT;
END;
/

EXIT;
EOSQL

log_info "Network ACL configured ✓"

# Step 10: Final verification
echo ""
log_info "Step 10: Final verification..."

sqlplus -s / as sysdba << 'EOSQL'
SET LINESIZE 150
SET PAGESIZE 100
ALTER SESSION SET CONTAINER = apex_pdb;

PROMPT
PROMPT === APEX Version ===
SELECT VERSION_NO, API_COMPATIBILITY FROM APEX_RELEASE;

PROMPT
PROMPT === APEX Tablespace Usage ===
SELECT TABLESPACE_NAME, 
       ROUND(SUM(BYTES)/1024/1024) AS SIZE_MB,
       ROUND(SUM(BYTES)/1024/1024 - SUM(DECODE(STATUS,'FREE',BYTES,0))/1024/1024) AS USED_MB
FROM DBA_DATA_FILES 
WHERE TABLESPACE_NAME = 'APEX_TS'
GROUP BY TABLESPACE_NAME;

PROMPT
PROMPT === APEX Users Status ===
SELECT USERNAME, ACCOUNT_STATUS, DEFAULT_TABLESPACE 
FROM DBA_USERS 
WHERE USERNAME LIKE 'APEX%' OR USERNAME LIKE 'FLOWS_%'
ORDER BY USERNAME;

PROMPT
PROMPT === APEX Workspaces ===
SELECT WORKSPACE_ID, WORKSPACE, PRIMARY_SCHEMA FROM APEX_WORKSPACES;

EXIT;
EOSQL

echo ""
log_info "=============================================="
log_info "APEX 24.2 Installation Complete!"
log_info "=============================================="
echo ""
echo "APEX Credentials:"
echo "  ─────────────────────────────────────────"
echo "  Admin User:              ADMIN"
echo "  Admin Password:          $APEX_ADMIN_PASSWORD"
echo "  ─────────────────────────────────────────"
echo "  APEX_PUBLIC_USER:        $APEX_PUBLIC_USER_PWD"
echo "  APEX_LISTENER:           $APEX_LISTENER_PWD"
echo "  APEX_REST_PUBLIC_USER:   $APEX_REST_PUBLIC_PWD"
echo "  ─────────────────────────────────────────"
echo ""
echo "APEX Tablespace: $APEX_TABLESPACE"
echo ""
log_info "Next steps:"
echo "  1. Run ./06-create-service.sh as ROOT to create systemd service"
echo "  2. Proceed to EC2 for ORDS installation"
echo ""
log_info "=============================================="
