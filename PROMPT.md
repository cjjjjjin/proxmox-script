# Resume Prompt

We are designing a Proxmox LXC helper script for a development container with Docker, Python, and Node.js.

Current confirmed context:
- Workspace session: `260506_proxmox_lxc_dev_env`
- Session goal: create an auditable script and usage notes for provisioning the LXC environment.
- Need to clarify whether the user wants a community-scripts-style Proxmox CT builder, an in-container bootstrap script, or both.
- Important design concern: Docker inside LXC may require nesting/keyctl/cgroup-related Proxmox settings and may be better in a privileged or carefully configured unprivileged container depending on the user's tolerance.

Continue by asking one clarifying question at a time before writing implementation code.
