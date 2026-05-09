#!/bin/bash
# Quick Cache Verification Script
# Uso: bash cache_verify.sh

echo "════════════════════════════════════════════════"
echo "   PROFILE PICTURE CACHE VERIFICATION SCRIPT"
echo "════════════════════════════════════════════════"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}[1/4]${NC} Checking Flutter environment..."
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}✗ Flutter not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Flutter found${NC}"
echo ""

echo -e "${BLUE}[2/4]${NC} Checking connected devices..."
adb devices | grep -E "emulator|device" &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠ No device/emulator connected${NC}"
    echo "Connect device and run: adb devices"
else
    device_count=$(adb devices | grep -E "emulator|device" | wc -l)
    echo -e "${GREEN}✓ Device(s) connected: $device_count${NC}"
fi
echo ""

echo -e "${BLUE}[3/4]${NC} Checking Firebase Storage structure..."
echo "Navigate to Firebase Console > Storage:"
echo "  Path: users/{userId}/profile_picture.jpg"
echo ""

echo -e "${BLUE}[4/4]${NC} Running app with verbose logging..."
echo "Logs containing 'ProfileViewModel:Cache' will show cache operations:"
echo ""

# Option to run with logs
read -p "Start app with cache logging? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Starting Flutter run...${NC}"
    echo "Watch for logs like:"
    echo "  🗑️  Removing old cache"
    echo "  ✅ Old cache removed successfully"
    echo "  📥 Pre-caching new image"
    echo "  ✅ Pre-cached successfully"
    echo ""
    flutter run -v 2>&1 | grep -E "ProfileViewModel|cache|Cache"
fi

echo ""
echo "════════════════════════════════════════════════"
echo "VERIFICATION COMPLETE"
echo "════════════════════════════════════════════════"

