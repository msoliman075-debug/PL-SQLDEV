#!/bin/bash
###############################################################################
# Script: 05-deploy-ords.sh
# Purpose: Deploy ORDS WAR to Tomcat and configure APEX images
# Server: EC2 (80.238.234.247) - Ubuntu 24.04
# Run as: root
###############################################################################
set -eo pipefail

echo "=============================================="
echo "ORDS Deployment to Tomcat"
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

TOMCAT_HOME="/opt/tomcat"
ORDS_HOME="/opt/ords"
ORDS_CONFIG="/opt/ords/config"

echo ""
log_info "Step 1: Stopping Tomcat..."
systemctl stop tomcat
sleep 3
log_info "Tomcat stopped ✓"

echo ""
log_info "Step 2: Extracting APEX images..."
APEX_ZIP=$(find /home/ubuntu/stage -name "apex*.zip" -type f 2>/dev/null | head -1)

if [[ -z "$APEX_ZIP" ]]; then
    log_warn "APEX zip not found in /home/ubuntu/stage/"
    log_warn "APEX images will not be available"
    log_warn "Please upload apex_24.2.zip for images to work"
else
    log_info "Found APEX file: $APEX_ZIP"
    
    # Extract APEX images
    mkdir -p /opt/ords/apex_images
    cd /home/ubuntu/stage
    unzip -oq "$APEX_ZIP" "apex/images/*"
    cp -r /home/ubuntu/stage/apex/images/* /opt/ords/apex_images/
    
    log_info "APEX images extracted ✓"
fi

echo ""
log_info "Step 3: Cleaning old deployments..."
rm -rf $TOMCAT_HOME/webapps/ords*
rm -rf $TOMCAT_HOME/webapps/i
rm -f $TOMCAT_HOME/conf/Catalina/localhost/ords.xml
log_info "Old deployments cleaned ✓"

echo ""
log_info "Step 4: Deploying ORDS WAR..."
cp $ORDS_HOME/ords.war $TOMCAT_HOME/webapps/ords.war
chown tomcat:tomcat $TOMCAT_HOME/webapps/ords.war
log_info "ORDS WAR deployed ✓"

echo ""
log_info "Step 5: Creating symbolic link for APEX images..."
ln -sf /opt/ords/apex_images $TOMCAT_HOME/webapps/i
chown -h tomcat:tomcat $TOMCAT_HOME/webapps/i
log_info "APEX images linked ✓"

echo ""
log_info "Step 6: Creating ORDS context configuration..."
mkdir -p $TOMCAT_HOME/conf/Catalina/localhost

cat > $TOMCAT_HOME/conf/Catalina/localhost/ords.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context docBase="${TOMCAT_HOME}/webapps/ords.war" path="/ords">
    <Parameter name="config.url" value="file://${ORDS_CONFIG}" override="false"/>
</Context>
EOF

chown tomcat:tomcat $TOMCAT_HOME/conf/Catalina/localhost/ords.xml
log_info "Context configuration created ✓"

echo ""
log_info "Step 7: Setting final permissions..."
chown -R tomcat:tomcat $ORDS_HOME
chown -R tomcat:tomcat $TOMCAT_HOME/webapps/
log_info "Permissions set ✓"

echo ""
log_info "Step 8: Starting Tomcat..."
systemctl start tomcat
log_info "Tomcat started ✓"

echo ""
log_info "Step 9: Waiting for deployment (30 seconds)..."
sleep 30

echo ""
log_info "Step 10: Verifying deployment..."

# Check if Tomcat is running
if systemctl is-active --quiet tomcat; then
    log_info "Tomcat service is running ✓"
else
    log_error "Tomcat service is not running!"
    systemctl status tomcat --no-pager
    exit 1
fi

# Check ORDS endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ords/ 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "302" ]]; then
    log_info "ORDS responding on /ords/ (HTTP $HTTP_CODE) ✓"
else
    log_warn "ORDS not responding yet (HTTP $HTTP_CODE)"
    log_warn "Check logs: tail -f /opt/tomcat/logs/catalina.out"
fi

# Check APEX images
if [[ -d "/opt/ords/apex_images" ]] && [[ -f "/opt/ords/apex_images/apex_version.txt" ]]; then
    log_info "APEX images available ✓"
else
    log_warn "APEX images may not be properly configured"
fi

echo ""
log_info "=============================================="
log_info "ORDS Deployment Complete!"
log_info "=============================================="
echo ""
echo "Access URLs:"
echo "  APEX:       http://80.238.234.247:8080/ords/apex"
echo "  APEX Admin: http://80.238.234.247:8080/ords/apex_admin"
echo "  ORDS Root:  http://80.238.234.247:8080/ords/"
echo ""
echo "APEX Login:"
echo "  Workspace: INTERNAL"
echo "  Username:  ADMIN"
echo "  Password:  Admin123!"
echo ""
echo "Useful Commands:"
echo "  View logs:     tail -f /opt/tomcat/logs/catalina.out"
echo "  Restart:       systemctl restart tomcat"
echo "  Check status:  systemctl status tomcat"
echo ""
log_info "=============================================="
