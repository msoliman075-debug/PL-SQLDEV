# ORDS 24.3 and Tomcat Installation Guide

## Environment Overview

| Server | Role | OS | EIP | Details |
|--------|------|-----|-----|---------|
| EC1 | Database Server | Oracle Linux 8 | 80.238.214.217 | Oracle 19c CDB, PDB1 with APEX |
| EC2 | Middleware Server | Ubuntu 24.04 | 80.238.234.247 | ORDS 24.3 + Tomcat |

### Connection Details
- **Database Port**: 1521
- **Service Name**: PDB1
- **ORDS Version**: 24.3
- **Tomcat Version**: 10.1.x (compatible with ORDS 24.3)
- **JDK Version**: 17 (required for ORDS 24.3)

---

## PHASE 1: Database Server Preparation (EC1 - Oracle Linux 8)

### 1.1 Verify APEX Installation

**Server**: EC1 (Database Server)  
**OS User**: oracle

```bash
# Connect to PDB1 as SYSDBA
sqlplus / as sysdba
```

```sql
-- Switch to PDB1
ALTER SESSION SET CONTAINER = PDB1;

-- Verify APEX version and status
SELECT VERSION_NO, STATUS FROM DBA_REGISTRY WHERE COMP_ID = 'APEX';

-- Check APEX schemas exist
SELECT USERNAME, ACCOUNT_STATUS FROM DBA_USERS WHERE USERNAME LIKE 'APEX%';

-- Verify APEX_PUBLIC_USER exists and is unlocked
SELECT USERNAME, ACCOUNT_STATUS FROM DBA_USERS WHERE USERNAME = 'APEX_PUBLIC_USER';

EXIT;
```

### 1.2 Create ORDS Database User

**Server**: EC1 (Database Server)  
**OS User**: oracle

Run the script: `01_db_create_ords_user.sql`

```sql
-- Connect as SYSDBA to PDB1
ALTER SESSION SET CONTAINER = PDB1;

-- Create tablespace for ORDS metadata (optional but recommended)
CREATE TABLESPACE ORDS_TS 
DATAFILE SIZE 100M 
AUTOEXTEND ON NEXT 50M MAXSIZE 2G;

-- Create ORDS_PUBLIC_USER (for ORDS runtime)
CREATE USER ORDS_PUBLIC_USER IDENTIFIED BY "<ORDS_PUBLIC_USER_PASSWORD>"
DEFAULT TABLESPACE ORDS_TS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON ORDS_TS;

-- Grant required privileges
GRANT CONNECT TO ORDS_PUBLIC_USER;

-- Create ORDS_METADATA schema owner
CREATE USER ORDS_METADATA IDENTIFIED BY "<ORDS_METADATA_PASSWORD>"
DEFAULT TABLESPACE ORDS_TS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON ORDS_TS;

GRANT CONNECT, RESOURCE TO ORDS_METADATA;

-- Unlock APEX_PUBLIC_USER and set password
ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "<APEX_PUBLIC_USER_PASSWORD>" ACCOUNT UNLOCK;
GRANT CONNECT TO APEX_PUBLIC_USER;

-- Create APEX REST public user (for RESTful services)
BEGIN
  APEX_UTIL.SET_WORKSPACE(p_workspace => 'INTERNAL');
  COMMIT;
END;
/

EXIT;
```

### 1.3 Configure Network ACL (Required for ORDS to connect)

**Server**: EC1 (Database Server)  
**OS User**: oracle

```sql
-- Connect as SYSDBA to PDB1
ALTER SESSION SET CONTAINER = PDB1;

-- Grant network privileges for ORDS
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => '*',
    ace => xs$ace_type(
      privilege_list => xs$name_list('connect', 'resolve'),
      principal_name => 'APEX_230200',
      principal_type => xs_acl.ptype_db
    )
  );
END;
/

COMMIT;
EXIT;
```

### 1.4 Open Firewall for Database Port

**Server**: EC1 (Database Server)  
**OS User**: root

```bash
# Check current firewall status
sudo firewall-cmd --state

# Open port 1521 for Oracle Database
sudo firewall-cmd --permanent --add-port=1521/tcp

# Reload firewall
sudo firewall-cmd --reload

# Verify port is open
sudo firewall-cmd --list-ports
```

---

## PHASE 2: Middleware Server Setup (EC2 - Ubuntu 24.04)

### 2.1 System Update and Prerequisites

**Server**: EC2 (Middleware Server)  
**OS User**: root or sudo user

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required utilities
sudo apt install -y unzip wget curl libaio1 net-tools
```

### 2.2 Install JDK 17

**Server**: EC2 (Middleware Server)  
**OS User**: root or sudo user

```bash
# Install OpenJDK 17
sudo apt install -y openjdk-17-jdk

# Verify installation
java -version
javac -version

# Set JAVA_HOME (add to /etc/environment)
echo 'JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"' | sudo tee -a /etc/environment

# Apply environment
source /etc/environment

# Verify JAVA_HOME
echo $JAVA_HOME
```

### 2.3 Create ORDS User and Directories

**Server**: EC2 (Middleware Server)  
**OS User**: root or sudo user

```bash
# Create ords system user
sudo useradd -r -m -U -d /opt/ords -s /bin/bash ords

# Create directory structure
sudo mkdir -p /opt/ords/ords-24.3
sudo mkdir -p /opt/ords/config
sudo mkdir -p /opt/ords/logs
sudo mkdir -p /opt/ords/doc_root

# Set ownership
sudo chown -R ords:ords /opt/ords
```

### 2.4 Install Oracle Instant Client (Required for SQL*Net connectivity)

**Server**: EC2 (Middleware Server)  
**OS User**: root or sudo user

```bash
# Download and install Oracle Instant Client
cd /tmp

# Option 1: Download from Oracle (requires login)
# wget https://download.oracle.com/otn_software/linux/instantclient/2340000/instantclient-basic-linux.x64-23.4.0.24.05.zip

# Option 2: Install via apt (Ubuntu)
sudo apt install -y libaio1

# If you have the instant client zip files:
# sudo mkdir -p /opt/oracle
# sudo unzip instantclient-basic-linux.x64-*.zip -d /opt/oracle/
# sudo sh -c 'echo /opt/oracle/instantclient_23_4 > /etc/ld.so.conf.d/oracle-instantclient.conf'
# sudo ldconfig
```

---

## PHASE 3: ORDS 24.3 Installation

### 3.1 Extract ORDS

**Server**: EC2 (Middleware Server)  
**OS User**: ords

```bash
# Switch to ords user
sudo su - ords

# Assuming ORDS zip is uploaded to /tmp/ords-24.3.0.xxx.zip via WinSCP
cd /opt/ords
unzip /tmp/ords-24.3.0.*.zip -d /opt/ords/ords-24.3

# Verify extraction
ls -la /opt/ords/ords-24.3/
```

### 3.2 Configure ORDS

**Server**: EC2 (Middleware Server)  
**OS User**: ords

```bash
# Set ORDS binary path
export PATH=/opt/ords/ords-24.3/bin:$PATH

# Create configuration directory
mkdir -p /opt/ords/config

# Install ORDS into PDB1
ords --config /opt/ords/config install \
  --admin-user SYS \
  --db-hostname 80.238.214.217 \
  --db-port 1521 \
  --db-servicename PDB1 \
  --feature-sdw true \
  --gateway-mode proxied \
  --gateway-user APEX_PUBLIC_USER \
  --proxy-user \
  --password-stdin <<EOF
<SYS_PASSWORD>
<ORDS_PUBLIC_USER_PASSWORD>
EOF
```

### 3.3 Interactive ORDS Installation (Alternative)

**Server**: EC2 (Middleware Server)  
**OS User**: ords

```bash
# Interactive installation
cd /opt/ords/ords-24.3
./bin/ords --config /opt/ords/config install

# Follow prompts:
# 1. Enter database connection type: 1 (Basic)
# 2. Enter hostname: 80.238.214.217
# 3. Enter port: 1521
# 4. Enter service name: PDB1
# 5. Enter administrator username: SYS
# 6. Enter SYS password: <your_sys_password>
# 7. Enter default tablespace: SYSAUX
# 8. Enter temp tablespace: TEMP
# 9. Enter ORDS_PUBLIC_USER password: <create_password>
# 10. Skip HTTPS configuration for now: 1
```

### 3.4 Configure APEX Static Files

**Server**: EC2 (Middleware Server)  
**OS User**: ords

```bash
# Copy APEX images to ORDS document root
# First, copy apex images from EC1 or extract from APEX installation zip
# Assuming apex images are in /tmp/apex_images/

sudo mkdir -p /opt/ords/doc_root/i
# Copy APEX static files (images, css, js)
# scp -r oracle@80.238.214.217:/path/to/apex/images/* /opt/ords/doc_root/i/

# Or extract from APEX zip
# unzip apex_24.1.zip -d /tmp/
# cp -r /tmp/apex/images/* /opt/ords/doc_root/i/

sudo chown -R ords:ords /opt/ords/doc_root
```

### 3.5 Test ORDS Standalone

**Server**: EC2 (Middleware Server)  
**OS User**: ords

```bash
# Start ORDS in standalone mode for testing
cd /opt/ords/ords-24.3
./bin/ords --config /opt/ords/config serve \
  --port 8080 \
  --apex-images /opt/ords/doc_root/i

# Test in another terminal or browser:
# curl http://localhost:8080/ords/
# Browser: http://80.238.234.247:8080/ords/
```

---

## PHASE 4: Tomcat Installation

### 4.1 Download and Install Tomcat 10.1

**Server**: EC2 (Middleware Server)  
**OS User**: root or sudo user

```bash
# Create tomcat user
sudo useradd -r -m -U -d /opt/tomcat -s /bin/false tomcat

# Download Tomcat 10.1.x
cd /tmp
wget https://dlcdn.apache.org/tomcat/tomcat-10/v10.1.34/bin/apache-tomcat-10.1.34.tar.gz

# Extract to /opt/tomcat
sudo tar xzf apache-tomcat-10.1.34.tar.gz -C /opt/tomcat --strip-components=1

# Set ownership
sudo chown -R tomcat:tomcat /opt/tomcat

# Make scripts executable
sudo chmod +x /opt/tomcat/bin/*.sh
```

### 4.2 Configure Tomcat Environment

**Server**: EC2 (Middleware Server)  
**OS User**: root or sudo user

Create `/opt/tomcat/bin/setenv.sh`:

```bash
sudo tee /opt/tomcat/bin/setenv.sh << 'EOF'
#!/bin/bash
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
export CATALINA_HOME="/opt/tomcat"
export CATALINA_BASE="/opt/tomcat"
export CATALINA_PID="/opt/tomcat/temp/tomcat.pid"
export CATALINA_OPTS="-Xms512m -Xmx2048m -server -XX:+UseG1GC"
export JAVA_OPTS="-Djava.awt.headless=true -Dconfig.url=/opt/ords/config"
EOF

sudo chmod +x /opt/tomcat/bin/setenv.sh
sudo chown tomcat:tomcat /opt/tomcat/bin/setenv.sh
```

### 4.3 Deploy ORDS WAR to Tomcat

**Server**: EC2 (Middleware Server)  
**OS User**: ords/tomcat

```bash
# Create ORDS WAR file
sudo su - ords
cd /opt/ords/ords-24.3
./bin/ords war /opt/ords/ords.war

# Deploy WAR to Tomcat
sudo cp /opt/ords/ords.war /opt/tomcat/webapps/ords.war
sudo chown tomcat:tomcat /opt/tomcat/webapps/ords.war

# Configure ORDS config location for Tomcat
sudo mkdir -p /opt/tomcat/conf/Catalina/localhost
sudo tee /opt/tomcat/conf/Catalina/localhost/ords.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context docBase="/opt/tomcat/webapps/ords" path="/ords" reloadable="true">
    <Parameter name="config.url" value="/opt/ords/config" override="false"/>
</Context>
EOF

sudo chown tomcat:tomcat /opt/tomcat/conf/Catalina/localhost/ords.xml
```

### 4.4 Configure APEX Images in Tomcat

**Server**: EC2 (Middleware Server)  
**OS User**: root

```bash
# Create symbolic link for APEX images
sudo ln -s /opt/ords/doc_root/i /opt/tomcat/webapps/i

# Or copy images directly
# sudo cp -r /opt/ords/doc_root/i /opt/tomcat/webapps/

sudo chown -R tomcat:tomcat /opt/tomcat/webapps/i 2>/dev/null || true
```

### 4.5 Create Tomcat Systemd Service

**Server**: EC2 (Middleware Server)  
**OS User**: root

```bash
sudo tee /etc/systemd/system/tomcat.service << 'EOF'
[Unit]
Description=Apache Tomcat 10.1 Web Application Server
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_OPTS=-Xms512M -Xmx2048M -server -XX:+UseG1GC"
Environment="JAVA_OPTS=-Djava.awt.headless=true"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
sudo systemctl daemon-reload

# Enable Tomcat to start on boot
sudo systemctl enable tomcat
```

### 4.6 Start Tomcat

**Server**: EC2 (Middleware Server)  
**OS User**: root

```bash
# Start Tomcat
sudo systemctl start tomcat

# Check status
sudo systemctl status tomcat

# View logs
sudo tail -f /opt/tomcat/logs/catalina.out
```

### 4.7 Configure Firewall

**Server**: EC2 (Middleware Server)  
**OS User**: root

```bash
# Ubuntu uses UFW
sudo ufw allow 8080/tcp
sudo ufw allow 8443/tcp
sudo ufw status
```

---

## PHASE 5: Verification and Testing

### 5.1 Test ORDS Connection

**Server**: EC2 (Middleware Server)  
**OS User**: any

```bash
# Test ORDS endpoint
curl -v http://localhost:8080/ords/

# Test APEX
curl -v http://localhost:8080/ords/apex

# From browser:
# http://80.238.234.247:8080/ords/
# http://80.238.234.247:8080/ords/apex
```

### 5.2 Verify Database Connectivity

**Server**: EC2 (Middleware Server)  
**OS User**: ords

```bash
# Check ORDS config
cd /opt/ords/ords-24.3
./bin/ords --config /opt/ords/config config list
```

### 5.3 Check Tomcat Logs

**Server**: EC2 (Middleware Server)  
**OS User**: root

```bash
# View Catalina logs
sudo tail -100 /opt/tomcat/logs/catalina.out

# View ORDS logs (if configured)
sudo tail -100 /opt/ords/logs/*.log
```

---

## PHASE 6: Reset/Cleanup Commands

### 6.1 Reset ORDS Installation (EC2)

**Server**: EC2 (Middleware Server)  
**OS User**: root

```bash
# Stop Tomcat
sudo systemctl stop tomcat

# Remove ORDS deployment from Tomcat
sudo rm -rf /opt/tomcat/webapps/ords*
sudo rm -f /opt/tomcat/conf/Catalina/localhost/ords.xml

# Remove ORDS configuration
sudo rm -rf /opt/ords/config/*

# Optional: Remove ORDS completely
# sudo rm -rf /opt/ords/ords-24.3
# sudo rm -rf /opt/ords

# Restart Tomcat
sudo systemctl start tomcat
```

### 6.2 Reset Tomcat Installation (EC2)

**Server**: EC2 (Middleware Server)  
**OS User**: root

```bash
# Stop and disable Tomcat
sudo systemctl stop tomcat
sudo systemctl disable tomcat

# Remove Tomcat service
sudo rm -f /etc/systemd/system/tomcat.service
sudo systemctl daemon-reload

# Remove Tomcat installation
sudo rm -rf /opt/tomcat

# Remove tomcat user
sudo userdel -r tomcat

# Remove ords user (if needed)
# sudo userdel -r ords
```

### 6.3 Reset ORDS Database Objects (EC1)

**Server**: EC1 (Database Server)  
**OS User**: oracle

```sql
-- Connect as SYSDBA to PDB1
ALTER SESSION SET CONTAINER = PDB1;

-- Uninstall ORDS schema
-- Run from ORDS installation directory on EC2:
-- ./bin/ords --config /opt/ords/config uninstall

-- Manual cleanup (if ORDS uninstall fails)
DROP USER ORDS_METADATA CASCADE;
DROP USER ORDS_PUBLIC_USER CASCADE;

-- Lock APEX_PUBLIC_USER (if needed)
ALTER USER APEX_PUBLIC_USER ACCOUNT LOCK;

-- Drop ORDS tablespace (optional)
DROP TABLESPACE ORDS_TS INCLUDING CONTENTS AND DATAFILES;

COMMIT;
EXIT;
```

### 6.4 Complete Reset Script (EC2)

**Server**: EC2 (Middleware Server)  
**OS User**: root

```bash
#!/bin/bash
set -euo pipefail

echo "=== Stopping Services ==="
sudo systemctl stop tomcat 2>/dev/null || true

echo "=== Removing ORDS ==="
sudo rm -rf /opt/ords/config/*
sudo rm -rf /opt/tomcat/webapps/ords*
sudo rm -f /opt/tomcat/conf/Catalina/localhost/ords.xml

echo "=== Clearing Tomcat Logs ==="
sudo rm -rf /opt/tomcat/logs/*

echo "=== Clearing Tomcat Work Directory ==="
sudo rm -rf /opt/tomcat/work/*

echo "=== Starting Tomcat ==="
sudo systemctl start tomcat

echo "=== Reset Complete ==="
```

---

## Troubleshooting

### Common Issues

1. **Connection Refused to Database**
   - Verify firewall on EC1 allows port 1521 from EC2
   - Check listener status: `lsnrctl status`
   - Test connectivity: `telnet 80.238.214.217 1521`

2. **ORDS Installation Fails**
   - Verify SYS password is correct
   - Check database is accessible
   - Review ORDS logs: `/opt/ords/logs/`

3. **Tomcat Won't Start**
   - Check JAVA_HOME is set correctly
   - Review logs: `/opt/tomcat/logs/catalina.out`
   - Verify port 8080 is not in use: `netstat -tlnp | grep 8080`

4. **APEX Images Not Loading**
   - Verify images are in correct location
   - Check permissions on `/opt/ords/doc_root/i`
   - Verify context path in `ords.xml`

5. **504 Gateway Timeout**
   - Increase database connection pool
   - Check database performance
   - Review ORDS pool settings

### Useful Commands

```bash
# Check listening ports
sudo netstat -tlnp | grep -E '8080|1521'

# Test database connectivity from EC2
telnet 80.238.214.217 1521

# Check Java version
java -version

# Check ORDS version
/opt/ords/ords-24.3/bin/ords --version

# Check Tomcat version
/opt/tomcat/bin/version.sh

# View real-time logs
sudo tail -f /opt/tomcat/logs/catalina.out

# Check systemd service status
sudo systemctl status tomcat
```

---

## Security Recommendations

1. **Change default passwords** for all database users
2. **Configure HTTPS** for production use
3. **Restrict network access** using firewall rules
4. **Use Oracle Wallet** instead of plain-text passwords
5. **Enable ORDS access logging** for audit
6. **Regular security patches** for OS and applications

---

## File Checklist

| File | Server | Description |
|------|--------|-------------|
| `01_db_create_ords_user.sql` | EC1 | SQL script to create ORDS users |
| `02_mw_install_prereqs.sh` | EC2 | Install prerequisites |
| `03_mw_install_ords.sh` | EC2 | Install and configure ORDS |
| `04_mw_install_tomcat.sh` | EC2 | Install and configure Tomcat |
| `05_mw_reset_all.sh` | EC2 | Complete reset script |
| `06_db_reset_ords.sql` | EC1 | Database cleanup script |
