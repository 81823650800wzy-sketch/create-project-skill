---
name: create-project
description: Create new projects with automatic GitHub repository creation and Cloudflare Pages deployment. Use when user asks to create, new, scaffold, or initialize a project.
argument-hint: "<project-name> [--type static|next|vite|node|python|generic] [--private] [--deploy-now]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Create Project Skill

Automates project creation: initializes directory, creates GitHub repository, and configures Cloudflare Pages deployment for static sites.

## When to Use

Trigger when the user says:
- "Create a project called X"
- "New project X"
- "Scaffold a website X"
- "Initialize project X"
- Any request to start a new project

## Workflow

### Step 1: Understand Requirements

Ask the user only if critical info is missing. Otherwise infer from context:

| Question | Default |
|----------|---------|
| Project name | Required (ask if missing) |
| Project type | `static` if website/HTML, otherwise auto-detect |
| Private repo? | `false` (public) |
| Deploy now? | `true` for static sites, skip for libraries |

### Step 2: Run the Script

Use the bundled script at `scripts/create-project.sh`:

```bash
bash ~/.claude/skills/create-project/scripts/create-project.sh <project-name> [flags]
```

Flags:
- `--type static|next|vite|node|python|generic` — project type
- `--private` — make GitHub repo private
- `--deploy-now` — immediately deploy to Cloudflare Pages via wrangler
- `--dir <path>` — custom workspace (default: `D:\Claude_workspace`)
- `--no-push` — skip GitHub push

### Step 3: Report Results

Summarize what was created:
- Local directory path
- GitHub repository URL
- Cloudflare Pages URL (if deployed)
- Any errors and how to resolve them

## Network Notes

- GitHub push may fail due to network restrictions in China
- Cloudflare Pages deployment (via wrangler) usually works
- If GitHub push fails, remind user: repo is created on GitHub but code needs a proxy/VPN to push
- The `--deploy-now` flag bypasses GitHub entirely for deployment

## Account Info

- GitHub: `81823650800wzy-sketch`
- Cloudflare Account ID: `f7085c2450a7ec7f257366e8cc602971`
- Default workspace: `D:\Claude_workspace`
