# Session Instructions

## Goal

- Create a Proxmox LXC helper script that provisions a development environment with Docker, Python, and Node.js.
- Keep the script understandable, auditable, and explicit about any Proxmox host-side requirements.

## Scope

- Work only inside this session folder unless the user explicitly approves changes elsewhere.
- Other session folders may be read for reference, but must not be modified.
- Do not delete files. Move files that should be removed into this session's `_DEL/` folder.

## Structure

- `README.md`: session summary and result map.
- `notes/`: research notes and working notes.
- `outputs/`: final deliverables.
- `src/`: code, when the session needs code.
- `_DEL/`: files moved aside instead of deleted.

## Special Notes

- Shell scripts should be written defensively because they may run as root on a Proxmox host or inside an LXC.
- Prefer explicit version choices and clear comments over hidden magic.
- Do not use destructive commands; if a file must be removed, move it into `_DEL/`.
