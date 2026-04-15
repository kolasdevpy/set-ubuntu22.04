#!/bin/bash
set -euo pipefail

# ============================================================
# DOCKER ENGINE SETUP FOR UBUNTU 24.04
# Installs: Docker CE, Buildx, Compose plugin
# Usage: sudo ./setup_docker.sh [username]

# wget https://raw.githubusercontent.com/kolasdevpy/set-ubuntu22.04/main/setup_docker.sh
# chmod +x setup_docker.sh
# sudo ./setup_docker.sh admin
# ============================================================

# 🎨 Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()  { echo -e "\n${BLUE}➤ $1${NC}"; }

# 🔒 Root check
[[ $EUID -ne 0 ]] && error "This script must be run as root."

# 📝 Defaults
TARGET_USER="${1:-${SUDO_USER:-$(ls -1 /home | grep -v '^lost\+found$' | head -n1)}}"
[[ -z "$TARGET_USER" ]] && error "Could not determine target user. Specify manually: $0 username"

export DEBIAN_FRONTEND=noninteractive

# ─────────────────────────────────────────────────────────────
# 1. Install prerequisites
# ─────────────────────────────────────────────────────────────
step "Installing prerequisites..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

# ─────────────────────────────────────────────────────────────
# 2. Add Docker's official GPG key
# ─────────────────────────────────────────────────────────────
step "Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# ─────────────────────────────────────────────────────────────
# 3. Add Docker repository
# ─────────────────────────────────────────────────────────────
step "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y

# ─────────────────────────────────────────────────────────────
# 4. Install Docker Engine
# ─────────────────────────────────────────────────────────────
step "Installing Docker Engine..."
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# ─────────────────────────────────────────────────────────────
# 5. Enable and start Docker service
# ─────────────────────────────────────────────────────────────
step "Enabling Docker service..."
systemctl enable --now docker

# ─────────────────────────────────────────────────────────────
# 6. Add user to docker group (no sudo for docker commands)
# ─────────────────────────────────────────────────────────────
step "Adding '$TARGET_USER' to 'docker' group..."
if id "$TARGET_USER" &>/dev/null; then
    usermod -aG docker "$TARGET_USER"
    info "✅ User '$TARGET_USER' added to 'docker' group"
    warn "⚠️  IMPORTANT: Log out and back in (or run 'newgrp docker') for changes to apply"
else
    warn "⚠️  User '$TARGET_USER' not found. Run manually later: sudo usermod -aG docker <username>"
fi

# ─────────────────────────────────────────────────────────────
# 7. Verify installation
# ─────────────────────────────────────────────────────────────
step "Verifying Docker installation..."
docker --version
docker compose version

# Test docker socket access (as root, so this should always work)
if docker info &>/dev/null; then
    info "✅ Docker daemon is running and accessible"
else
    error "Docker daemon check failed"
fi

# ─────────────────────────────────────────────────────────────
# ✅ Final summary
# ─────────────────────────────────────────────────────────────
echo -e "\n${GREEN}🎉 Docker setup complete!${NC}"
echo "🔹 Docker: $(docker --version)"
echo "🔹 Compose: $(docker compose version)"
echo -e "💡 ${YELLOW}For '$TARGET_USER' to run docker without sudo: re-login or run 'newgrp docker'${NC}"
echo -e "💡 Test with: ${YELLOW}docker run hello-world${NC}"
echo "------------------------------"
echo "run ⚠️  sudo usermod -aG docker admin"
echo "run ⚠️  newgrp docker"
