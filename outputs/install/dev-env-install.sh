#!/usr/bin/env bash

# Copyright (c) 2026
# License: MIT
# Source: https://github.com/community-scripts/ProxmoxVE

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

DOCKER_LATEST_VERSION=$(get_latest_github_release "moby/moby")
PORTAINER_LATEST_VERSION=$(get_latest_github_release "portainer/portainer")
PORTAINER_AGENT_LATEST_VERSION=$(get_latest_github_release "portainer/agent")

msg_info "Installing development dependencies"
$STD apt-get install -y \
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
msg_ok "Installed development dependencies"

msg_info "Installing Docker $DOCKER_LATEST_VERSION (with Compose, Buildx)"
DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
mkdir -p "$(dirname "$DOCKER_CONFIG_PATH")"
echo -e '{\n  "log-driver": "journald"\n}' >"$DOCKER_CONFIG_PATH"
$STD sh <(curl -fsSL https://get.docker.com)
msg_ok "Installed Docker $DOCKER_LATEST_VERSION"

read -r -p "${TAB3}Would you like to add Portainer (UI)? <y/N> " prompt
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  msg_info "Installing Portainer $PORTAINER_LATEST_VERSION"
  docker volume create portainer_data >/dev/null
  $STD docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name=portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
  msg_ok "Installed Portainer $PORTAINER_LATEST_VERSION"
else
  read -r -p "${TAB3}Would you like to install the Portainer Agent (for remote management)? <y/N> " prompt_agent
  if [[ ${prompt_agent,,} =~ ^(y|yes)$ ]]; then
    msg_info "Installing Portainer Agent $PORTAINER_AGENT_LATEST_VERSION"
    $STD docker run -d \
      -p 9001:9001 \
      --name portainer_agent \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /var/lib/docker/volumes:/var/lib/docker/volumes \
      portainer/agent
    msg_ok "Installed Portainer Agent $PORTAINER_AGENT_LATEST_VERSION"
  fi
fi

read -r -p "${TAB3}Expose Docker TCP socket (insecure) ? [n = No, l = Local only (127.0.0.1), a = All interfaces (0.0.0.0)] <n/l/a>: " socket_choice
case "${socket_choice,,}" in
l)
  socket="tcp://127.0.0.1:2375"
  ;;
a)
  socket="tcp://0.0.0.0:2375"
  ;;
*)
  socket=""
  ;;
esac

if [[ -n "$socket" ]]; then
  msg_info "Enabling Docker TCP socket on $socket"

  tmpfile=$(mktemp)
  jq --arg sock "$socket" '. + { "hosts": ["unix:///var/run/docker.sock", $sock] }' "$DOCKER_CONFIG_PATH" >"$tmpfile" && mv "$tmpfile" "$DOCKER_CONFIG_PATH"

  mkdir -p /etc/systemd/system/docker.service.d
  cat <<EOF >/etc/systemd/system/docker.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
EOF

  $STD systemctl daemon-reexec
  $STD systemctl daemon-reload

  if systemctl restart docker; then
    msg_ok "Docker TCP socket available on $socket"
  else
    msg_error "Docker failed to restart. Check journalctl -xeu docker.service"
    exit 150
  fi
fi

msg_info "Installing uv"
curl -LsSf https://astral.sh/uv/install.sh | sh
ln -sf /root/.local/bin/uv /usr/local/bin/uv
ln -sf /root/.local/bin/uvx /usr/local/bin/uvx
msg_ok "Installed uv"

msg_info "Installing nvm and Node.js LTS"
export NVM_DIR="/root/.nvm"
mkdir -p "$NVM_DIR"
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source "$NVM_DIR/nvm.sh"
$STD nvm install --lts
$STD nvm alias default 'lts/*'
$STD nvm use default
cat <<'EOF' >/etc/profile.d/nvm.sh
export NVM_DIR="/root/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
EOF
msg_ok "Installed Node.js LTS"

msg_info "Verifying development tools"
docker --version
docker compose version
python3 --version
uv --version
source /etc/profile.d/nvm.sh
node --version
npm --version
msg_ok "Verified development tools"

motd_ssh
customize
cleanup_lxc
