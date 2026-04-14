# Auto-configure room-based multi-agent coordination

Analyze this project and set up rooms so multiple Claude Code agents can work on it simultaneously without conflicts.

## Steps

1. Read the full directory structure of this project (use `find . -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/__pycache__/*' -not -path '*/rooms/*' -type f | head -200`)

2. Identify logical modules — groups of files that serve one purpose:
   - Backend languages (Go, Python, Node, Rust, Java)
   - Frontend (HTML/CSS/JS, React, Vue, etc.)
   - CI/CD (.github/, workflows)
   - Infrastructure (deploy/, helm/, terraform/, Docker)
   - Scripts and tooling
   - Documentation

3. For each module, decide:
   - **Room name** — short, lowercase, hyphenated (e.g., `go-dev`, `frontend`, `ci`)
   - **Owns** — which directories/files this room exclusively controls
   - **Description** — one line explaining what this room does

4. Identify **shared files** — files that multiple rooms might need to edit (config, README, root Makefile). Assign an approver room.

5. Generate `rooms.json` with your analysis. Follow this exact format:
```json
{
  "version": 1,
  "description": "Room assignments for multi-agent coordination.",
  "rooms": {
    "room-name": {
      "description": "What this room does",
      "owns": ["dir1/", "dir2/specific-file.py"],
      "color": "blue"
    }
  },
  "shared": {
    "description": "Files that require a request to edit",
    "paths": ["CLAUDE.md", "README.md"],
    "approver": "room-name"
  }
}
```

6. Run `make rooms` to scaffold the inbox/outbox structure.

7. Report what you created — list each room, what it owns, and how many files are in each.

## Rules
- Aim for 3-6 rooms. Fewer is better. One agent per major module.
- Tests belong with their module (go tests → go room, python tests → python room).
- Don't create a room for dirs with fewer than 3 files.
- Every source file must belong to exactly one room (no orphans, no overlaps).
- Shared files should be minimal — most files should have a clear owner.
