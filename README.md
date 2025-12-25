# Oracle Database 19c + APEX 24.2 + ORDS 24.3 Setup

## Quick Start Guide

### Server Information

| Server | IP | OS | Purpose |
|--------|----|----|---------|
| EC1 | 80.238.214.217 | Oracle Linux 8 | Database + APEX |
| EC2 | 80.238.234.247 | Ubuntu 24.04 | ORDS + Tomcat |

---

## Step-by-Step Execution Order

### Phase 1: EC1 - Database Server Setup

**Upload files to EC1 via WinSCP first:**
```
Target: /home/oracle/stage/
Files:
  - LINUX.X64_193000_db_home.zip
  - apex_24.2.zip
```

**Execute scripts in order:**

```bash
# 1. [root] Uninstall existing Oracle (if any)
./ec1-db-server/01-uninstall-oracle.sh

# 2. [root] Install prerequisites
./ec1-db-server/02-prerequisites.sh

# 3. [oracle] Install Oracle software
su - oracle
./03-install-oracle.sh

# 4. [root] Run post-install root scripts
exit  # back to root
/u01/app/oraInventory/orainstRoot.sh
/u01/app/oracle/product/19.3.0/dbhome_1/root.sh

# 5. [oracle] Create database with CDB and PDB
su - oracle
./04-create-database.sh

# 6. [oracle] Install APEX
./05-install-apex.sh

# 7. [root] Create systemd services
exit  # back to root
./ec1-db-server/06-create-service.sh
```

### Phase 2: EC2 - Application Server Setup

**Upload files to EC2 via WinSCP first:**
```
Target: /home/ubuntu/stage/
Files:
  - ords-24.3.x.zip
  - apex_24.2.zip (for images)
```

**Execute scripts in order:**

```bash
# 1. [root] Install prerequisites
sudo su -
./ec2-app-server/01-prerequisites.sh

# 2. [root] Install JDK 17
./ec2-app-server/02-install-jdk.sh

# 3. [root] Install Tomcat 9
./ec2-app-server/03-install-tomcat.sh

# 4. [root] Install and configure ORDS
./ec2-app-server/04-install-ords.sh

# 5. [root] Deploy ORDS to Tomcat
./ec2-app-server/05-deploy-ords.sh
```

---

## Access URLs

| Service | URL |
|---------|-----|
| APEX | http://80.238.234.247:8080/ords/apex |
| APEX Admin | http://80.238.234.247:8080/ords/apex_admin |
| ORDS | http://80.238.234.247:8080/ords/ |

## Default Credentials

| Account | Password | Notes |
|---------|----------|-------|
| SYS | Oracle123 | Database admin |
| APEX ADMIN | Admin123! | APEX administration |
| APEX_PUBLIC_USER | ApexPublic123 | ORDS connection |
| APEX_LISTENER | Listener123 | REST services |

⚠️ **CHANGE ALL PASSWORDS AFTER INSTALLATION!**

---

## Reset Commands

### EC1 - Reset Oracle Installation
```bash
# [root]
./ec1-db-server/reset-all.sh
```

### EC2 - Reset ORDS/Tomcat
```bash
# [root]
./ec2-app-server/reset-all.sh
```

---

## Troubleshooting

### Check EC1 Database Status
```bash
# As oracle user
sqlplus / as sysdba <<< "SELECT STATUS FROM V\$INSTANCE;"
lsnrctl status
```

### Check EC2 ORDS Status
```bash
# Check Tomcat
systemctl status tomcat
tail -f /opt/tomcat/logs/catalina.out

# Test ORDS endpoint
curl -v http://localhost:8080/ords/
```

### Test Connectivity from EC2 to EC1
```bash
nc -zv 80.238.214.217 1521
```

---

## File Structure

```
/workspace/
├── README.md                    # This file
├── oracle-apex-ords-setup-guide.md  # Detailed guide
│
├── ec1-db-server/               # Scripts for EC1 (Oracle Linux 8)
│   ├── 01-uninstall-oracle.sh
│   ├── 02-prerequisites.sh
│   ├── 03-install-oracle.sh
│   ├── 04-create-database.sh
│   ├── 05-install-apex.sh
│   ├── 06-create-service.sh
│   └── reset-all.sh
│
└── ec2-app-server/              # Scripts for EC2 (Ubuntu 24.04)
    ├── 01-prerequisites.sh
    ├── 02-install-jdk.sh
    ├── 03-install-tomcat.sh
    ├── 04-install-ords.sh
    ├── 05-deploy-ords.sh
    └── reset-all.sh
```

---

## Firewall Configuration (EC1)

The firewall is configured in `02-prerequisites.sh` to allow remote connections. You can also run independently:

```bash
# [root] Configure firewall for remote access
./ec1-db-server/configure-firewall.sh

# [oracle/root] Verify remote access is working
./ec1-db-server/verify-remote-access.sh
```

### Open Ports on EC1
| Port | Service |
|------|---------|
| 1521/tcp | Oracle Listener (DB connections) |
| 5500/tcp | Enterprise Manager Express |
| 5501/tcp | Additional EM port |

### Remote Connection Examples

**SQL*Plus from local machine:**
```bash
sqlplus sys/Oracle123@80.238.214.217:1521/apex_pdb as sysdba
```

**SQL Developer / DBeaver:**
```
Host: 80.238.214.217
Port: 1521
Service: apex_pdb
User: SYS (as SYSDBA) or SYSTEM
```

**JDBC URL:**
```
jdbc:oracle:thin:@80.238.214.217:1521/apex_pdb
```

**TNS Entry (add to local tnsnames.ora):**
```
APEX_PDB_REMOTE =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 80.238.214.217)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = apex_pdb)
    )
  )
```

---

## Security Notes

1. **Change all default passwords immediately after setup**

2. For production, restrict port 1521 to specific IPs only:
   ```bash
   # On EC1 [root] - restrict to EC2 only (blocks your local access)
   firewall-cmd --permanent --remove-port=1521/tcp
   firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="80.238.234.247" port port="1521" protocol="tcp" accept'
   firewall-cmd --reload
   ```

3. Consider enabling HTTPS for ORDS/Tomcat in production
