#!/bin/bash
###############################################################################
# Script: 03-install-tomcat.sh
# Purpose: Install Apache Tomcat 9
# Server: EC2 (80.238.234.247) - Ubuntu 24.04
# Run as: root
###############################################################################
set -eo pipefail

echo "=============================================="
echo "Apache Tomcat 9 Installation"
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

TOMCAT_VERSION="9.0.113"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
TOMCAT_HOME="/opt/tomcat"

echo ""
log_info "Step 1: Creating tomcat user..."
if id tomcat &>/dev/null; then
    log_info "Tomcat user already exists ✓"
else
    useradd -r -m -U -d /opt/tomcat -s /bin/false tomcat
    log_info "Tomcat user created ✓"
fi

echo ""
log_info "Step 2: Downloading Tomcat ${TOMCAT_VERSION}..."
cd /tmp

if [[ -f "apache-tomcat-${TOMCAT_VERSION}.tar.gz" ]]; then
    log_info "Tomcat archive already downloaded ✓"
else
    wget -q --show-progress "$TOMCAT_URL"
    log_info "Tomcat downloaded ✓"
fi

echo ""
log_info "Step 3: Extracting Tomcat..."
rm -rf $TOMCAT_HOME/*
tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/tomcat --strip-components=1
log_info "Tomcat extracted to $TOMCAT_HOME ✓"

echo ""
log_info "Step 4: Setting permissions..."
chown -R tomcat:tomcat $TOMCAT_HOME
chmod +x $TOMCAT_HOME/bin/*.sh
log_info "Permissions set ✓"

echo ""
log_info "Step 5: Creating Tomcat environment file..."
cat > $TOMCAT_HOME/bin/setenv.sh << 'EOF'
#!/bin/bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export CATALINA_HOME=/opt/tomcat
export CATALINA_BASE=/opt/tomcat
export CATALINA_PID=/opt/tomcat/temp/tomcat.pid
export CATALINA_OPTS="-Xms512m -Xmx2048m -XX:+UseG1GC -Dconfig.url=/opt/ords/config"
EOF

chmod +x $TOMCAT_HOME/bin/setenv.sh
chown tomcat:tomcat $TOMCAT_HOME/bin/setenv.sh
log_info "Environment file created ✓"

echo ""
log_info "Step 6: Creating systemd service..."
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

log_info "Systemd service created ✓"

echo ""
log_info "Step 7: Enabling and starting Tomcat..."
systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat
sleep 5
log_info "Tomcat started ✓"

echo ""
log_info "Step 8: Verifying Tomcat..."
if systemctl is-active --quiet tomcat; then
    log_info "Tomcat service is running ✓"
else
    log_error "Tomcat service failed to start"
    systemctl status tomcat --no-pager
    exit 1
fi

# Test HTTP response
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200"; then
    log_info "Tomcat responding on port 8080 ✓"
else
    log_warn "Tomcat not responding on port 8080 yet (may need more time)"
fi

echo ""
log_info "=============================================="
log_info "Tomcat ${TOMCAT_VERSION} Installation Complete!"
log_info "=============================================="
echo ""
echo "Service Commands:"
echo "  Start:   systemctl start tomcat"
echo "  Stop:    systemctl stop tomcat"
echo "  Status:  systemctl status tomcat"
echo "  Logs:    tail -f /opt/tomcat/logs/catalina.out"
echo ""
log_info "Test URL: http://80.238.234.247:8080"
echo ""
log_info "Next: Run 04-install-ords.sh"
log_info "=============================================="
