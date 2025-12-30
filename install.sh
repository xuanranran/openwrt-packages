#!/bin/sh

set -e

# Define color codes and output functions
RED='\033[1;31m'
GREEN='\033[1;32m'
RESET='\033[0m'

msg_red()   { printf "${RED}%b${RESET}\n" "$*"; }
msg_green() { printf "${GREEN}%b${RESET}\n" "$*"; }

msg_green "\nInstall luci-app-clouddrive2"
msg_green "LuCI support for CloudDrive2\n"

# Parse gh_proxy from $1 if provided, e.g. gh_proxy="https://gh-proxy.com/"
gh_proxy=""
if [ -n "$1" ]; then
    case "$1" in
        gh_proxy=*)
            gh_proxy="${1#gh_proxy=}"
            # ensure gh_proxy ends with /
            [ -n "$gh_proxy" ] && case "$gh_proxy" in
                */) : ;;
                *) gh_proxy="$gh_proxy/" ;;
            esac
            ;;
    esac
fi

# Check if running on OpenWrt
if [ ! -f /etc/openwrt_release ]; then
    msg_red "Unknown OpenWrt Version."
    exit 1
fi

# Read architecture information
. /etc/openwrt_release
DISTRIB_ARCH="${DISTRIB_ARCH:-unknown}"

# Detect package manager and set SDK version
if [ -x "/usr/bin/apk" ]; then
    PKG_MANAGER="apk"
    PKG_OPT="add --allow-untrusted"
    # Use generic names for now, or match build.yml
    if echo "$DISTRIB_ARCH" | grep -q "x86_64"; then
        SDK="x86_64-SNAPSHOT"
    elif echo "$DISTRIB_ARCH" | grep -q "aarch64_generic"; then
        SDK="rockchip-SNAPSHOT"
    elif echo "$DISTRIB_ARCH" | grep -q "arm_cortex-a7"; then
        SDK="armv7-SNAPSHOT"
    else
        msg_red "Unsupported architecture for apk: $DISTRIB_ARCH"
        exit 1
    fi
elif command -v opkg >/dev/null 2>&1; then
    PKG_MANAGER="opkg"
    PKG_OPT="install --force-downgrade"
    if echo "$DISTRIB_ARCH" | grep -q "x86_64"; then
        SDK="x86_64-openwrt-24.10"
    elif echo "$DISTRIB_ARCH" | grep -q "aarch64_generic"; then
        SDK="rockchip-openwrt-24.10"
    elif echo "$DISTRIB_ARCH" | grep -q "arm_cortex-a7"; then
        SDK="armv7-openwrt-24.10"
    else
        msg_red "Unsupported architecture for opkg: $DISTRIB_ARCH"
        exit 1
    fi
else
    msg_red "No supported package manager found."
    exit 1
fi

# Check LuCI version compatibility
if [ ! -d "/usr/share/luci/menu.d" ]; then
    msg_red "The current OpenWrt LuCI version is not supported or \`luci-base\` is not installed."
    msg_red "The minimum required OpenWrt version is openwrt-21.02 or higher (i.e., LuCI2)."
    exit 1
fi

# Check available root partition space (at least 20MiB required)
ROOT_SPACE=$(df -m /usr | awk 'END{print $4}')
if [ "$ROOT_SPACE" -lt 20 ]; then
    msg_red "Error: The system storage space is less than 20MiB."
    exit 1
fi

# Create temporary directory and set up cleanup on exit
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

# Check if the current platform is supported
msg_green "Checking platform..."

SUPPORTED_PLATFORMS="
aarch64_generic
arm_cortex-a7
x86_64
"

FOUND=0
for arch in $SUPPORTED_PLATFORMS; do
    if [ "$DISTRIB_ARCH" = "$arch" ]; then
        FOUND=1
        break
    fi
done

if [ "$FOUND" -ne 1 ]; then
    # Loose check for x86_64
    if echo "$DISTRIB_ARCH" | grep -q "x86_64"; then
        FOUND=1
    else
         msg_red "Error! The current \"$DISTRIB_ARCH\" platform is not supported."
         exit 1
    fi
fi

# Download the corresponding package archive
# NOTE: Using simplified names matched in build.yml
PKG_FILE="$SDK.tar.gz"
BASE_URL="https://github.com/xuanranran/openwrt-clouddrive2/releases/latest/download/$PKG_FILE"
if [ -n "$gh_proxy" ]; then
    PKG_URL="${gh_proxy}${BASE_URL}"
else
    PKG_URL="$BASE_URL"
fi

msg_green "Downloading $PKG_URL ..."
if ! curl --connect-timeout 30 -m 300 -kLo "$TEMP_DIR/$PKG_FILE" "$PKG_URL"; then
    msg_red "Download $PKG_FILE failed."
    exit 1
fi

# Stop clouddrive2 service
if [ -x "/etc/init.d/clouddrive2" ]; then
    /etc/init.d/clouddrive2 stop || true
fi

# Extract and install packages
msg_green "\nInstalling Packages ..."
tar -zxf "$TEMP_DIR/$PKG_FILE" -C "$TEMP_DIR/"
for pkg in "$TEMP_DIR"/clouddrive2*.* \
           "$TEMP_DIR"/luci-app-clouddrive2*.* \
           "$TEMP_DIR"/luci-i18n-clouddrive2-zh-cn*.*; do
    [ -f "$pkg" ] && $PKG_MANAGER $PKG_OPT $pkg
done

# Clean up temporary files and finish
rm -rf /tmp/luci-*

# Start clouddrive2 service
if [ -x "/etc/init.d/clouddrive2" ]; then
    /etc/init.d/clouddrive2 start || true
fi

msg_green "Done!"
