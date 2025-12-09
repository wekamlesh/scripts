#!/bin/bash
# Debian Server Setup Script
# Creates user 'tenzo' with sudo access, sets India timezone, prompts for password
# Run with: curl -s https://raw.githubusercontent.com/yourusername/yourrepo/main/setup.sh | sudo bash

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
    ca-certificates

# 2. Set timezone to India
log "Setting timezone to $TIMEZONE..."
echo "$TIMEZONE" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
log "Timezone set to $(timedatectl | grep "Time zone")"

# 3. Create user 'tenzo' and prompt for password
if id "$USERNAME" &>/dev/null; then
    warning "User $USERNAME already exists. Skipping user creation."
else
    log "Creating user $USERNAME..."
    useradd -m -s /bin/bash "$USERNAME"
    
    # Prompt for password securely
    while true; do
        echo -e "${BLUE}Please enter a password for user '$USERNAME':${NC}"
        read -s -p "Password: " password1
        echo
        read -s -p "Confirm password: " password2
        echo
        
        if [ "$password1" != "$password2" ]; then
            error "Passwords do not match. Please try again."
            continue
        fi
        
        if [ -z "$password1" ]; then
            error "Password cannot be empty. Please try again."
            continue
        fi
        
        # Set the password
        echo "$USERNAME:$password1" | chpasswd
        log "Password set successfully for user $USERNAME."
        break
    done
    
    log "Adding $USERNAME to sudo group..."
    usermod -aG sudo "$USERNAME"
    
    # Create .ssh directory
    mkdir -p "/home/$USERNAME/.ssh"
    chmod 700 "/home/$USERNAME/.ssh"
    chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
    
    log "User $USERNAME created with sudo privileges."
fi

# 4. Configure SSH settings
log "Configuring SSH server..."
SSH_CONFIG="/etc/ssh/sshd_config"

# Backup original config
cp "$SSH_CONFIG" "$SSH_CONFIG.bak"

# Configure SSH settings
cat > /etc/ssh/sshd_config.d/custom.conf << EOF
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

# Allow password authentication
PasswordAuthentication yes
EOF

# 5. Configure firewall (UFW) - allow all IPs on SSH port 22
log "Configuring firewall (UFW)..."
ufw --force reset

# Allow SSH from all IPs on port 22
ufw allow "$SSH_PORT"/tcp comment "SSH Access - ALL IPs"

# Allow HTTP and HTTPS
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"

# Enable firewall
ufw --force enable
log "Firewall status:"
ufw status verbose

# 6. Configure fail2ban for brute force protection
log "Configuring fail2ban..."
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

# 7. Enable automatic security updates
log "Enabling automatic security updates..."
apt install -y unattended-upgrades

cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Origins-Pattern {
        "\${distro_id}:\${distro_codename}";
        "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# 8. Clean up and optimize
log "Cleaning up package cache..."
apt autoremove -y
apt clean

# 9. Restart SSH service
log "Restarting SSH service..."
systemctl restart sshd

# 10. Display important information
SERVER_IP=$(hostname -I | awk '{print $1}')

cat << EOF

${GREEN}=== SETUP COMPLETE ===${NC}

${BLUE}User Account:${NC}
- Username: ${GREEN}$USERNAME${NC}
- Sudo access: ${GREEN}Enabled${NC}

${BLUE}Server Details:${NC}
- IP Address: ${GREEN}$SERVER_IP${NC}
- SSH Port: ${GREEN}$SSH_PORT${NC}
- Timezone: ${GREEN}$TIMEZONE${NC}
- Connect command: ${GREEN}ssh -p $SSH_PORT $USERNAME@$SERVER_IP${NC}

${YELLOW}🛡️  SECURITY RECOMMENDATIONS${NC}
1. ${RED}This server allows SSH access from ALL IPs${NC} - consider restricting to your IP only:
   ${GREEN}sudo ufw delete allow $SSH_PORT/tcp${NC}
   ${GREEN}sudo ufw allow from YOUR_IP_ADDRESS to any port $SSH_PORT${NC}
2. ${RED}Disable password authentication${NC} after setting up SSH keys:
   ${GREEN}sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config${NC}
   ${GREEN}sudo systemctl restart sshd${NC}
3. ${RED}Enable 2FA${NC} for SSH access

${YELLOW}✅ Verification Commands:${NC}
- Check sudo access: ${GREEN}sudo -l -U $USERNAME${NC}
- Check timezone: ${GREEN}timedatectl${NC}
- Check firewall: ${GREEN}sudo ufw status${NC}
- Check fail2ban: ${GREEN}sudo systemctl status fail2ban${NC}

${GREEN}Setup completed successfully at $(date)${NC}
EOF

exit 0
