#!/bin/bash
################################################################################
# ORDS Restart and Debug Script
# Run this on your Linux server to restart ORDS and clear cache
################################################################################

echo "=== ORDS Restart and Debug ==="

# Option 1: If ORDS is running as standalone (most common for development)
echo ""
echo "Option 1: Restart Standalone ORDS"
echo "---------------------------------"
echo "1. Find ORDS process:"
echo "   ps aux | grep ords"
echo ""
echo "2. Kill ORDS process (replace PID):"
echo "   kill <PID>"
echo ""
echo "3. Restart ORDS:"
echo "   cd /opt/ords  # or your ORDS installation directory"
echo "   ./ords serve &"
echo ""
echo "   OR with specific config:"
echo "   ./ords --config /path/to/config serve &"

# Option 2: If ORDS is running under systemd
echo ""
echo "Option 2: Restart ORDS via systemd"
echo "-----------------------------------"
echo "   sudo systemctl restart ords"
echo "   sudo systemctl status ords"

# Option 3: If ORDS is deployed to Tomcat
echo ""
echo "Option 3: Restart Tomcat (if ORDS deployed there)"
echo "--------------------------------------------------"
echo "   sudo systemctl restart tomcat"
echo "   # OR"
echo "   sudo /opt/tomcat/bin/shutdown.sh"
echo "   sudo /opt/tomcat/bin/startup.sh"

# Option 4: If ORDS is deployed to WebLogic
echo ""
echo "Option 4: Restart WebLogic managed server"
echo "------------------------------------------"
echo "   # Use WebLogic console or WLST script"

# Check ORDS logs
echo ""
echo "=== Check ORDS Logs ==="
echo "Common log locations:"
echo "  - /opt/ords/logs/"
echo "  - /var/log/ords/"
echo "  - /opt/tomcat/logs/catalina.out"
echo ""
echo "Tail logs for errors:"
echo "  tail -100f /opt/ords/logs/ords.log"

echo ""
echo "=== Test After Restart ==="
echo "curl -v http://ai.suretysa.com:8080/ords/surety_api/surety/upload_policy/"
