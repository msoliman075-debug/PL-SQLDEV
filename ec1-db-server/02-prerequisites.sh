#!/bin/bash
###############################################################################
# Script: 02-prerequisites.sh
# Purpose: Install prerequisites for Oracle Database 19c
# Server: EC1 (80.238.214.217)
# Run as: root
###############################################################################
set -eo pipefail

echo "=============================================="
echo "Oracle Database 19c Prerequisites Setup"
echo "=============================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

echo ""
log_info "Step 1: Installing Oracle preinstall package..."
dnf install -y oracle-database-preinstall-19c

echo ""
log_info "Step 2: Installing additional required packages..."
dnf install -y bc binutils compat-openssl10 elfutils-libelf \
    elfutils-libelf-devel fontconfig-devel glibc glibc-devel \
    ksh libaio libaio-devel libX11 libXau libXi libXtst \
    libXrender libXrender-devel libgcc libstdc++ libstdc++-devel \
    libxcb make smartmontools sysstat unzip wget net-tools vim tar

echo ""
log_info "Step 3: Verifying and configuring oracle user..."
if id oracle &>/dev/null; then
    log_info "Oracle user exists ✓"
else
    log_info "Creating oracle user..."
    groupadd -g 54321 oinstall 2>/dev/null || true
    groupadd -g 54322 dba 2>/dev/null || true
    groupadd -g 54323 oper 2>/dev/null || true
    groupadd -g 54324 backupdba 2>/dev/null || true
    groupadd -g 54325 dgdba 2>/dev/null || true
    groupadd -g 54326 kmdba 2>/dev/null || true
    groupadd -g 54330 racdba 2>/dev/null || true
    useradd -u 54321 -g oinstall -G dba,oper,backupdba,dgdba,kmdba,racdba oracle
fi

# Ensure oracle is member of ALL required groups
log_info "Ensuring oracle user has all required groups..."
usermod -a -G oinstall,dba,oper,backupdba,dgdba,kmdba,racdba oracle

# Verify groups
id oracle

echo ""
log_info "Step 4: Creating Oracle directories..."
mkdir -p /u01/app/oracle/product/19.3.0/dbhome_1
mkdir -p /u01/app/oraInventory
mkdir -p /u02/oradata
mkdir -p /u02/fast_recovery_area
mkdir -p /home/oracle/stage

chown -R oracle:oinstall /u01
chown -R oracle:oinstall /u02
chown -R oracle:oinstall /home/oracle/stage
chmod -R 775 /u01
chmod -R 775 /u02

log_info "Directories created ✓"

echo ""
log_info "Step 5: Configuring kernel parameters..."
cat > /etc/sysctl.d/97-oracle-database-sysctl.conf << 'EOF'
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

sysctl -p /etc/sysctl.d/97-oracle-database-sysctl.conf
log_info "Kernel parameters configured ✓"

echo ""
log_info "Step 6: Configuring user limits..."
cat > /etc/security/limits.d/97-oracle-limits.conf << 'EOF'
oracle   soft   nofile    1024
oracle   hard   nofile    65536
oracle   soft   nproc    16384
oracle   hard   nproc    16384
oracle   soft   stack    10240
oracle   hard   stack    32768
oracle   soft   memlock    134217728
oracle   hard   memlock    134217728
EOF
log_info "User limits configured ✓"

echo ""
log_info "Step 7: Setting oracle user password..."
echo "oracle:Oracle_user_123" | chpasswd
log_info "Oracle user password set to: Oracle_user_123"

echo ""
log_info "Step 8: Creating oracle environment file..."
cat > /home/oracle/.bash_profile << 'EOF'
# .bash_profile
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
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

umask 022
EOF

chown oracle:oinstall /home/oracle/.bash_profile
log_info "Environment file created ✓"

echo ""
log_info "Step 9: Configuring firewall for remote access..."

# Ensure firewalld is running
systemctl start firewalld
systemctl enable firewalld

# Open Oracle listener port (remote DB connections)
firewall-cmd --permanent --add-port=1521/tcp

# Open Enterprise Manager Express port
firewall-cmd --permanent --add-port=5500/tcp

# Open additional ports if needed
firewall-cmd --permanent --add-port=5501/tcp

# Reload firewall to apply changes
firewall-cmd --reload

log_info "Firewall configured ✓"
echo ""
echo "Open ports:"
firewall-cmd --list-ports

echo ""
log_info "Step 10: Configuring SELinux..."
if getenforce | grep -q "Enforcing"; then
    setenforce 0
    sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
    log_info "SELinux set to permissive ✓"
else
    log_info "SELinux already permissive/disabled ✓"
fi

echo ""
log_info "=============================================="
log_info "Prerequisites installation complete!"
log_info ""
log_info "Next steps:"
log_info "1. Upload LINUX.X64_193000_db_home.zip to /home/oracle/stage/"
log_info "2. Upload apex_24.2.zip to /home/oracle/stage/"
log_info "3. Run 03-install-oracle.sh as oracle user"
log_info "=============================================="

echo ""
log_info "Verification Summary:"
echo "  Memory:     $(free -h | grep Mem | awk '{print $2}')"
echo "  Disk /u01:  $(df -h /u01 | tail -1 | awk '{print $4}') available"
echo "  Disk /u02:  $(df -h /u02 | tail -1 | awk '{print $4}') available"
