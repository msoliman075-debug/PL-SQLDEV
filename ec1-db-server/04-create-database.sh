#!/bin/bash
###############################################################################
# Script: 04-create-database.sh
# Purpose: Create CDB and PDB (apex_pdb) using DBCA
# Server: EC1 (80.238.214.217)
# Run as: oracle
###############################################################################
set -euo pipefail

echo "=============================================="
echo "Oracle Database Creation (CDB + PDB)"
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

# Database passwords - CHANGE THESE!
SYS_PASSWORD="Oracle123"
PDB_ADMIN_PASSWORD="Oracle123"

echo ""
log_info "Database Configuration:"
echo "  CDB Name:    ORCL"
echo "  PDB Name:    apex_pdb"
echo "  Data Dir:    /u02/oradata"

echo ""
log_info "Step 1: Creating listener configuration..."

cat > $ORACLE_HOME/network/admin/listener.ora << 'EOF'
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

ADR_BASE_LISTENER = /u01/app/oracle
EOF

cat > $ORACLE_HOME/network/admin/tnsnames.ora << 'EOF'
ORCL =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORCL)
    )
  )

APEX_PDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = apex_pdb)
    )
  )
EOF

log_info "Listener configuration created ✓"

echo ""
log_info "Step 2: Starting listener..."
lsnrctl start
log_info "Listener started ✓"

echo ""
log_info "Step 3: Creating database using DBCA..."
log_warn "This will take 15-30 minutes. Please wait..."

dbca -silent -createDatabase \
    -templateName General_Purpose.dbc \
    -gdbname ORCL \
    -sid ORCL \
    -responseFile NO_VALUE \
    -characterSet AL32UTF8 \
    -nationalCharacterSet AL16UTF16 \
    -sysPassword "$SYS_PASSWORD" \
    -systemPassword "$SYS_PASSWORD" \
    -createAsContainerDatabase true \
    -numberOfPDBs 1 \
    -pdbName apex_pdb \
    -pdbAdminPassword "$PDB_ADMIN_PASSWORD" \
    -databaseType MULTIPURPOSE \
    -memoryMgmtType AUTO_SGA \
    -totalMemory 2048 \
    -storageType FS \
    -datafileDestination /u02/oradata \
    -recoveryAreaDestination /u02/fast_recovery_area \
    -recoveryAreaSize 10240 \
    -emConfiguration NONE \
    -ignorePreReqs

DBCA_EXIT=$?

if [[ $DBCA_EXIT -ne 0 ]]; then
    log_error "Database creation failed with exit code: $DBCA_EXIT"
    exit 1
fi

log_info "Database created successfully ✓"

echo ""
log_info "Step 4: Configuring PDB auto-open..."

sqlplus -s / as sysdba << 'EOSQL'
SET ECHO OFF
SET FEEDBACK OFF

-- Open PDB
ALTER PLUGGABLE DATABASE apex_pdb OPEN;

-- Save state for auto-open on startup
ALTER PLUGGABLE DATABASE apex_pdb SAVE STATE;

-- Create trigger to auto-open all PDBs
CREATE OR REPLACE TRIGGER open_pdbs
  AFTER STARTUP ON DATABASE
BEGIN
   EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ALL OPEN';
END open_pdbs;
/

EXIT;
EOSQL

log_info "PDB auto-open configured ✓"

echo ""
log_info "Step 5: Verifying database..."

sqlplus -s / as sysdba << 'EOSQL'
SET LINESIZE 100
SET PAGESIZE 50

PROMPT
PROMPT === CDB Information ===
SELECT NAME, OPEN_MODE, CDB FROM V$DATABASE;

PROMPT
PROMPT === PDB Information ===
SHOW PDBS

PROMPT
PROMPT === Listener Services ===
EXIT;
EOSQL

lsnrctl status

echo ""
log_info "=============================================="
log_info "Database creation complete!"
log_info ""
log_info "CDB: ORCL"
log_info "PDB: apex_pdb"
log_info "SYS Password: $SYS_PASSWORD"
log_info ""
log_info "Next: Run 05-install-apex.sh"
log_info "=============================================="
