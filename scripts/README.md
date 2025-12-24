# ORDS 24.3 & Tomcat Installation Scripts

## Environment

| Server | Role | OS | IP | Port |
|--------|------|----|----|------|
| EC1 | Database | Oracle Linux 8 | 80.238.214.217 | 1521 |
| EC2 | Middleware | Ubuntu 24.04 | 80.238.234.247 | 8080 |

## Quick Start

### On EC1 (Database Server)

```bash
# As oracle user
sqlplus / as sysdba @01_db_create_ords_user.sql

# As root - open firewall
sudo firewall-cmd --permanent --add-port=1521/tcp
sudo firewall-cmd --reload
```

### On EC2 (Middleware Server)

```bash
# 1. Upload ORDS zip to /tmp via WinSCP

# 2. Install prerequisites
sudo ./02_mw_install_prereqs.sh

# 3. Extract ORDS
sudo ./03_mw_install_ords.sh

# 4. Configure ORDS (interactive)
sudo su - ords
cd /opt/ords/ords-24.3
./bin/ords --config /opt/ords/config install

# 5. Install Tomcat and deploy
exit  # back to root
sudo ./04_mw_install_tomcat.sh
```

### Access URLs
- ORDS: http://80.238.234.247:8080/ords/
- APEX: http://80.238.234.247:8080/ords/apex

## Scripts

| Script | Server | User | Description |
|--------|--------|------|-------------|
| `01_db_create_ords_user.sql` | EC1 | oracle | Create ORDS database users |
| `02_mw_install_prereqs.sh` | EC2 | root | Install JDK, create users/dirs |
| `03_mw_install_ords.sh` | EC2 | root | Extract and prepare ORDS |
| `04_mw_install_tomcat.sh` | EC2 | root | Install Tomcat, deploy ORDS |
| `05_mw_reset_all.sh` | EC2 | root | Reset middleware installation |
| `06_db_reset_ords.sql` | EC1 | oracle | Reset database ORDS objects |

## Reset Commands

```bash
# Soft reset - ORDS config only
sudo ./05_mw_reset_all.sh soft

# Hard reset - Tomcat + ORDS (keeps zip)
sudo ./05_mw_reset_all.sh hard

# Complete reset - everything
sudo ./05_mw_reset_all.sh complete

# Database reset
sqlplus / as sysdba @06_db_reset_ords.sql
```

## APEX Images

Copy APEX images after ORDS installation:

```bash
# On EC2 after extracting APEX zip
sudo cp -r /tmp/apex/images/* /opt/ords/doc_root/i/
sudo chown -R ords:ords /opt/ords/doc_root
```
