# Proxmox LXC Development Environment Design

## Goal

Create a community-scripts-style Proxmox LXC helper script that provisions a Debian-based development container with Docker, Python tooling, and Node.js tooling.

## Selected Approach

Use the existing `community-scripts/ProxmoxVE` Docker LXC scripts as the baseline:

- `ct/docker.sh` for the Proxmox host-side LXC creation flow.
- `install/docker-install.sh` for the in-container Docker installation flow.

The new script keeps the same two-file structure:

- `outputs/ct/dev-env.sh`
- `outputs/install/dev-env-install.sh`

This preserves the familiar Proxmox helper script flow while making the development-specific additions explicit and auditable.

## Container Defaults

- OS: Debian
- OS version: 13
- CPU: 2 cores
- RAM: 4096 MB
- Disk: 16 GB
- Unprivileged: enabled by default, matching the upstream Docker LXC script baseline.

## Installed Components

The in-container installer provisions:

- Docker Engine using Docker's official convenience installer, matching the upstream Docker script.
- Docker Compose plugin and Buildx via Docker Engine packaging.
- Optional Portainer or Portainer Agent, using the upstream prompt flow.
- Optional Docker TCP socket exposure, disabled by default.
- System Python packages from Debian: `python3`, `python3-venv`, `python3-pip`, `pipx`.
- Python project tooling: `uv`.
- Node.js tooling: `nvm`, then `nvm install --lts` and default alias to LTS.
- General development tools: `git`, `curl`, `wget`, `ca-certificates`, `build-essential`, `jq`, `unzip`, `sudo`.

## Python Policy

System Python is installed and remains the system default. `uv` is installed for project dependency management and virtual environments, but the script does not run `uv python install` automatically. Project-specific Python versions should be installed explicitly per project.

## Node Policy

The script installs `nvm` and then installs the latest Node.js LTS release. The default `node` command is configured through `nvm alias default 'lts/*'`.

## Safety Notes

Docker inside LXC depends on Proxmox container features such as nesting. This design follows the upstream Docker helper script's defaults and does not introduce privileged LXC by default.

Docker TCP socket exposure is intentionally optional and disabled by default because unauthenticated TCP access to Docker is equivalent to high-privilege control over the container.

## Deliverables

- Host-side LXC creation script.
- In-container installer script.
- Usage README with execution, verification, and security notes.

## Execution Constraint

The host-side script uses upstream `misc/build.func`. That function fetches the in-container installer from `install/${app}-install.sh` in the community-scripts repository flow. Therefore the deliverables are intended as repo-ready files placed at matching `ct/` and `install/` paths, not as a standalone local script pair.
