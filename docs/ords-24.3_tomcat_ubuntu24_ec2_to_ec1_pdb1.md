# ORDS 24.3 + Tomcat on EC2 (Ubuntu 24.04) connecting to EC1 (Oracle Linux 8, DB 19c, PDB1)

This runbook is written for **least-privilege** and **no hard-coded credentials**.

## Values (from your environment)

- **EC1 (DB server)**: `80.238.214.217`
- **DB port**: `1521`
- **PDB service name**: `PDB1`
- **EC2 (Middleware server)**: `80.238.234.247`
- **ORDS version**: `24.3`

---

## 0) Network prerequisite (run first)

### EC2 (Ubuntu) — run as `root` (or a sudo-capable user)

```bash
sudo -i
set -euo pipefail

# Verify EC2 can reach EC1 listener
nc -vz 80.238.214.217 1521
```

If this fails, fix **security groups / firewall** before continuing.

---

## 1) Confirm APEX is installed successfully in PDB1 (required)

### EC1 (Oracle Linux 8) — run as `oracle` OS user

```bash
sudo -iu oracle
set -euo pipefail

# Connect specifically to the PDB service
sqlplus -L / as sysdba <<'SQL'
whenever sqlerror exit 1
set pages 200 lines 200

-- If this CDB has multiple PDBs, confirm PDB1 exists and is open:
col name format a20
select con_id, name, open_mode from v$pdbs order by con_id;

-- Switch session to PDB1:
alter session set container = PDB1;

-- Confirm the service name ORDS will use is registered/available:
col name format a35
select name from v$services order by name;

-- Confirm APEX component status in PDB1:
col comp_name format a45
col version format a15
select comp_id, comp_name, version, status
from dba_registry
where comp_id = 'APEX';

-- APEX release table exists in PDB1 when APEX is installed:
select version_no, api_compatibility, patch_applied
from apex_release;

exit
SQL
```

**Expected:** APEX shows `STATUS = VALID` and `apex_release` returns a row.

---

## 2) EC2: Install prerequisites (JDK + unzip + netcat)

### EC2 (Ubuntu 24.04) — run as `root` (or a sudo-capable user)

```bash
sudo -i
set -euo pipefail

apt-get update
apt-get install -y unzip ca-certificates netcat-openbsd

# Oracle ORDS 24.3 requires a supported Java LTS. Use Java 17 on Ubuntu 24.04:
apt-get install -y openjdk-17-jdk
java -version
```

---

## 3) EC2: Create a dedicated OS user and directories for ORDS

### EC2 (Ubuntu 24.04) — run as `root`

```bash
sudo -i
set -euo pipefail

# Dedicated, least-privilege user to own ORDS config/artifacts
id ords >/dev/null 2>&1 || useradd --system --home /opt/ords --create-home --shell /usr/sbin/nologin ords

install -d -o ords -g ords -m 0750 /opt/ords
install -d -o ords -g ords -m 0750 /opt/ords/product
install -d -o ords -g ords -m 0750 /opt/ords/config
install -d -o ords -g ords -m 0750 /opt/ords/log
```

---

## 4) EC2: Unzip ORDS 24.3 (you said you will upload the zip via WinSCP)

### EC2 (Ubuntu 24.04) — run as `root`

Assume you uploaded ORDS zip to: `/tmp/ords-24.3.zip` (adjust if different).

```bash
sudo -i
set -euo pipefail

ORDS_ZIP='/tmp/ords-24.3.zip'
test -f "$ORDS_ZIP"

rm -rf /opt/ords/product/ords-24.3
install -d -o ords -g ords -m 0750 /opt/ords/product/ords-24.3

unzip -q "$ORDS_ZIP" -d /opt/ords/product/ords-24.3
chown -R ords:ords /opt/ords/product/ords-24.3

ls -la /opt/ords/product/ords-24.3
```

---

## 5) EC2: Run ORDS install (creates/validates DB objects in PDB1)

This step connects from EC2 to EC1 (`80.238.214.217:1521/PDB1`) and will prompt for DB credentials.

### EC2 (Ubuntu 24.04) — run as `ords` OS user

```bash
sudo -iu ords
set -euo pipefail

export JAVA_HOME='/usr/lib/jvm/java-17-openjdk-amd64'
export PATH="$JAVA_HOME/bin:$PATH"

cd /opt/ords/product/ords-24.3

# Oracle-doc style: use a persistent config directory.
# This command is intentionally interactive to avoid embedding passwords.
./bin/ords --config /opt/ords/config install
```

When prompted, use:
- **DB host**: `80.238.214.217`
- **DB port**: `1521`
- **DB service name**: `PDB1`

Notes:
- Provide the credentials you used to install APEX (typically `SYS` as `SYSDBA`) when ORDS requests privileged installation credentials.
- Choose the default options unless you have a specific security requirement to change them.

---

## 6) EC2: Install Tomcat (recommended: Tomcat 10 on Ubuntu 24.04)

### EC2 (Ubuntu 24.04) — run as `root`

```bash
sudo -i
set -euo pipefail

apt-get install -y tomcat10
systemctl enable --now tomcat10
systemctl status --no-pager tomcat10
```

---

## 7) EC2: Deploy ORDS to Tomcat

### EC2 (Ubuntu 24.04) — run as `root`

1) Locate ORDS WAR (one of these will exist, depending on packaging):

```bash
sudo -i
set -euo pipefail

ls -la /opt/ords/product/ords-24.3 | sed -n '1,80p'
ls -la /opt/ords/product/ords-24.3/*.war 2>/dev/null || true
ls -la /opt/ords/product/ords-24.3/ords.war 2>/dev/null || true
```

2) Deploy `ords.war` into Tomcat:

```bash
sudo -i
set -euo pipefail

# Adjust this if your ORDS war file is in a different location/name.
ORDS_WAR_SRC='/opt/ords/product/ords-24.3/ords.war'
test -f "$ORDS_WAR_SRC"

install -o root -g root -m 0644 "$ORDS_WAR_SRC" /var/lib/tomcat10/webapps/ords.war
```

3) Point Tomcat to the ORDS config directory:

On Ubuntu Tomcat packages, set JVM options in `/etc/default/tomcat10`.

```bash
sudo -i
set -euo pipefail

grep -n 'JAVA_OPTS' /etc/default/tomcat10 || true

# Add ORDS config location (append, do not overwrite any existing options).
if ! grep -q 'config.url=/opt/ords/config' /etc/default/tomcat10; then
  printf '\n# ORDS config directory\nJAVA_OPTS="$JAVA_OPTS -Dconfig.url=/opt/ords/config"\n' >> /etc/default/tomcat10
fi

systemctl restart tomcat10
systemctl status --no-pager tomcat10
```

---

## 8) Smoke test

### EC2 (Ubuntu 24.04) — run as any user

```bash
set -euo pipefail

# Local check on EC2
curl -fsS -I http://127.0.0.1:8080/ords/ | head -n 20
```

### From your laptop (if security group allows)

- `http://80.238.234.247:8080/ords/`

---

## RESET / ROLLBACK (DESTRUCTIVE — read before running)

These commands remove ORDS/Tomcat from EC2 and (optionally) remove ORDS schemas from PDB1.

### A) EC2 reset (Ubuntu): remove Tomcat + ORDS files

#### EC2 — run as `root`

```bash
sudo -i
set -euo pipefail

# Stop services first
systemctl stop tomcat10 || true

# Remove Tomcat (package-managed)
apt-get purge -y tomcat10 tomcat10-common || true
apt-get autoremove -y || true

# Remove ORDS deployment/config directories
rm -rf /opt/ords

# Optional: remove dedicated user
userdel ords 2>/dev/null || true
```

### B) EC1 reset (DB): remove ORDS database objects (ONLY if you must)

**WARNING:** This is destructive and should be done only if you are sure ORDS objects should be removed.

#### EC1 — run as `oracle` OS user

```bash
sudo -iu oracle
set -euo pipefail

sqlplus -L / as sysdba <<'SQL'
whenever sqlerror exit 1
set pages 200 lines 200

alter session set container = PDB1;

-- Identify ORDS users first (review output before dropping anything):
col username format a30
select username from dba_users where username like 'ORDS%' order by 1;

-- Identify ORDS roles first (review output before dropping anything):
col role format a40
select role from dba_roles where role like 'ORDS%' order by 1;

prompt
prompt If you decide to DROP, uncomment the following statements and re-run:
prompt

-- drop user ORDS_PUBLIC_USER cascade;
-- drop user ORDS_METADATA cascade;
-- drop role ORDS_ADMINISTRATOR_ROLE;

exit
SQL
```

If you prefer the Oracle-supported uninstall path, run ORDS' uninstall procedure from EC2 after installation (per the 24.3 ORDS documentation) instead of manual drops.

