#!/bin/bash
# Simple Debian Server Setup Script (SAFE / Debian-only)
# - Updates system
# - Installs essentials (sudo, ufw, fail2ban, unattended-upgrades, etc.)
# - Sets timezone to Asia/Kolkata
# - Enables UFW (allows SSH/HTTP/HTTPS)
# - Enables fail2ban (basic SSH jail)
# - Enables unattended upgrades
#
# Run with:
# curl -fsSL https://raw.githubusercontent.com/wekamlesh/scripts/main/setup.sh | sudo bash

set -euo pipefail

TIMEZONE="Asia/Kolkata"

# Ensure running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

echo "Starting minimal Debian server setup..."

# Update and upgrade
echo "Updating package lists..."
apt-get update -y
echo "Upgrading packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install basic tools
echo "Installing core packages..."
apt-get install -y sudo curl wget git vim nano htop tzdata ca-certificates lsb-release unattended-upgrades podman podman-compose

# Set timezone
echo "Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE" || true

# Enable unattended upgrades
echo "Configuring unattended upgrades..."
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now unattended-upgrades

# Cleanup
echo "Cleaning up..."
apt-get autoremove -y
apt-get clean

# Summary
echo ""
echo "===== SETUP COMPLETE ====="
echo "Timezone set: $TIMEZONE"
echo "Basic packages installed"
echo "Unattended upgrades enabled"
echo "=========================="

# Internet connectivity test
echo "Testing internet connectivity..."
if ping -c 2 1.1.1.1 &>/dev/null; then
  echo "Internet connectivity: OK"
else
  echo "Internet connectivity: FAILED"
fi

exit 0
