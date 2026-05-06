# Proxmox LXC Dev Environment

This session contains a community-scripts-style Proxmox LXC helper pair for a Debian development container with Docker, Python tooling, `uv`, and Node.js LTS via `nvm`.

## Files

| Path | Purpose |
| --- | --- |
| `ct/dev-env.sh` | Proxmox host-side LXC creation script. Uses the vendored Docker installer, then installs Python/uv/Node tooling with `pct exec`. |
| `misc/` | Vendored community-scripts runtime functions with raw URLs rewritten to this repository. |
| `install/docker-install.sh` | Vendored Docker installer used by `build.func` through `var_install="docker-install"`. |
| `install/dev-env-install.sh` | Repo-ready in-container installer variant if you decide to maintain this as a full two-file script later. The current `ct/dev-env.sh` does not depend on this file. |

## Execution Model

`ct/dev-env.sh` is designed to run from:

```text
https://raw.githubusercontent.com/cjjjjjin/proxmox-script/main/outputs/ct/dev-env.sh
```

By default it sets:

```bash
SCRIPT_REPO_BASE="https://raw.githubusercontent.com/cjjjjjin/proxmox-script/main/outputs"
```

All vendored runtime fetches should resolve under that base URL.

It works by:

1. Loading `misc/build.func` from this repository.
2. Using this repository's `install/docker-install.sh` for Docker, Portainer, and Docker TCP socket prompts.
3. Running a post-Docker `pct exec` step to install Python tooling, `uv`, `nvm`, and Node.js LTS.

You can override the raw base URL for testing another branch or fork:

```bash
SCRIPT_REPO_BASE='https://raw.githubusercontent.com/cjjjjjin/proxmox-script/my-branch/outputs' \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/cjjjjjin/proxmox-script/main/outputs/ct/dev-env.sh)"
```

## Root Password Automation

To predefine the root password without editing the script:

```bash
DEV_ENV_ROOT_PASSWORD='your-password' \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/cjjjjjin/proxmox-script/main/outputs/ct/dev-env.sh)"
```

Passwords containing spaces are rejected to match the upstream password handling constraints.

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
