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
- `--dir <path>` — custom workspace (default: `$CREATE_PROJECT_WORKSPACE` or `~/projects`)
- `--no-push` — skip GitHub push

### Step 3: Report Results

Summarize what was created:
- Local directory path
- GitHub repository URL
- Cloudflare Pages URL (if deployed)
- Any errors and how to resolve them

## Network Notes

- GitHub push may fail due to network restrictions in some regions
- Cloudflare Pages deployment (via wrangler) usually bypasses these restrictions
- If GitHub push fails, remind user: repo is created on GitHub but code needs proxy/VPN to push
- The `--deploy-now` flag deploys directly to Cloudflare without requiring GitHub push

## Configuration

All account-specific values are auto-detected or read from environment variables:
- `CREATE_PROJECT_WORKSPACE` — default workspace directory (falls back to `~/projects`)
- `CLOUDFLARE_ACCOUNT_ID` — Cloudflare Account ID (auto-detected from `wrangler whoami` if logged in)
- GitHub username and repo owner are resolved automatically via `gh` CLI
- Cloudflare API Token is only needed for GitHub Actions CI/CD (not for `--deploy-now`)

Set these in `~/.bashrc` or a `.env` file to persist your preferences.
