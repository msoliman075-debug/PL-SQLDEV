# Oracle Database 19c, APEX 24.2 & ORDS 24.3 Setup Guide

## Environment Overview

| Server | IP | OS | Components |
|--------|----|----|------------|
| EC1 (DB Server) | 80.238.214.217 | Oracle Linux 8 | Oracle DB 19c, APEX 24.2 |
| EC2 (App Server) | 80.238.234.247 | Ubuntu 24.04 | JDK 17, Tomcat 9, ORDS 24.3 |

---

# PART 1: EC1 - DATABASE SERVER SETUP

## Section 1.1: Uninstall Existing Oracle Database 19c

### [root] Stop and Remove Oracle Services

```bash
# Login as root
sudo su -

# Stop Oracle listener and database (if running)
su - oracle -c "lsnrctl stop" 2>/dev/null || true
su - oracle -c "sqlplus / as sysdba <<EOF
SHUTDOWN IMMEDIATE;
EXIT;
EOF" 2>/dev/null || true

# Stop and disable Oracle services
systemctl stop oracle-database* 2>/dev/null || true
systemctl disable oracle-database* 2>/dev/null || true
```

### [root] Remove Oracle RPM Packages

```bash
# List installed Oracle packages
rpm -qa | grep -i oracle

# Remove Oracle Database RPM (if installed via RPM)
dnf remove -y oracle-database-* 2>/dev/null || true
dnf remove -y oracle-database-preinstall-19c 2>/dev/null || true
```

### [root] Remove Oracle Directories

```bash
# Remove Oracle base directories
rm -rf /opt/oracle
rm -rf /u01/app/oracle
rm -rf /u01/app/oraInventory
rm -rf /u02

# Remove Oracle network config
rm -rf /etc/oratab
rm -f /etc/init.d/dbora
rm -f /etc/systemd/system/oracle*

# Remove Oracle user environment files
rm -f /home/oracle/.bash_profile.bak 2>/dev/null || true
```

### [root] Remove Oracle User and Groups (Optional - for full reset)

```bash
# Only run if you want to recreate oracle user
userdel -r oracle 2>/dev/null || true
groupdel oinstall 2>/dev/null || true
groupdel dba 2>/dev/null || true
groupdel oper 2>/dev/null || true
groupdel backupdba 2>/dev/null || true
groupdel dgdba 2>/dev/null || true
groupdel kmdba 2>/dev/null || true
groupdel racdba 2>/dev/null || true
```

### [root] Verify Cleanup

```bash
# Verify Oracle directories removed
ls -la /opt/oracle 2>/dev/null && echo "WARNING: /opt/oracle still exists" || echo "OK: /opt/oracle removed"
ls -la /u01 2>/dev/null && echo "WARNING: /u01 still exists" || echo "OK: /u01 removed"

# Verify no Oracle processes running
ps -ef | grep -i ora_ | grep -v grep && echo "WARNING: Oracle processes still running" || echo "OK: No Oracle processes"

# Verify no Oracle listener
ps -ef | grep -i tnslsnr | grep -v grep && echo "WARNING: Listener still running" || echo "OK: No listener"
```

---

## Section 1.2: Oracle Database 19c Prerequisites

### [root] Install Required Packages

```bash
# Install Oracle preinstall package (sets up groups, user, kernel params)
dnf install -y oracle-database-preinstall-19c

# Install additional required packages
dnf install -y bc binutils compat-openssl10 elfutils-libelf \
    elfutils-libelf-devel fontconfig-devel glibc glibc-devel \
    ksh libaio libaio-devel libX11 libXau libXi libXtst \
    libXrender libXrender-devel libgcc libstdc++ libstdc++-devel \
    libxcb make smartmontools sysstat unzip wget

# Install additional utilities
dnf install -y net-tools vim tar
```

### [root] Verify Oracle User and Groups Created

```bash
# Verify oracle user exists
id oracle

# Expected output should show groups: oinstall, dba, oper, backupdba, dgdba, kmdba, racdba
```

### [root] Create Oracle Directories

```bash
# Create Oracle base and Oracle home directories
mkdir -p /u01/app/oracle/product/19.3.0/dbhome_1
mkdir -p /u01/app/oraInventory
mkdir -p /u02/oradata

# Set ownership
chown -R oracle:oinstall /u01
chown -R oracle:oinstall /u02

# Set permissions
chmod -R 775 /u01
chmod -R 775 /u02
```

### [root] Configure Kernel Parameters

```bash
# The preinstall package should set these, but verify/add if needed
cat >> /etc/sysctl.d/97-oracle-database-sysctl.conf << 'EOF'
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
kernel.panic_on_oops = 1
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
fs.aio-max-nr = 1048576
net.ipv4.ip_local_port_range = 9000 65500
EOF

# Apply kernel parameters
sysctl -p /etc/sysctl.d/97-oracle-database-sysctl.conf
```

### [root] Configure User Limits

```bash
# The preinstall package should set these, but verify/add if needed
cat >> /etc/security/limits.d/oracle-database-preinstall-19c.conf << 'EOF'
oracle   soft   nofile    1024
oracle   hard   nofile    65536
oracle   soft   nproc    16384
oracle   hard   nproc    16384
oracle   soft   stack    10240
oracle   hard   stack    32768
oracle   soft   memlock    134217728
oracle   hard   memlock    134217728
EOF
```

### [root] Set Oracle User Password

```bash
# Set password for oracle user
echo "oracle:YourSecurePassword123" | chpasswd

# Or interactively
# passwd oracle
```

### [root] Configure Oracle Environment Variables

```bash
# Create oracle user profile
cat > /home/oracle/.bash_profile << 'EOF'
# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# Oracle Settings
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.3.0/dbhome_1
export ORACLE_SID=ORCL
export ORACLE_UNQNAME=ORCL
export PDB_NAME=apex_pdb
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib

# Prompt
export PS1='[\u@\h \W]\$ '

umask 022
EOF

chown oracle:oinstall /home/oracle/.bash_profile
```

### [root] Configure Firewall

```bash
# Open Oracle ports
firewall-cmd --permanent --add-port=1521/tcp    # Oracle Listener
firewall-cmd --permanent --add-port=5500/tcp    # Enterprise Manager Express
firewall-cmd --permanent --add-port=5501/tcp    # Additional EM port

# Reload firewall
firewall-cmd --reload

# Verify
firewall-cmd --list-ports
```

### [root] Disable SELinux (or configure properly)

```bash
# Check current SELinux status
getenforce

# Set to permissive (recommended for Oracle)
setenforce 0

# Make permanent
sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config

# Verify
cat /etc/selinux/config | grep SELINUX=
```

### [root] Verify Prerequisites

```bash
# Verify all prerequisites
echo "=== Checking Prerequisites ==="

# Check memory (minimum 2GB, recommended 8GB+)
free -h
echo ""

# Check disk space (minimum 12GB for Oracle Home)
df -h /u01 /u02
echo ""

# Check swap (should be equal to or greater than RAM for systems with < 16GB RAM)
free -h | grep Swap
echo ""

# Check kernel parameters
sysctl -a | grep -E 'kernel.sem|kernel.shm|fs.file-max|fs.aio-max-nr' 2>/dev/null
echo ""

# Check oracle user limits
su - oracle -c "ulimit -a"
```

---

## Section 1.3: Oracle Database 19c Installation

### [root] Prepare Installation Files

```bash
# Create staging directory for installation files
mkdir -p /home/oracle/stage
chown oracle:oinstall /home/oracle/stage

# After uploading via WinSCP, verify files exist
ls -la /home/oracle/stage/

# Expected files:
# - LINUX.X64_193000_db_home.zip (Oracle Database 19c)
# - apex_24.2.zip (Oracle APEX 24.2)
```

### [oracle] Extract Oracle Database Software

```bash
# Switch to oracle user
su - oracle

# Verify environment
echo $ORACLE_HOME
echo $ORACLE_BASE

# Extract Oracle software directly to ORACLE_HOME
cd $ORACLE_HOME
unzip -q /home/oracle/stage/LINUX.X64_193000_db_home.zip

# Verify extraction
ls -la $ORACLE_HOME/runInstaller
```

### [oracle] Run Oracle Installer (Silent Mode)

```bash
# Create response file for silent installation
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
oracle.install.db.ConfigureAsContainerDB=false
oracle.install.db.config.starterdb.type=GENERAL_PURPOSE
EOF

# Run installer in silent mode
cd $ORACLE_HOME
./runInstaller -silent -responseFile /home/oracle/stage/db_install.rsp \
    -ignorePrereqFailure
```

### [root] Execute Root Scripts

```bash
# After installer completes, run as root:
/u01/app/oraInventory/orainstRoot.sh
/u01/app/oracle/product/19.3.0/dbhome_1/root.sh
```

### [oracle] Verify Installation

```bash
# Switch to oracle user
su - oracle

# Check Oracle version
sqlplus -version

# Expected output: SQL*Plus: Release 19.0.0.0.0
```

---

## Section 1.4: Create CDB and PDB Database

### [oracle] Create Listener Configuration

```bash
# Switch to oracle user (if not already)
su - oracle

# Create listener.ora
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

# Create tnsnames.ora
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

# Start listener
lsnrctl start

# Verify listener status
lsnrctl status
```

### [oracle] Create Database Using DBCA (Silent Mode)

```bash
# Create CDB with PDB using DBCA
dbca -silent -createDatabase \
    -templateName General_Purpose.dbc \
    -gdbname ORCL \
    -sid ORCL \
    -responseFile NO_VALUE \
    -characterSet AL32UTF8 \
    -nationalCharacterSet AL16UTF16 \
    -sysPassword Oracle123 \
    -systemPassword Oracle123 \
    -createAsContainerDatabase true \
    -numberOfPDBs 1 \
    -pdbName apex_pdb \
    -pdbAdminPassword Oracle123 \
    -databaseType MULTIPURPOSE \
    -memoryMgmtType AUTO_SGA \
    -totalMemory 2048 \
    -storageType FS \
    -datafileDestination /u02/oradata \
    -recoveryAreaDestination /u02/fast_recovery_area \
    -recoveryAreaSize 10240 \
    -emConfiguration NONE \
    -ignorePreReqs

# This process takes 15-30 minutes
```

### [oracle] Verify Database Creation

```bash
# Connect to database
sqlplus / as sysdba

-- Check CDB
SELECT NAME, OPEN_MODE, CDB FROM V$DATABASE;

-- Check PDBs
SELECT PDB_NAME, STATUS FROM DBA_PDBS;

-- Show all PDBs
SHOW PDBS;

-- Open PDB
ALTER PLUGGABLE DATABASE apex_pdb OPEN;

-- Save state so PDB opens automatically
ALTER PLUGGABLE DATABASE apex_pdb SAVE STATE;

-- Verify PDB is open
SHOW PDBS;

EXIT;
```

### [oracle] Configure PDB Auto-Open on Startup

```bash
sqlplus / as sysdba << 'EOF'
-- Create trigger to auto-open PDBs
CREATE OR REPLACE TRIGGER open_pdbs
  AFTER STARTUP ON DATABASE
BEGIN
   EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ALL OPEN';
END open_pdbs;
/
EXIT;
EOF
```

### [oracle] Verify Listener Registration

```bash
# Check listener services
lsnrctl status

# Should show services for ORCL (CDB) and apex_pdb (PDB)
```

---

## Section 1.5: Install Oracle APEX 24.2

### [oracle] Extract APEX Installation Files

```bash
# Switch to oracle user
su - oracle

# Create APEX directory
mkdir -p /u01/app/oracle/apex
cd /u01/app/oracle/apex

# Extract APEX
unzip -q /home/oracle/stage/apex_24.2.zip

# Verify extraction
ls -la /u01/app/oracle/apex/apex/
```

### [oracle] Install APEX in PDB

```bash
# Connect to CDB first, then switch to PDB
cd /u01/app/oracle/apex/apex

sqlplus / as sysdba << 'EOF'
-- Switch to apex_pdb
ALTER SESSION SET CONTAINER = apex_pdb;

-- Verify we are in apex_pdb
SHOW CON_NAME;

-- Set APEX tablespace (will be created by installer)
-- Run APEX full installation
@apexins.sql SYSAUX SYSAUX TEMP /i/

-- This takes 30-60 minutes
EOF
```

### [oracle] Configure APEX Admin Account

```bash
cd /u01/app/oracle/apex/apex

sqlplus / as sysdba << 'EOF'
ALTER SESSION SET CONTAINER = apex_pdb;

-- Set APEX admin password
@apxchpwd.sql

-- When prompted:
-- Enter new admin username: ADMIN
-- Enter new admin email: admin@localhost
-- Enter new admin password: Admin123!
EOF
```

### [oracle] Configure APEX REST Configuration

```bash
cd /u01/app/oracle/apex/apex

sqlplus / as sysdba << 'EOF'
ALTER SESSION SET CONTAINER = apex_pdb;

-- Configure RESTful Services
@apex_rest_config.sql

-- When prompted for passwords:
-- APEX_LISTENER password: Listener123
-- APEX_REST_PUBLIC_USER password: RestPublic123
EOF
```

### [oracle] Create APEX Network ACL (Required for external access)

```bash
sqlplus / as sysdba << 'EOF'
ALTER SESSION SET CONTAINER = apex_pdb;

-- Grant network privileges to APEX_240200
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace => xs$ace_type(privilege_list => xs$name_list('connect'),
                          principal_name => 'APEX_240200',
                          principal_type => xs_acl.ptype_db));
END;
/

COMMIT;
EXIT;
EOF
```

### [oracle] Unlock and Configure APEX Database Users

```bash
sqlplus / as sysdba << 'EOF'
ALTER SESSION SET CONTAINER = apex_pdb;

-- Unlock APEX users
ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK;
ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "ApexPublic123";

-- Verify APEX installation
SELECT VERSION_NO, API_COMPATIBILITY, PATCH_APPLIED FROM APEX_RELEASE;

-- Check APEX users
SELECT USERNAME, ACCOUNT_STATUS FROM DBA_USERS WHERE USERNAME LIKE 'APEX%';

EXIT;
EOF
```

### [oracle] Verify APEX Installation

```bash
sqlplus / as sysdba << 'EOF'
ALTER SESSION SET CONTAINER = apex_pdb;

-- Check APEX version
SELECT VERSION_NO FROM APEX_RELEASE;

-- Check APEX workspaces
SELECT WORKSPACE_ID, WORKSPACE FROM APEX_WORKSPACES;

-- Verify APEX is fully installed
SELECT COMP_NAME, VERSION, STATUS FROM DBA_REGISTRY WHERE COMP_NAME LIKE '%APEX%';

EXIT;
EOF
```

---

## Section 1.6: Create Oracle Systemd Service

### [root] Create Oracle Database Service

```bash
# Create systemd service file
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

ExecStart=/u01/app/oracle/product/19.3.0/dbhome_1/bin/dbstart /u01/app/oracle/product/19.3.0/dbhome_1
ExecStop=/u01/app/oracle/product/19.3.0/dbhome_1/bin/dbshut /u01/app/oracle/product/19.3.0/dbhome_1

[Install]
WantedBy=multi-user.target
EOF

# Update oratab for auto-start
sed -i 's/:N$/:Y/' /etc/oratab

# Enable and start service
systemctl daemon-reload
systemctl enable oracle-database.service
systemctl start oracle-database.service

# Check status
systemctl status oracle-database.service
```

---

## Section 1.7: EC1 Reset Commands (If Installation Fails)

### [root] Full Reset Script

```bash
#!/bin/bash
# Save as /root/reset_oracle.sh
set -euo pipefail

echo "=== Stopping Oracle Services ==="
systemctl stop oracle-database.service 2>/dev/null || true
su - oracle -c "lsnrctl stop" 2>/dev/null || true
su - oracle -c "sqlplus / as sysdba <<< 'SHUTDOWN ABORT;'" 2>/dev/null || true

echo "=== Killing Oracle Processes ==="
pkill -9 -u oracle 2>/dev/null || true

echo "=== Removing Oracle Directories ==="
rm -rf /u01/app/oracle
rm -rf /u01/app/oraInventory
rm -rf /u02/oradata
rm -rf /u02/fast_recovery_area

echo "=== Removing Service Files ==="
systemctl disable oracle-database.service 2>/dev/null || true
rm -f /etc/systemd/system/oracle-database.service
systemctl daemon-reload

echo "=== Removing Network Config ==="
rm -f /etc/oratab

echo "=== Recreating Directories ==="
mkdir -p /u01/app/oracle/product/19.3.0/dbhome_1
mkdir -p /u01/app/oraInventory
mkdir -p /u02/oradata
chown -R oracle:oinstall /u01
chown -R oracle:oinstall /u02
chmod -R 775 /u01
chmod -R 775 /u02

echo "=== Reset Complete ==="
echo "You can now restart the installation from Section 1.3"
```

---

# PART 2: EC2 - APPLICATION SERVER SETUP (Ubuntu 24.04)

## Section 2.1: System Prerequisites

### [root] Update System

```bash
# Login as root or use sudo
sudo su -

# Update system packages
apt update && apt upgrade -y

# Install required packages
apt install -y wget curl unzip vim net-tools
```

### [root] Configure Firewall

```bash
# Enable UFW firewall
ufw enable

# Allow SSH
ufw allow 22/tcp

# Allow Tomcat/ORDS port
ufw allow 8080/tcp
ufw allow 8443/tcp

# Verify firewall rules
ufw status verbose
```

### [root] Test Connectivity to EC1 Database

```bash
# Install Oracle Instant Client for testing (optional)
# Test network connectivity to EC1
nc -zv 80.238.214.217 1521

# Expected: Connection to 80.238.214.217 1521 port [tcp/*] succeeded!
```

---

## Section 2.2: Install JDK 17

### [root] Install OpenJDK 17

```bash
# Install OpenJDK 17
apt install -y openjdk-17-jdk

# Verify installation
java -version
javac -version

# Set JAVA_HOME
cat >> /etc/environment << 'EOF'
JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
EOF

# Apply environment
source /etc/environment
echo $JAVA_HOME
```

### [root] Verify Java Installation

```bash
# Verify Java is properly installed
java -version

# Expected output:
# openjdk version "17.x.x"
# OpenJDK Runtime Environment ...
# OpenJDK 64-Bit Server VM ...
```

---

## Section 2.3: Install Apache Tomcat 9

### [root] Create Tomcat User

```bash
# Create tomcat system user
useradd -r -m -U -d /opt/tomcat -s /bin/false tomcat
```

### [root] Download and Install Tomcat 9

```bash
# Download Tomcat 9 (latest stable for ORDS 24.3)
cd /tmp
wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.97/bin/apache-tomcat-9.0.97.tar.gz

# Extract to /opt/tomcat
tar xzf apache-tomcat-9.0.97.tar.gz -C /opt/tomcat --strip-components=1

# Set ownership
chown -R tomcat:tomcat /opt/tomcat

# Set execute permissions on scripts
chmod +x /opt/tomcat/bin/*.sh
```

### [root] Configure Tomcat Environment

```bash
# Create Tomcat environment file
cat > /opt/tomcat/bin/setenv.sh << 'EOF'
#!/bin/bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export CATALINA_HOME=/opt/tomcat
export CATALINA_BASE=/opt/tomcat
export CATALINA_PID=/opt/tomcat/temp/tomcat.pid
export CATALINA_OPTS="-Xms512m -Xmx2048m -XX:+UseG1GC"
EOF

chmod +x /opt/tomcat/bin/setenv.sh
chown tomcat:tomcat /opt/tomcat/bin/setenv.sh
```

### [root] Create Tomcat Systemd Service

```bash
# Create systemd service file
cat > /etc/systemd/system/tomcat.service << 'EOF'
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx2048M -server -XX:+UseG1GC"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable Tomcat service
systemctl enable tomcat

# Start Tomcat
systemctl start tomcat

# Check status
systemctl status tomcat
```

### [root] Verify Tomcat Installation

```bash
# Check Tomcat is running
curl -I http://localhost:8080

# Expected: HTTP/1.1 200 OK

# Check Tomcat process
ps aux | grep tomcat

# Check listening ports
ss -tlnp | grep 8080
```

---

## Section 2.4: Install ORDS 24.3

### [root] Create ORDS Directories

```bash
# Create ORDS directories
mkdir -p /opt/ords
mkdir -p /opt/ords/config
mkdir -p /opt/ords/logs
mkdir -p /home/ubuntu/stage

# Set permissions
chown -R tomcat:tomcat /opt/ords
```

### [root] Download/Extract ORDS

```bash
# After uploading ords-24.3.x.zip via WinSCP to /home/ubuntu/stage/
cd /home/ubuntu/stage

# Extract ORDS
unzip -q ords-24.3.*.zip -d /opt/ords/

# Set permissions
chown -R tomcat:tomcat /opt/ords
```

### [root] Configure ORDS Connection to Database

```bash
# Create ORDS configuration directory structure
mkdir -p /opt/ords/config/databases/default
chown -R tomcat:tomcat /opt/ords/config

# Set ORDS_CONFIG environment variable
echo 'export ORDS_CONFIG=/opt/ords/config' >> /etc/environment
source /etc/environment
```

### [tomcat] Configure ORDS Installation

```bash
# Switch to tomcat user for ORDS setup (or run as root with proper env)
sudo su - tomcat -s /bin/bash

# Set environment
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ORDS_CONFIG=/opt/ords/config
export PATH=/opt/ords/bin:$PATH

# Run ORDS installation
/opt/ords/bin/ords --config /opt/ords/config install

# Interactive prompts:
# - Choose installation type: 2 (Install ORDS and/or configure a database pool)
# - Enter database connection type: 1 (Basic)
# - Enter database host: 80.238.214.217
# - Enter database listen port: 1521
# - Enter database service name: apex_pdb
# - Enter administrator username: SYS
# - Enter database password for SYS: Oracle123
# - Enter default tablespace for ORDS_METADATA: SYSAUX
# - Enter temporary tablespace for ORDS_METADATA: TEMP
# - Enter default tablespace for ORDS_PUBLIC_USER: SYSAUX
# - Enter temporary tablespace for ORDS_PUBLIC_USER: TEMP
# - Enter APEX static resources location: /opt/ords/apex_images
# - Enter 1 if using APEX: 1

exit
```

### [root] Alternative: ORDS Silent Installation

```bash
# Create ORDS install response file
cat > /opt/ords/config/ords_params.properties << 'EOF'
db.hostname=80.238.214.217
db.port=1521
db.servicename=apex_pdb
db.username=APEX_PUBLIC_USER
db.password=ApexPublic123
feature.sdw=true
restEnabledSql.active=true
security.requestValidationFunction=wwv_flow_epg_include_mod_local
misc.defaultPage=apex
EOF

# Run silent install
/opt/ords/bin/ords --config /opt/ords/config install \
    --db-hostname 80.238.214.217 \
    --db-port 1521 \
    --db-servicename apex_pdb \
    --admin-user SYS \
    --proxy-user \
    --password-stdin << 'EOF'
Oracle123
EOF
```

---

## Section 2.5: Copy APEX Images

### [root] Extract APEX Images on EC2

```bash
# After uploading apex_24.2.zip to EC2 via WinSCP
cd /home/ubuntu/stage
unzip -q apex_24.2.zip

# Copy APEX images to ORDS directory
mkdir -p /opt/ords/apex_images
cp -r /home/ubuntu/stage/apex/images/* /opt/ords/apex_images/

# Set permissions
chown -R tomcat:tomcat /opt/ords/apex_images
```

### [root] Configure APEX Images in ORDS

```bash
# Configure static resources path in ORDS
/opt/ords/bin/ords --config /opt/ords/config config set standalone.static.path /opt/ords/apex_images

# Or create/edit settings in config
cat > /opt/ords/config/global/settings.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
<entry key="standalone.static.path">/opt/ords/apex_images</entry>
</properties>
EOF

chown tomcat:tomcat /opt/ords/config/global/settings.xml
```

---

## Section 2.6: Deploy ORDS to Tomcat

### [root] Deploy ORDS WAR File

```bash
# Stop Tomcat
systemctl stop tomcat

# Copy ORDS WAR to Tomcat webapps
cp /opt/ords/ords.war /opt/tomcat/webapps/ords.war

# Create i directory for APEX images (symbolic link)
ln -sf /opt/ords/apex_images /opt/tomcat/webapps/i

# Set ownership
chown tomcat:tomcat /opt/tomcat/webapps/ords.war
chown -h tomcat:tomcat /opt/tomcat/webapps/i

# Start Tomcat
systemctl start tomcat

# Check deployment
ls -la /opt/tomcat/webapps/
```

### [root] Configure ORDS Context

```bash
# Create context configuration for ORDS
mkdir -p /opt/tomcat/conf/Catalina/localhost

cat > /opt/tomcat/conf/Catalina/localhost/ords.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context docBase="/opt/tomcat/webapps/ords.war" path="/ords">
    <Parameter name="config.url" value="file:///opt/ords/config" override="false"/>
</Context>
EOF

chown tomcat:tomcat /opt/tomcat/conf/Catalina/localhost/ords.xml

# Restart Tomcat
systemctl restart tomcat
```

---

## Section 2.7: Verify ORDS Installation

### [root] Test ORDS and APEX Access

```bash
# Wait for Tomcat to fully start (30 seconds)
sleep 30

# Test ORDS status
curl -v http://localhost:8080/ords/

# Test APEX landing page
curl -I http://localhost:8080/ords/apex

# Check Tomcat logs for errors
tail -100 /opt/tomcat/logs/catalina.out
```

### Access APEX from Browser

```
# APEX URL
http://80.238.234.247:8080/ords/apex

# APEX Admin URL
http://80.238.234.247:8080/ords/apex_admin

# Login credentials:
# Workspace: INTERNAL
# Username: ADMIN
# Password: Admin123! (set during APEX installation)
```

---

## Section 2.8: EC2 Reset Commands (If Installation Fails)

### [root] Reset ORDS Installation

```bash
#!/bin/bash
# Save as /root/reset_ords.sh
set -euo pipefail

echo "=== Stopping Tomcat ==="
systemctl stop tomcat

echo "=== Removing ORDS Deployment ==="
rm -rf /opt/tomcat/webapps/ords*
rm -rf /opt/tomcat/webapps/i
rm -f /opt/tomcat/conf/Catalina/localhost/ords.xml

echo "=== Removing ORDS Configuration ==="
rm -rf /opt/ords/config/*

echo "=== Starting Tomcat ==="
systemctl start tomcat

echo "=== Reset Complete ==="
echo "You can now restart ORDS installation from Section 2.4"
```

### [root] Full Reset (Including Tomcat and Java)

```bash
#!/bin/bash
# Save as /root/full_reset_ec2.sh
set -euo pipefail

echo "=== Stopping Services ==="
systemctl stop tomcat 2>/dev/null || true

echo "=== Removing Tomcat ==="
systemctl disable tomcat 2>/dev/null || true
rm -f /etc/systemd/system/tomcat.service
rm -rf /opt/tomcat
userdel -r tomcat 2>/dev/null || true

echo "=== Removing ORDS ==="
rm -rf /opt/ords

echo "=== Removing Java (optional) ==="
# apt remove -y openjdk-17-jdk  # Uncomment if needed

echo "=== Reloading Systemd ==="
systemctl daemon-reload

echo "=== Full Reset Complete ==="
echo "You can now restart installation from Section 2.2"
```

---

# PART 3: QUICK REFERENCE

## EC1 Commands Summary (Database Server)

| Task | User | Command |
|------|------|---------|
| Start Listener | oracle | `lsnrctl start` |
| Stop Listener | oracle | `lsnrctl stop` |
| Start Database | oracle | `sqlplus / as sysdba <<< "STARTUP;"` |
| Stop Database | oracle | `sqlplus / as sysdba <<< "SHUTDOWN IMMEDIATE;"` |
| Open PDB | oracle | `sqlplus / as sysdba <<< "ALTER PLUGGABLE DATABASE apex_pdb OPEN;"` |
| Check APEX Version | oracle | `sqlplus / as sysdba <<< "ALTER SESSION SET CONTAINER=apex_pdb; SELECT VERSION_NO FROM APEX_RELEASE;"` |
| Start Oracle Service | root | `systemctl start oracle-database` |
| Stop Oracle Service | root | `systemctl stop oracle-database` |

## EC2 Commands Summary (App Server)

| Task | User | Command |
|------|------|---------|
| Start Tomcat | root | `systemctl start tomcat` |
| Stop Tomcat | root | `systemctl stop tomcat` |
| Restart Tomcat | root | `systemctl restart tomcat` |
| Check Tomcat Status | root | `systemctl status tomcat` |
| View Tomcat Logs | root | `tail -f /opt/tomcat/logs/catalina.out` |
| Test ORDS | root | `curl http://localhost:8080/ords/` |

## Important URLs

| Service | URL |
|---------|-----|
| APEX | http://80.238.234.247:8080/ords/apex |
| APEX Admin | http://80.238.234.247:8080/ords/apex_admin |
| ORDS Status | http://80.238.234.247:8080/ords/ |

## Default Credentials (Change After Setup!)

| Account | Username | Password |
|---------|----------|----------|
| Oracle SYS | SYS | Oracle123 |
| APEX Admin | ADMIN | Admin123! |
| APEX_PUBLIC_USER | APEX_PUBLIC_USER | ApexPublic123 |
| APEX_LISTENER | APEX_LISTENER | Listener123 |
| APEX_REST_PUBLIC_USER | APEX_REST_PUBLIC_USER | RestPublic123 |

---

# PART 4: TROUBLESHOOTING

## Common Issues

### EC1: Database Won't Start

```bash
# Check alert log
tail -100 /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log

# Check listener log
tail -100 /u01/app/oracle/diag/tnslsnr/$(hostname)/listener/trace/listener.log
```

### EC1: PDB Not Opening

```bash
sqlplus / as sysdba << 'EOF'
-- Check PDB status
SELECT NAME, OPEN_MODE FROM V$PDBS;

-- Force open PDB
ALTER PLUGGABLE DATABASE apex_pdb OPEN FORCE;

-- Check for violations
SELECT NAME, CAUSE, STATUS FROM PDB_PLUG_IN_VIOLATIONS WHERE NAME='APEX_PDB';
EOF
```

### EC2: ORDS Connection Failed

```bash
# Test database connectivity from EC2
nc -zv 80.238.214.217 1521

# Check ORDS logs
tail -100 /opt/tomcat/logs/catalina.out | grep -i error

# Verify ORDS config
cat /opt/ords/config/databases/default/pool.xml
```

### EC2: APEX Images Not Loading

```bash
# Verify images directory
ls -la /opt/ords/apex_images/

# Check symbolic link
ls -la /opt/tomcat/webapps/i

# Test image access
curl -I http://localhost:8080/i/apex_version.txt
```

### EC1: Firewall Blocking Connection

```bash
# On EC1 - Verify port 1521 is open
firewall-cmd --list-ports

# If not open
firewall-cmd --permanent --add-port=1521/tcp
firewall-cmd --reload
```

---

## Security Hardening (Post-Installation)

### Change All Default Passwords

```bash
# On EC1 - Change database passwords
sqlplus / as sysdba << 'EOF'
ALTER USER SYS IDENTIFIED BY "NewStrongPassword1!";
ALTER USER SYSTEM IDENTIFIED BY "NewStrongPassword2!";
ALTER SESSION SET CONTAINER = apex_pdb;
ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "NewStrongPassword3!";
EOF

# Update ORDS with new password
/opt/ords/bin/ords --config /opt/ords/config config set db.password "NewStrongPassword3!"
```

### Restrict Network Access

```bash
# On EC1 - Only allow EC2 to connect
firewall-cmd --permanent --remove-port=1521/tcp
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="80.238.234.247" port port="1521" protocol="tcp" accept'
firewall-cmd --reload
```
