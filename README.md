# 🚀 create-project — Claude Code Skill

> 一句话创建项目：自动建 GitHub 仓库 + 部署 Cloudflare Pages  
> **Create once, deploy instantly.**

[English](#english) | [中文](#中文)

---

## English

### What It Does

Every time you create a new project, you repeat the same steps: `mkdir`, `git init`, open GitHub in browser, create repo, add remote, push, configure Cloudflare Pages, write CI/CD workflow...

**This skill eliminates all of that.** Just tell Claude "create a project called X", and it:

1. Creates the project directory and initializes git
2. Creates a GitHub repository via `gh` CLI
3. Auto-detects project type (Next.js, Vite, React, Vue, Python, Go, etc.)
4. Generates `.gitignore`, starter template, and Cloudflare Pages deployment workflow
5. Optionally deploys to Cloudflare Pages immediately (`--deploy-now`)

### Why This Matters

| Manual Process | With This Skill |
|----------------|-----------------|
| 7+ manual steps per project | 1 sentence → done |
| Browser tab switching (GitHub, Cloudflare, terminal) | All in terminal / Claude Code |
| Different setup for each framework | Auto-detection of 10+ project types |
| Need to know CI/CD YAML syntax | Auto-generated GitHub Actions workflow |
| GitHub blocked in some regions | `--deploy-now` deploys via Cloudflare directly |

### Installation

```bash
git clone https://github.com/YOUR_USERNAME/create-project-skill.git ~/.claude/skills/create-project
```

### Quick Start

**Via Claude Code:**
> "Create a project called my-blog"

**Via CLI:**
```bash
bash ~/.claude/skills/create-project/scripts/create-project.sh my-website --type static --deploy-now
```

### Options

| Flag | Description |
|------|-------------|
| `--type static\|next\|vite\|node\|python\|go\|generic` | Project type (auto-detected if omitted) |
| `--private` | Make repo private |
| `--deploy-now` | Deploy to Cloudflare Pages immediately |
| `--dir <path>` | Custom workspace directory |
| `--no-push` | Skip GitHub push |
| `--org <name>` | Create under an organization |
| `--dry-run` | Preview without making changes |

### Requirements

- [GitHub CLI](https://cli.github.com/) — `gh auth login`
- [Node.js](https://nodejs.org/) — for `npx wrangler`
- Cloudflare account — `npx wrangler login`
- Git

### Security

- All account credentials are **auto-detected** (via `gh api`, `wrangler whoami`) — never hardcoded
- Sensitive config via environment variables (`CREATE_PROJECT_WORKSPACE`, etc.)
- Run `bash scripts/publish-check.sh --strict` before pushing to catch credential leaks
- `.env` files are gitignored, `.env.example` provided as template

---

## 中文

### 解决什么问题

每次创建新项目，你都要重复：建目录、`git init`、浏览器打开 GitHub、新建仓库、添加 remote、push、登录 Cloudflare、创建 Pages 项目、配置构建命令、写 CI/CD 工作流……

**这个 skill 彻底终结这些重复劳动。** 对 Claude 说"创建项目 XXX"，自动完成一切。

### 它能做什么

1. 📁 创建项目目录，初始化 git
2. 🐙 通过 `gh` CLI 在 GitHub 自动创建仓库
3. 🔍 自动检测项目类型（Next.js、Vite、React、Vue、Python、Go 等）
4. 📄 自动生成 `.gitignore`、起始模板、Cloudflare Pages 工作流
5. 🚀 可选立即部署到 Cloudflare Pages（`--deploy-now`）

### 核心价值

| 手动操作 | 用这个 Skill |
|----------|-------------|
| 7 步以上手动操作 | 一句话完成 |
| GitHub / Cloudflare / 终端来回切换 | 全部在对话里完成 |
| 不同框架不同配置 | 自动检测 10+ 种项目类型 |
| 需要懂 CI/CD YAML 写法 | 自动生成 GitHub Actions 工作流 |
| GitHub 被墙推不上去 | `--deploy-now` 直连 Cloudflare 部署 |

### 安装

```bash
git clone https://github.com/YOUR_USERNAME/create-project-skill.git ~/.claude/skills/create-project
```

### 使用方式

**方式一：对 Claude Code 说话（自动）**
> "创建项目 my-blog"

Skill 自动触发，无需手动调用。

**方式二：终端命令行**
```bash
# 基础用法
bash ~/.claude/skills/create-project/scripts/create-project.sh my-website --type static

# 创建并立即部署（绕过 GitHub 被墙问题）
bash ~/.claude/skills/create-project/scripts/create-project.sh my-blog --type static --deploy-now

# 私有仓库
bash ~/.claude/skills/create-project/scripts/create-project.sh my-lib --type node --private

# 自定义目录
bash ~/.claude/skills/create-project/scripts/create-project.sh demo --dir ~/Desktop
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `--type static\|next\|vite\|node\|python\|go\|generic` | 项目类型，不指定则自动检测 |
| `--private` | 创建私有仓库（默认公开） |
| `--deploy-now` | 立即通过 wrangler 部署到 Cloudflare Pages |
| `--dir <路径>` | 自定义工作目录（默认 `~/projects`） |
| `--no-push` | 只建本地仓库，不推送 GitHub |
| `--org <组织名>` | 在组织下创建仓库 |
| `--dry-run` | 演习模式，只显示不执行 |

### 依赖

- [GitHub CLI](https://cli.github.com/) — 需 `gh auth login`
- [Node.js](https://nodejs.org/) — 用于 `npx wrangler`
- Cloudflare 账号 — 需 `npx wrangler login`
- Git

### 安全设计

- 所有账户信息**自动检测**（通过 `gh api`、`wrangler whoami`），绝不硬编码
- 敏感配置用环境变量（`CREATE_PROJECT_WORKSPACE` 等）
- 推送前运行 `bash scripts/publish-check.sh --strict` 阻断凭证泄露
- `.env` 文件已 gitignore，提供 `.env.example` 模板

### 配置环境变量（可选）

```bash
# 复制模板
cp .env.example .env

# 编辑配置
# CREATE_PROJECT_WORKSPACE=~/projects    # 默认工作目录
# CLOUDFLARE_ACCOUNT_ID=xxx             # 可选，脚本自动检测
```

### 工作流程

```
你: "创建项目 my-website"
         │
    ┌────▼─────┐
    │ 自动检测  │ ← 项目类型？static/next/vite…
    └────┬─────┘
         │
    ┌────▼─────┐
    │ git init  │ ← D:\Claude_workspace\my-website\
    └────┬─────┘
         │
    ┌────▼─────┐
    │ gh repo   │ ← 在 GitHub 创建仓库
    │ create    │
    └────┬─────┘
         │
    ┌────▼─────┐
    │ 生成文件  │ ← .gitignore + index.html + CI/CD 工作流
    └────┬─────┘
         │
    ┌────▼─────┐
    │ 提交推送  │ ← git commit + push
    └────┬─────┘
         │
    ┌────▼─────┐
    │ 部署上线  │ ← Cloudflare Pages 🌐
    └──────────┘
```

---

## License

MIT
