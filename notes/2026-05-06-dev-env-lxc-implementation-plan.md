# Dev Env LXC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a community-scripts-style Proxmox LXC helper pair that creates a Debian development container with Docker, system Python tooling, `uv`, and Node.js LTS via `nvm`.

**Architecture:** The host-side script mirrors `community-scripts/ProxmoxVE/ct/docker.sh` and delegates container provisioning to an in-container installer. The installer mirrors `install/docker-install.sh`, then adds development tooling in explicit sections.

**Tech Stack:** Bash, Proxmox LXC helper conventions, Debian 13, Docker Engine, `uv`, `nvm`, Node.js LTS.

---

## File Structure

- `outputs/ct/dev-env.sh`: Host-side LXC creation entrypoint. Defines app metadata, resource defaults, update behavior, and calls the upstream-style `build_container` flow.
- `outputs/install/dev-env-install.sh`: In-container installer. Installs Docker, optional Portainer/Agent, optional Docker TCP socket, Python tooling, `uv`, `nvm`, Node.js LTS, and cleanup hooks.
- `outputs/README.md`: User-facing runbook with copy commands, expected installed tools, verification commands, and security notes.

## Task 1: Host-Side LXC Script

**Files:**
- Create: `outputs/ct/dev-env.sh`

- [ ] **Step 1: Create the host-side script**

Create `outputs/ct/dev-env.sh` with this content:

```bash
#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2026
# License: MIT
# Source: https://github.com/community-scripts/ProxmoxVE

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

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Docker, Python tooling, uv, and Node.js LTS are installed in the container.${CL}"
echo -e "${INFO}${YW} If you installed Portainer, access it at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://${IP}:9443${CL}"
```

- [ ] **Step 2: Syntax-check the host-side script**

Run:

```powershell
bash -n outputs/ct/dev-env.sh
```

Expected: no output and exit code `0`.

## Task 2: In-Container Installer Script

**Files:**
- Create: `outputs/install/dev-env-install.sh`

- [ ] **Step 1: Create the installer script**

Create `outputs/install/dev-env-install.sh` with this content:

```bash
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
```

- [ ] **Step 2: Syntax-check the installer script**

Run:

```powershell
bash -n outputs/install/dev-env-install.sh
```

Expected: no output and exit code `0`.

## Task 3: Usage Documentation

**Files:**
- Create: `outputs/README.md`

- [ ] **Step 1: Create the usage README**

Create `outputs/README.md` with this content:

```markdown
# Proxmox LXC Dev Environment

This session contains a community-scripts-style Proxmox LXC helper pair for a Debian development container with Docker, Python tooling, `uv`, and Node.js LTS via `nvm`.

## Files

| Path | Purpose |
| --- | --- |
| `ct/dev-env.sh` | Proxmox host-side LXC creation script. |
| `install/dev-env-install.sh` | In-container installer script. |

## Defaults

| Setting | Value |
| --- | --- |
| OS | Debian 13 |
| CPU | 2 cores |
| RAM | 4096 MB |
| Disk | 16 GB |
| Unprivileged | Yes |

## Installed Tools

- Docker Engine
- Docker Compose plugin
- Docker Buildx
- Optional Portainer or Portainer Agent
- Python 3 from Debian packages
- `python3-venv`, `python3-pip`, `pipx`
- `uv` and `uvx`
- `nvm`
- Node.js LTS and npm
- `git`, `curl`, `wget`, `jq`, `unzip`, `sudo`, `build-essential`

## Verification

Inside the container, run:

```bash
docker --version
docker compose version
python3 --version
uv --version
source /etc/profile.d/nvm.sh
node --version
npm --version
```

## Security Notes

Docker runs inside an unprivileged LXC by default, following the upstream community Docker script pattern.

Do not expose the Docker TCP socket unless you have a specific reason. Exposing Docker on `0.0.0.0:2375` is insecure on untrusted networks.
```

## Task 4: Final Verification

**Files:**
- Verify: `outputs/ct/dev-env.sh`
- Verify: `outputs/install/dev-env-install.sh`
- Verify: `outputs/README.md`

- [ ] **Step 1: Run syntax checks**

Run:

```powershell
bash -n outputs/ct/dev-env.sh
bash -n outputs/install/dev-env-install.sh
```

Expected: both commands exit `0` with no output.

- [ ] **Step 2: Inspect final files**

Run:

```powershell
Get-ChildItem -Recurse outputs | Select-Object FullName
```

Expected: output includes `outputs/ct/dev-env.sh`, `outputs/install/dev-env-install.sh`, and `outputs/README.md`.

## Self-Review

- Spec coverage: The plan covers host-side script, installer script, default resources, Docker, Python system tooling, `uv`, Node LTS via `nvm`, optional Portainer, optional Docker TCP socket, and README usage notes.
- Placeholder scan: No placeholders remain.
- Type/name consistency: The app name is consistently `Dev-Env`; file names are consistently `dev-env.sh` and `dev-env-install.sh`.
