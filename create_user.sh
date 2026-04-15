#!/bin/bash
set -euo pipefail

# 🎨 Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 🔒 Root check
[[ $EUID -ne 0 ]] && error "This script must be run as root."

# 📝 Defaults
USERNAME="${1:-admin}"
USER_UID="${2:-1000}"
ENABLE_NOPASSWD="${3:-false}"
USER_SHELL="/bin/bash"

# 🔍 Collect valid groups only
BASE_GROUPS=("sudo" "adm")
if getent group docker &>/dev/null; then
    BASE_GROUPS+=("docker")
    info "Docker group detected. Will add user to it."
fi
USER_GROUPS=$(IFS=,; echo "${BASE_GROUPS[*]}")

info "Creating user: $USERNAME (UID: $USER_UID)..."

# 🔍 Pre-checks
id "$USERNAME" &>/dev/null && error "User '$USERNAME' already exists."
getent passwd "$USER_UID" &>/dev/null && error "UID $USER_UID is already in use."

# 👤 Create user
useradd -m -u "$USER_UID" -s "$USER_SHELL" -G "$USER_GROUPS" "$USERNAME"
info "User '$USERNAME' created successfully."

# 🔑 Set password
info "Set password for '$USERNAME':"
passwd "$USERNAME"

# 📂 Copy SSH keys
if [[ -f /root/.ssh/authorized_keys ]]; then
    mkdir -p "/home/$USERNAME/.ssh"
    cp /root/.ssh/authorized_keys "/home/$USERNAME/.ssh/"
    chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
    chmod 700 "/home/$USERNAME/.ssh"
    chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
    info "SSH keys copied from root."
fi

# 🔓 NOPASSWD sudo
if [[ "$ENABLE_NOPASSWD" == "true" ]]; then
    SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    
    if visudo -cf "$SUDOERS_FILE" &>/dev/null; then
        info "NOPASSWD enabled for '$USERNAME'."
    else
        warn "Sudoers syntax check failed. NOPASSWD NOT applied."
        rm -f "$SUDOERS_FILE"
    fi
fi

# 📜 Docker post-install note
if ! getent group docker &>/dev/null; then
    warn "Docker is not installed yet. After installation, run:"
    warn "  sudo usermod -aG docker $USERNAME"
fi

echo -e "\n${GREEN}✅ Setup complete.${NC}"
echo "🔹 Login: ssh $USERNAME@<server_ip>"
echo "🔹 Docker CLI: будет работать без sudo после добавления в группу"
echo "🔹 System commands: sudo по-прежнему требуется (это норма)"
