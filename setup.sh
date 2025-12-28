#!/bin/bash
# Simple Debian Server Setup – with Fail2Ban brute-force protection
# - update + upgrade
# - install core tools
# - set timezone
# - install and enable Fail2Ban
# - enable unattended upgrades

set -euo pipefail

TIMEZONE="Asia/Kolkata"

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

echo "Starting Debian server setup..."

# Update & Upgrade
echo "Updating packages..."
apt-get update -y
echo "Upgrading packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install basic tools + Fail2Ban
echo "Installing core packages and Fail2Ban..."
apt-get install -y sudo curl wget git vim nano htop tzdata ca-certificates lsb-release unattended-upgrades fail2ban

# Set timezone
echo "Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE" || true

# Configure Fail2Ban for basic SSH protection
echo "Configuring Fail2Ban..."
cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime = 3600
EOF

systemctl enable --now fail2ban

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

echo ""
echo "===== SETUP COMPLETE ====="
echo "Timezone: $TIMEZONE"
echo "Core tools installed"
echo "Fail2Ban enabled (SSH brute-force protection)"
echo "Unattended upgrades enabled"
echo "=========================="

# Test connectivity
echo "Testing internet connectivity..."
if ping -c 2 1.1.1.1 &>/dev/null; then
  echo "Internet connectivity: OK"
else
  echo "Internet connectivity: FAILED"
fi

exit 0
