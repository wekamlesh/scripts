!/bin/bash
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

# ===== Configuration =====
TIMEZONE="Asia/Kolkata"
SSH_PORT="22"   # keep 22 unless you already changed it manually
# =========================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Root check
if [ "$(id -u)" -ne 0 ]; then
  error "This script must be run as root. Use sudo."
  exit 1
fi

log "Starting simple Debian server setup..."

# 1) Update + upgrade
log "Updating package lists..."
apt-get update -y

log "Upgrading packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold"

# 2) Install packages
log "Installing essential packages..."
apt-get install -y \
  sudo curl wget git vim nano htop \
  ufw fail2ban tzdata ca-certificates lsb-release \
  unattended-upgrades

# 3) Timezone
log "Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE" || true
log "Timezone now: $(timedatectl | grep -i 'Time zone' || true)"

# 4) UFW firewall (do NOT touch SSH config)
log "Configuring firewall (UFW)..."
ufw --force reset

# Allow SSH first (prevent lockout)
ufw allow "${SSH_PORT}/tcp" comment "SSH"

# Web ports
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"

ufw --force enable
log "✅ UFW enabled"
ufw status verbose || true

# 5) fail2ban (basic)
log "Configuring fail2ban..."
cat > /etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled = true
port = ${SSH_PORT}
maxretry = 5
bantime = 1h
findtime = 10m
EOF

systemctl enable --now fail2ban
log "✅ fail2ban enabled"

# 6) unattended upgrades (simple defaults)
log "Enabling unattended-upgrades..."
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

systemctl enable --now unattended-upgrades
log "✅ unattended-upgrades enabled"

# 7) Cleanup
log "Cleaning up..."
apt-get autoremove -y
apt-get clean

# 8) Final info
SERVER_IP="$(hostname -I | awk '{print $1}')"
OS_INFO="$(lsb_release -ds 2>/dev/null || echo "Debian")"

cat <<EOF

${GREEN}╔══════════════════════════════════════════════════════════╗
║                  🎉 SETUP COMPLETE! 🎉                   ║
╚══════════════════════════════════════════════════════════╝${NC}

${BLUE}📊 System Information:${NC}
- Operating System: ${GREEN}${OS_INFO}${NC}
- Hostname: ${GREEN}$(hostname)${NC}
- IP (local): ${GREEN}${SERVER_IP}${NC}
- Timezone: ${GREEN}${TIMEZONE}${NC}

${BLUE}🔌 Network / Access:${NC}
- SSH Port Allowed in UFW: ${GREEN}${SSH_PORT}${NC}
- HTTP/HTTPS Allowed: ${GREEN}80, 443${NC}

${BLUE}🛡️ Security:${NC}
- UFW: ${GREEN}✅ Enabled${NC}
- fail2ban: ${GREEN}✅ Enabled${NC}
- unattended-upgrades: ${GREEN}✅ Enabled${NC}

${YELLOW}Notes:${NC}
- This script does NOT modify your SSH server configuration.
- It only opens the SSH port in the firewall to avoid lockouts.

EOF

# 9) Connectivity test
log "Testing internet connectivity..."
if ping -c 2 1.1.1.1 &>/dev/null; then
  log "✅ Internet connectivity verified"
else
  warning "⚠️ Unable to ping 1.1.1.1 — check network"
fi

exit 0
