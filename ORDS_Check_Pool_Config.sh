#!/bin/bash
################################################################################
# ORDS Pool Configuration Check
# This script helps identify why ORDS can't find the module
################################################################################

echo "=== ORDS Configuration Check ==="
echo ""

CONFIG_DIR="/opt/ords/config"

echo "1. Checking ORDS config directory structure..."
echo "------------------------------------------------"
if [ -d "$CONFIG_DIR" ]; then
    find "$CONFIG_DIR" -type f -name "*.xml" 2>/dev/null | head -20
    echo ""
else
    echo "Config directory not found at $CONFIG_DIR"
    echo "Trying alternative locations..."
    find /opt -name "pool.xml" 2>/dev/null | head -10
fi

echo ""
echo "2. Checking database pools..."
echo "------------------------------------------------"
if [ -d "$CONFIG_DIR/databases" ]; then
    ls -la "$CONFIG_DIR/databases/"
    echo ""
    for db in "$CONFIG_DIR/databases/"*/; do
        echo "Database: $db"
        if [ -d "${db}pools" ]; then
            ls -la "${db}pools/"
        fi
    done
else
    echo "No databases directory found"
fi

echo ""
echo "3. Looking for surety_api pool configuration..."
echo "------------------------------------------------"
POOL_FILE=$(find "$CONFIG_DIR" -name "*surety*" -type f 2>/dev/null | head -1)
if [ -n "$POOL_FILE" ]; then
    echo "Found: $POOL_FILE"
    echo "Contents:"
    cat "$POOL_FILE"
else
    echo "No surety-specific pool config found"
    echo ""
    echo "Checking default pool..."
    DEFAULT_POOL=$(find "$CONFIG_DIR" -name "pool.xml" -type f 2>/dev/null | head -1)
    if [ -n "$DEFAULT_POOL" ]; then
        echo "Found: $DEFAULT_POOL"
        cat "$DEFAULT_POOL"
    fi
fi

echo ""
echo "4. Checking ORDS settings..."
echo "------------------------------------------------"
SETTINGS_FILE="$CONFIG_DIR/global/settings.xml"
if [ -f "$SETTINGS_FILE" ]; then
    echo "Global settings:"
    cat "$SETTINGS_FILE"
else
    echo "No global settings.xml found"
fi

echo ""
echo "5. Check URL mappings..."
echo "------------------------------------------------"
URL_MAPPING=$(find "$CONFIG_DIR" -name "*url*" -o -name "*mapping*" 2>/dev/null | head -5)
if [ -n "$URL_MAPPING" ]; then
    for f in $URL_MAPPING; do
        echo "=== $f ==="
        cat "$f"
    done
else
    echo "No URL mapping files found"
fi

echo ""
echo "=== ORDS Command Line Config Check ==="
echo "Run these commands to see ORDS configuration:"
echo ""
echo "  cd /opt/ords"
echo "  ./ords config list"
echo "  ./ords config list --include-defaults"
echo ""
echo "Or check which database user ORDS connects as:"
echo "  ./ords config get db.username"
echo "  ./ords config get jdbc.InitialLimit"
