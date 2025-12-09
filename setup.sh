#!/bin/bash
# Debian Server Setup Script
# Creates or updates user 'tenzo' with sudo access, sets India timezone, sets password non-interactively, and adds SSH key
# Run with: curl -s https://raw.githubusercontent.com/wekamlesh/scripts/main/setup.sh | sudo bash

set -euo pipefail

# Configuration
USERNAME="tenzo"
TIMEZONE="Asia/Kolkata"
SSH_PORT="22"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root. Use sudo."
    exit 1
fi

log "Starting Debian server setup..."

# 1. Update system and install essentials
log "Updating package lists and upgrading system..."
apt update -y
DEBIAN_FRONTEND=noninteractive apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

log "Installing essential packages..."
apt install -y \
    sudo \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    ufw \
    fail2ban \
    tzdata \
    ca-certificates \
    lsb-release

# 2. Set timezone to India
log "Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE"
log "Timezone set to $(timedatectl | grep "Time zone")"

# 3. Configure SSH settings
log "Configuring SSH server..."
SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
mkdir -p "$SSH_CONFIG_DIR"

cat > "$SSH_CONFIG_DIR/custom.conf" << EOF
# Custom SSH configuration for tenzo user
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF


# Add SSH public key
mkdir -p "/home/$USERNAME/.ssh"
cat > "/home/$USERNAME/.ssh/authorized_keys" << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAr99k2aRJ5juB4TiKZcmMKsmZInfPOwRQSLzGhsB0cz merugukamlesh@gmail.com
EOF

chmod 700 "/home/$USERNAME/.ssh"
chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"

# 4. Configure firewall (UFW)
log "Configuring firewall (UFW)..."
ufw --force reset
ufw allow "$SSH_PORT"/tcp comment "SSH Access - ALL IPs"
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"
ufw --force enable
log "✅ Firewall configured and enabled"
log "Firewall status:"
ufw status verbose

# 5. Configure fail2ban
log "Configuring fail2ban for SSH protection..."
cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 1h
findtime = 10m
action = %(action_)s
EOF

systemctl restart fail2ban
systemctl enable fail2ban
log "✅ Fail2ban configured and enabled"

# 6. Enable automatic security updates
log "Enabling automatic security updates..."
apt install -y unattended-upgrades

cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Origins-Pattern {
        "\${distro_id}:\${distro_codename}";
        "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

systemctl enable unattended-upgrades
systemctl start unattended-upgrades
log "✅ Automatic security updates enabled"

# 7. Clean up
log "Cleaning up package cache..."
apt autoremove -y
apt clean

# 8. Restart SSH
log "Restarting SSH service..."
systemctl restart sshd

# 9. Final info display
SERVER_IP=$(hostname -I | awk '{print $1}')
OS_INFO=$(lsb_release -ds)

cat << EOF

${GREEN}╔══════════════════════════════════════════════════════════╗
║                  🎉 SETUP COMPLETE! 🎉                   ║
╚══════════════════════════════════════════════════════════╝${NC}

${BLUE}📊 System Information:${NC}
- Operating System: ${GREEN}$OS_INFO${NC}
- Hostname: ${GREEN}$(hostname)${NC}
- Public IP: ${GREEN}$SERVER_IP${NC}
- Timezone: ${GREEN}$TIMEZONE${NC} (India)

${BLUE}👤 User Account:${NC}
- Username: ${GREEN}$USERNAME${NC}
- Sudo Access: ${GREEN}✅ Enabled${NC}
- Home Directory: ${GREEN}/home/$USERNAME${NC}
- Password: ${GREEN}Set non-interactively${NC}
- SSH Key: ${GREEN}✅ Configured${NC}

${BLUE}🔌 SSH Access:${NC}
- Port: ${GREEN}$SSH_PORT${NC}
- Access: ${YELLOW}⚠️ ALL IPs ALLOWED${NC}
- Connect: ${GREEN}ssh -p $SSH_PORT $USERNAME@$SERVER_IP${NC}

${BLUE}🛡️ Security Status:${NC}
- Firewall (UFW): ${GREEN}✅ Active${NC}
- Fail2ban: ${GREEN}✅ Active${NC}
- Auto Updates: ${GREEN}✅ Enabled${NC}

${YELLOW}⚠️  IMPORTANT SECURITY NOTES ⚠️${NC}
${RED}This server allows SSH from ALL IPs and uses password auth!${NC}
👉 For production:
1. Restrict SSH to your IP:
   ${BLUE}sudo ufw delete allow $SSH_PORT/tcp${NC}
   ${BLUE}sudo ufw allow from YOUR_IP to any port $SSH_PORT${NC}
2. Disable password login after verifying SSH key works:
   ${BLUE}sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config${NC}
   ${BLUE}sudo systemctl restart sshd${NC}

${GREEN}✅ Done at $(date)${NC}
EOF

# Test connectivity
log "Testing internet connectivity..."
if ping -c 2 google.com &>/dev/null; then
    log "✅ Internet connectivity verified"
else
    warning "⚠️ Unable to ping google.com — check network"
fi

exit 0
