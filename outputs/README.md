# Proxmox LXC Dev Environment

This session contains a community-scripts-style Proxmox LXC helper pair for a Debian development container with Docker, Python tooling, `uv`, and Node.js LTS via `nvm`.

## Files

| Path | Purpose |
| --- | --- |
| `ct/dev-env.sh` | Proxmox host-side LXC creation script. |
| `install/dev-env-install.sh` | In-container installer script. |

## Execution Model

These files are repo-ready community-scripts-style files. They are designed to be placed into a `community-scripts/ProxmoxVE`-style repository at matching paths:

- `ct/dev-env.sh`
- `install/dev-env-install.sh`

The host-side script sources upstream `misc/build.func`, and that function fetches the installer from the repository's `install/${app}-install.sh` path during container creation. If you run `ct/dev-env.sh` locally without hosting or adding the matching installer file to the same script repository flow, Proxmox will not be able to fetch `install/dev-env-install.sh`.

For a private fork, either merge both files into the fork and adjust the fetched `build.func`/installer source flow to the fork, or submit the pair through the normal community-scripts development flow.

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
