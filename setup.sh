#!/bin/bash
# Debian Server Setup Script
# Creates or updates user 'tenzo' with sudo access, sets India timezone, prompts for password
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

# 3. Create or update user 'tenzo' and set/reset password
function set_user_password() {
    local username="$1"
    local action="$2" # "create" or "reset"
    
    while true; do
        echo -e "\n${BLUE}🔐 ${action^} password for user '$username':${NC}"
        echo -e "${YELLOW}Note: Password will not be visible while typing${NC}"
        
        # Read password without echo
        stty_orig=$(stty -g)
        stty -echo
        read -p "Enter password: " password1
        echo
        read -p "Confirm password: " password2
        echo
        stty "$stty_orig"
        
        if [ "$password1" != "$password2" ]; then
            error "❌ Passwords do not match. Please try again."
            continue
        fi
        
        if [ ${#password1} -lt 8 ]; then
            error "❌ Password must be at least 8 characters long. Please try again."
            continue
        fi
        
        if [ -z "$password1" ]; then
            error "❌ Password cannot be empty. Please try again."
            continue
        fi
        
        # Set the password
        echo "$username:$password1" | chpasswd
        unset password1 password2  # Clear passwords from memory
        log "✅ Password ${action} successfully for user $username."
        break
    done
}

if id "$USERNAME" &>/dev/null; then
    log "User $USERNAME already exists. Resetting password..."
    set_user_password "$USERNAME" "reset"
    
    # Ensure user is in sudo group
    if ! groups "$USERNAME" | grep -q '\bsudo\b'; then
        log "Adding existing user $USERNAME to sudo group..."
        usermod -aG sudo "$USERNAME"
        log "✅ User $USERNAME added to sudo group."
    else
        log "✅ User $USERNAME is already in sudo group."
    fi
else
    log "Creating user $USERNAME..."
    useradd -m -s /bin/bash "$USERNAME"
    set_user_password "$USERNAME" "create"
    
    log "Adding $USERNAME to sudo group..."
    usermod -aG sudo "$USERNAME"
    
    # Create .ssh directory
    mkdir -p "/home/$USERNAME/.ssh"
    chmod 700 "/home/$USERNAME/.ssh"
    chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
    
    log "✅ User $USERNAME created with sudo privileges."
fi

# 4. Configure SSH settings
log "Configuring SSH server..."
SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
mkdir -p "$SSH_CONFIG_DIR"

# Create custom SSH config
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

# 5. Configure firewall (UFW) - allow all IPs on SSH port 22
log "Configuring firewall (UFW)..."
ufw --force reset

# Allow SSH from all IPs on port 22
ufw allow "$SSH_PORT"/tcp comment "SSH Access - ALL IPs"

# Allow HTTP and HTTPS (common services)
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"

# Enable firewall
ufw --force enable
log "✅ Firewall configured and enabled"
log "Firewall status:"
ufw status verbose

# 6. Configure fail2ban for brute force protection
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
Unattended-Upgrade::Automatic-Reboot "false";
EOF

systemctl enable unattended-upgrades
systemctl start unattended-upgrades
log "✅ Automatic security updates enabled"

# 8. Clean up and optimize
log "Cleaning up package cache..."
apt autoremove -y
apt clean

# 9. Restart SSH service to apply changes
log "Restarting SSH service..."
systemctl restart sshd

# 10. Final verification and information display
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
- Password Status: ${GREEN}✅ ${$(id "$USERNAME" &>/dev/null && echo "Reset" || echo "Created")}${NC}

${BLUE}🔌 SSH Access:${NC}
- Port: ${GREEN}$SSH_PORT${NC}
- Access: ${YELLOW}⚠️ ALL IPs ALLOWED${NC}
- Connect Command: ${GREEN}ssh -p $SSH_PORT $USERNAME@$SERVER_IP${NC}

${BLUE}🛡️ Security Status:${NC}
- Firewall (UFW): ${GREEN}✅ Active${NC}
- Fail2ban: ${GREEN}✅ Active${NC}
- Auto Updates: ${GREEN}✅ Enabled${NC}

${YELLOW}⚠️  IMPORTANT SECURITY NOTES ⚠️${NC}
${RED}This server is configured with SSH access from ALL IPs!${NC}
${YELLOW}This is INSECURE for production environments. Consider:${NC}
1. ${GREEN}Restrict SSH access${NC} to your specific IP:
   ${BLUE}sudo ufw delete allow $SSH_PORT/tcp${NC}
   ${BLUE}sudo ufw allow from YOUR_IP_ADDRESS to any port $SSH_PORT${NC}
   
2. ${GREEN}Disable password authentication${NC} after setting up SSH keys:
   ${BLUE}sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config${NC}
   ${BLUE}sudo systemctl restart sshd${NC}

3. ${GREEN}Change your password${NC} regularly:
   ${BLUE}passwd${NC} (when logged in as $USERNAME)

${GREEN}✅ Verification Commands:${NC}
- Check sudo access: ${BLUE}sudo -l -U $USERNAME${NC}
- Check timezone: ${BLUE}timedatectl${NC}
- Check firewall: ${BLUE}sudo ufw status${NC}
- Check fail2ban: ${BLUE}sudo systemctl status fail2ban${NC}
- Test internet: ${BLUE}ping -c 4 google.com${NC}

${GREEN}🎉 Setup completed successfully at $(date)${NC}
${YELLOW}Thank you for using this setup script!${NC}
EOF

# Test connectivity
log "Testing internet connectivity..."
if ping -c 2 google.com &>/dev/null; then
    log "✅ Internet connectivity verified"
else
    warning "⚠️ Unable to ping google.com - check your network connection"
fi

exit 0
