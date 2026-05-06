#!/usr/bin/env bash
SCRIPT_REPO_BASE="${SCRIPT_REPO_BASE:-https://raw.githubusercontent.com/cjjjjjin/proxmox-script/main/outputs}"
source <(curl -fsSL "${SCRIPT_REPO_BASE}/misc/build.func")
# Copyright (c) 2026
# License: MIT
# Source: https://github.com/cjjjjjin/proxmox-script

APP="Dev-Env"
var_tags="${var_tags:-docker;python;node;development}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-16}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors
var_install="docker-install"

DEV_ENV_ROOT_PASSWORD="${DEV_ENV_ROOT_PASSWORD:-debian}"
if [[ -n "${DEV_ENV_ROOT_PASSWORD:-}" ]]; then
  if [[ "$DEV_ENV_ROOT_PASSWORD" == *" "* ]]; then
    msg_error "DEV_ENV_ROOT_PASSWORD cannot contain spaces."
    exit 1
  fi
  PW="--password $DEV_ENV_ROOT_PASSWORD"
fi

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  msg_info "Updating base system"
  $STD apt update
  $STD apt upgrade -y
  msg_ok "Base system updated"

  msg_info "Updating Docker Engine"
  $STD apt install --only-upgrade -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin
  msg_ok "Docker Engine updated"

  if command -v uv >/dev/null 2>&1; then
    msg_info "Updating uv"
    $STD uv self update
    msg_ok "uv updated"
  fi

  if [[ -s /root/.nvm/nvm.sh ]]; then
    msg_info "Updating Node.js LTS via nvm"
    source /root/.nvm/nvm.sh
    $STD nvm install --lts
    $STD nvm alias default 'lts/*'
    msg_ok "Node.js LTS updated"
  fi

  if docker ps -a --format '{{.Image}}' | grep -q '^portainer/portainer-ce:latest$'; then
    msg_info "Updating Portainer"
    $STD docker pull portainer/portainer-ce:latest
    $STD docker stop portainer
    $STD docker rm portainer
    $STD docker volume create portainer_data >/dev/null 2>&1
    $STD docker run -d \
      -p 8000:8000 \
      -p 9443:9443 \
      --name=portainer \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:latest
    msg_ok "Updated Portainer"
  fi

  if docker ps -a --format '{{.Names}}' | grep -q '^portainer_agent$'; then
    msg_info "Updating Portainer Agent"
    $STD docker pull portainer/agent:latest
    $STD docker stop portainer_agent
    $STD docker rm portainer_agent
    $STD docker run -d \
      -p 9001:9001 \
      --name=portainer_agent \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /var/lib/docker/volumes:/var/lib/docker/volumes \
      portainer/agent
    msg_ok "Updated Portainer Agent"
  fi

  msg_ok "Updated successfully!"
  exit
}

function install_dev_tools_after_docker() {
  local _ctid="${CTID:-${CT_ID:-}}"

  if [[ -z "$_ctid" ]]; then
    msg_error "Unable to determine CTID for post-Docker development tooling install."
    exit 1
  fi

  msg_info "Installing Python tooling, uv, and Node.js LTS"
  $STD pct exec "$_ctid" -- bash -c '
set -e

apt-get update
apt-get install -y \
  build-essential \
  ca-certificates \
  curl \
  git \
  jq \
  pipx \
  python3 \
  python3-pip \
  python3-venv \
  sudo \
  unzip \
  wget

curl -LsSf https://astral.sh/uv/install.sh | sh
ln -sf /root/.local/bin/uv /usr/local/bin/uv
ln -sf /root/.local/bin/uvx /usr/local/bin/uvx

export NVM_DIR="/root/.nvm"
NVM_VERSION="v0.40.3"
mkdir -p "$NVM_DIR"
curl -fsSL "https://github.com/nvm-sh/nvm/archive/refs/tags/${NVM_VERSION}.tar.gz" -o /tmp/nvm.tar.gz
tar -xzf /tmp/nvm.tar.gz -C "$NVM_DIR" --strip-components=1
rm -f /tmp/nvm.tar.gz
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "nvm.sh was not installed at $NVM_DIR/nvm.sh" >&2
  exit 127
fi
. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default "lts/*"
nvm use default

cat >/etc/profile.d/nvm.sh <<NVM_PROFILE
export NVM_DIR="/root/.nvm"
[ -s "/root/.nvm/nvm.sh" ] && . "/root/.nvm/nvm.sh"
[ -s "/root/.nvm/bash_completion" ] && . "/root/.nvm/bash_completion"
NVM_PROFILE

docker --version
docker compose version
python3 --version
uv --version
. /etc/profile.d/nvm.sh
node --version
npm --version
'
  msg_ok "Installed Python tooling, uv, and Node.js LTS"
}

start
build_container
install_dev_tools_after_docker
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Docker, Python tooling, uv, and Node.js LTS are installed in the container.${CL}"
echo -e "${INFO}${YW} If you installed Portainer, access it at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://${IP}:9443${CL}"
