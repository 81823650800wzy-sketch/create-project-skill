# create-project — Claude Code Skill

Automatically create projects with GitHub repository + Cloudflare Pages deployment.

## Features

- 🏗️ Initialize project directory with git
- 🐙 Auto-create GitHub repository
- ☁️ Auto-deploy static sites to Cloudflare Pages
- 🔍 Auto-detect project type (Next.js, Vite, React, Python, Go, etc.)
- 🚀 `--deploy-now` for instant deployment via wrangler
- 📄 Generates `.gitignore`, starter `index.html`, and GitHub Actions workflow

## Installation

```bash
# Clone into Claude Code skills directory
git clone https://github.com/YOUR_USERNAME/create-project-skill.git ~/.claude/skills/create-project

# Or manually: copy SKILL.md + scripts/ into .claude/skills/create-project/
```

## Usage

### Via Claude Code (automatic)

Just tell Claude:
> "Create a project called my-blog"

The skill auto-triggers and handles everything.

### Via CLI (manual)

```bash
bash ~/.claude/skills/create-project/scripts/create-project.sh my-website --type static --deploy-now
```

### Options

| Flag | Description |
|------|-------------|
| `--type static\|next\|vite\|node\|python\|go\|generic` | Project type |
| `--private` | Create private GitHub repo |
| `--deploy-now` | Deploy to Cloudflare Pages immediately |
| `--dir <path>` | Custom workspace (default: `~/projects`) |
| `--no-push` | Skip git push to GitHub |
| `--org <name>` | Create under GitHub organization |
| `--dry-run` | Preview without executing |

## Requirements

- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated
- [Node.js](https://nodejs.org/) — for `npx wrangler`
- Cloudflare account — for Pages deployment
- Git

## Cloudflare Pages Setup

```bash
# Login to Cloudflare
npx wrangler login

# Or set GitHub Secrets for CI/CD auto-deploy:
gh secret set CLOUDFLARE_API_TOKEN -b"your-token"
gh secret set CLOUDFLARE_ACCOUNT_ID -b"your-account-id"
```

## License

MIT
