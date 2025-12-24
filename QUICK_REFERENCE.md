# ORDS 24.3 Quick Reference Card

## Server Information

```
┌─────────────────────────────────────────────────────────────────┐
│  EC1 - Database Server                                          │
│  IP: 80.238.214.217 | OS: Oracle Linux 8                        │
│  Oracle 19c CDB + PDB1 with APEX                                │
│  Port: 1521 | Service: PDB1                                     │
├─────────────────────────────────────────────────────────────────┤
│  EC2 - Middleware Server                                        │
│  IP: 80.238.234.247 | OS: Ubuntu 24.04                          │
│  ORDS 24.3 + Tomcat 10.1 + JDK 17                               │
│  Port: 8080                                                     │
└─────────────────────────────────────────────────────────────────┘
```

## Execution Order

```
Step 1: EC1 (oracle)    → 01_db_create_ords_user.sql
Step 2: EC1 (root)      → firewall-cmd --add-port=1521/tcp
Step 3: EC2 (WinSCP)    → Upload ords-24.3.0.xxx.zip to /tmp
Step 4: EC2 (root)      → ./02_mw_install_prereqs.sh
Step 5: EC2 (root)      → ./03_mw_install_ords.sh
Step 6: EC2 (ords)      → ords --config /opt/ords/config install
Step 7: EC2 (root)      → ./04_mw_install_tomcat.sh
Step 8: Browser         → http://80.238.234.247:8080/ords/apex
```

## Key Paths

### EC1 (Database)
```
Oracle Home:     $ORACLE_HOME
Listener:        $ORACLE_HOME/network/admin/listener.ora
TNS Names:       $ORACLE_HOME/network/admin/tnsnames.ora
```

### EC2 (Middleware)
```
ORDS Home:       /opt/ords
ORDS Binary:     /opt/ords/ords-24.3/bin/ords
ORDS Config:     /opt/ords/config
APEX Images:     /opt/ords/doc_root/i
Tomcat Home:     /opt/tomcat
Tomcat Logs:     /opt/tomcat/logs/catalina.out
ORDS WAR:        /opt/tomcat/webapps/ords.war
```

## Essential Commands

### EC1 - Database Server

```bash
# Check listener
lsnrctl status

# Connect to PDB1
sqlplus / as sysdba
ALTER SESSION SET CONTAINER = PDB1;

# Verify APEX
SELECT VERSION_NO, STATUS FROM DBA_REGISTRY WHERE COMP_ID = 'APEX';

# Check ORDS users
SELECT USERNAME, ACCOUNT_STATUS FROM DBA_USERS 
WHERE USERNAME IN ('ORDS_PUBLIC_USER','ORDS_METADATA','APEX_PUBLIC_USER');

# Open firewall
sudo firewall-cmd --permanent --add-port=1521/tcp
sudo firewall-cmd --reload
```

### EC2 - Middleware Server

```bash
# ORDS commands (as ords user)
sudo su - ords
cd /opt/ords/ords-24.3

# Install ORDS
./bin/ords --config /opt/ords/config install

# Check version
./bin/ords --version

# View config
./bin/ords --config /opt/ords/config config list

# Test standalone
./bin/ords --config /opt/ords/config serve --port 8080

# Tomcat commands (as root)
sudo systemctl start tomcat
sudo systemctl stop tomcat
sudo systemctl restart tomcat
sudo systemctl status tomcat

# View logs
tail -f /opt/tomcat/logs/catalina.out

# Check ports
netstat -tlnp | grep 8080
ss -tlnp | grep 8080
```

## Troubleshooting

### Cannot connect to database from EC2

```bash
# Test connectivity
telnet 80.238.214.217 1521

# Check listener on EC1
lsnrctl status

# Check firewall on EC1
sudo firewall-cmd --list-ports
```

### ORDS installation fails

```bash
# Check database connectivity
sqlplus sys@80.238.214.217:1521/PDB1 as sysdba

# Review ORDS logs
cat /opt/ords/logs/*.log
```

### Tomcat won't start

```bash
# Check JAVA_HOME
echo $JAVA_HOME
java -version

# Check port in use
netstat -tlnp | grep 8080

# View detailed logs
journalctl -u tomcat -f
tail -100 /opt/tomcat/logs/catalina.out
```

### APEX images not loading

```bash
# Verify images exist
ls -la /opt/ords/doc_root/i/

# Check Tomcat symlink
ls -la /opt/tomcat/webapps/i

# Fix permissions
sudo chown -R ords:ords /opt/ords/doc_root
```

## Reset Procedures

### Soft Reset (ORDS config only)
```bash
sudo ./05_mw_reset_all.sh soft
```

### Hard Reset (Tomcat + ORDS)
```bash
sudo ./05_mw_reset_all.sh hard
```

### Complete Reset (everything)
```bash
sudo ./05_mw_reset_all.sh complete
```

### Database Reset
```bash
sqlplus / as sysdba @06_db_reset_ords.sql
```

## Security Checklist

- [ ] Change default passwords in 01_db_create_ords_user.sql
- [ ] Update SYS password for ORDS installation
- [ ] Configure HTTPS for production
- [ ] Restrict firewall to specific IPs
- [ ] Enable audit logging
- [ ] Regular security patches
