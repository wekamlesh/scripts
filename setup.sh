#!/bin/bash
# Simple Debian Server Setup (No colors, no extras)
# Updates system, installs essentials, configures UFW & fail2ban, sets timezone

set -euo pipefail

TIMEZONE="Asia/Kolkata"
SSH_PORT="22"

# Check for root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

echo "Starting Debian server setup..."

# Update & upgrade
echo "Updating packages..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install core packages
echo "Installing packages..."
apt-get install -y sudo curl wget git vim nano htop ufw fail2ban tzdata ca-certificates lsb-release unattended-upgrades

# Set timezone
echo "Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE" || true

# Configure UFW firewall
echo "Configuring UFW firewall..."
ufw --force reset
ufw allow "${SSH_PORT}/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
echo "UFW status:"
ufw status

# Configure fail2ban
echo "Configuring fail2ban..."
cat > /etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled = true
port = ${SSH_PORT}
maxretry = 5
bantime = 1h
findtime = 10m
EOF
systemctl enable --now fail2ban

# Enable unattended upgrades
echo "Setting up unattended upgrades..."
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now unattended-upgrades

# Cleanup
echo "Cleaning up..."
apt-get autoremove -y
apt-get clean

# Final summary
echo ""
echo "===== SETUP COMPLETE ====="
echo "Timezone: $TIMEZONE"
echo "SSH Port Allowed: $SSH_PORT"
echo "Firewall (UFW): enabled"
echo "fail2ban: enabled"
echo "unattended-upgrades: enabled"
echo "=========================="

# Test internet connectivity
echo "Testing internet connectivity..."
if ping -c 2 1.1.1.1 &>/dev/null; then
  echo "Internet connectivity verified."
else
  echo "Unable to verify internet connectivity."
fi

exit 0
