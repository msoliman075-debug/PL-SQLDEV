#!/bin/bash
###############################################################################
# Script: 02-install-jdk.sh
# Purpose: Install OpenJDK 17
# Server: EC2 (80.238.234.247) - Ubuntu 24.04
# Run as: root
###############################################################################
set -eo pipefail

echo "=============================================="
echo "OpenJDK 17 Installation"
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
log_info "Step 1: Installing OpenJDK 17..."
apt install -y openjdk-17-jdk
log_info "OpenJDK 17 installed ✓"

echo ""
log_info "Step 2: Setting JAVA_HOME..."

# Add to /etc/environment
if ! grep -q "JAVA_HOME" /etc/environment; then
    echo 'JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"' >> /etc/environment
fi

# Create profile script for all users
cat > /etc/profile.d/java.sh << 'EOF'
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
EOF

chmod +x /etc/profile.d/java.sh
source /etc/profile.d/java.sh

log_info "JAVA_HOME configured ✓"

echo ""
log_info "Step 3: Verifying installation..."
echo ""
echo "Java Version:"
java -version
echo ""
echo "Java Compiler Version:"
javac -version
echo ""
echo "JAVA_HOME: $JAVA_HOME"

echo ""
log_info "=============================================="
log_info "JDK 17 Installation Complete!"
log_info ""
log_info "Next: Run 03-install-tomcat.sh"
log_info "=============================================="
