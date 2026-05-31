#!/bin/bash
# ============================================================
# create-project — 自动创建项目、GitHub 仓库并部署到 Cloudflare Pages
# ============================================================
# 用法:
#   create-project <project-name> [选项]
#
# 选项:
#   --type static|node|python|next|vite|generic   项目类型 (默认自动检测)
#   --private                                      创建私有仓库 (默认公开)
#   --deploy cloudflare|none                       部署方式 (静态网站默认 cloudflare)
#   --org <org>                                   在组织下创建仓库
#   --dir <path>                                  指定工作目录 (默认 $CREATE_PROJECT_WORKSPACE 或 ~/projects)
#   --no-push                                     只创建本地仓库，不推送到 GitHub
#   --deploy-now                                  立即通过 wrangler 部署到 Cloudflare Pages
#   --dry-run                                     只显示将要执行的操作
#
# 示例:
#   create-project my-website                     # 在默认工作目录创建
#   create-project my-app --type next             # Next.js 项目
#   create-project my-lib --type node --private   # 私有 Node 库
#   create-project my-blog --type static          # 纯静态网站 → Cloudflare Pages
#   create-project demo --dir ~/Desktop           # 在桌面创建
# ============================================================

set -euo pipefail

# --------------- 加载用户配置（可选，文件已被 .gitignore 排除） ---------------
for _conf in "${HOME}/.create-project.env" "${HOME}/.config/create-project/env" "./.env"; do
    [[ -f "$_conf" ]] && { source "$_conf"; break; }
done
unset _conf

# --------------- 颜色输出 ---------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --------------- 默认值 ---------------
PROJECT_TYPE=""
VISIBILITY="public"
DEPLOY_MODE=""
ORG=""
WORKSPACE="${CREATE_PROJECT_WORKSPACE:-$HOME/projects}"
NO_PUSH=false
DEPLOY_NOW=false
DRY_RUN=false
PROJECT_NAME=""

# --------------- 解析参数 ---------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)
            PROJECT_TYPE="$2"; shift 2 ;;
        --private)
            VISIBILITY="private"; shift ;;
        --deploy)
            DEPLOY_MODE="$2"; shift 2 ;;
        --org)
            ORG="$2"; shift 2 ;;
        --dir)
            WORKSPACE="$2"; shift 2 ;;
        --no-push)
            NO_PUSH=true; shift ;;
        --deploy-now)
            DEPLOY_NOW=true; shift ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        -h|--help)
            head -28 "$0" | tail -24; exit 0 ;;
        -*)
            error "未知选项: $1" ;;
        *)
            if [[ -z "$PROJECT_NAME" ]]; then
                PROJECT_NAME="$1"; shift
            else
                error "只能指定一个项目名称"
            fi ;;
    esac
done

# --------------- 校验 ---------------
[[ -z "$PROJECT_NAME" ]] && error "请指定项目名称\n用法: create-project <project-name> [选项]"

# 检查 gh CLI
if ! command -v gh &>/dev/null; then
    error "未找到 GitHub CLI (gh)。请安装: https://cli.github.com"
fi

# 检查 gh 登录状态
if ! gh auth status &>/dev/null; then
    error "未登录 GitHub。请运行: gh auth login"
fi

# 获取 GitHub 用户名
GH_USER=$(gh api user --jq '.login' 2>/dev/null) || error "无法获取 GitHub 用户名"
REPO_OWNER="${ORG:-$GH_USER}"
REPO_URL="https://github.com/${REPO_OWNER}/${PROJECT_NAME}"

# --------------- 自动检测项目类型 ---------------
detect_project_type() {
    local dir="$1"

    # 如果已经指定类型，直接返回
    if [[ -n "$PROJECT_TYPE" ]]; then
        echo "$PROJECT_TYPE"
        return
    fi

    # 检测常见框架
    if [[ -f "$dir/package.json" ]]; then
        local deps
        deps=$(jq -r '.dependencies // {} | keys[], .devDependencies // {} | keys[]' "$dir/package.json" 2>/dev/null || echo "")
        if echo "$deps" | grep -q "next";       then echo "next"; return; fi
        if echo "$deps" | grep -q "react";       then echo "react"; return; fi
        if echo "$deps" | grep -q "vue";         then echo "vue"; return; fi
        if echo "$deps" | grep -q "vite";        then echo "vite"; return; fi
        if echo "$deps" | grep -q "astro";       then echo "astro"; return; fi
        echo "node"
        return
    fi

    if [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/setup.py" ]] || [[ -f "$dir/requirements.txt" ]]; then
        echo "python"; return
    fi

    if [[ -f "$dir/go.mod" ]]; then
        echo "go"; return
    fi

    if [[ -f "$dir/index.html" ]]; then
        echo "static"; return
    fi

    echo "generic"
}

# --------------- 判断是否需要静态网站部署 ---------------
needs_deploy() {
    local type="$1"
    case "$type" in
        static|next|vite|react|vue|astro) return 0 ;;
        *) return 1 ;;
    esac
}

# --------------- 获取静态文件输出目录 ---------------
get_output_dir() {
    local type="$1"
    case "$type" in
        static)  echo "." ;;
        next)    echo "./out" ;;
        vite|react|vue) echo "./dist" ;;
        astro)   echo "./dist" ;;
        *)       echo "./dist" ;;
    esac
}

# --------------- 生成 .gitignore ---------------
generate_gitignore() {
    local type="$1"
    local target="$2"

    case "$type" in
        node|next|vite|react|vue|astro)
            echo "node_modules/
dist/
build/
.next/
.env
.env.local
.DS_Store
*.log
coverage/
.cache/
.wrangler/
" > "$target"
            ;;
        python)
            echo "__pycache__/
*.py[cod]
*.egg-info/
dist/
build/
.env
.venv/
venv/
*.log
.DS_Store
" > "$target"
            ;;
        go)
            echo "*.exe
*.test
*.out
/bin/
/dist/
.env
*.log
.DS_Store
" > "$target"
            ;;
        static)
            echo ".DS_Store
*.log
.env
.wrangler/
" > "$target"
            ;;
        *)
            echo ".DS_Store
*.log
.env
" > "$target"
            ;;
    esac
}

# --------------- 生成 Cloudflare Pages 部署工作流 ---------------
generate_cloudflare_workflow() {
    local type="$1"
    local target_dir="$2"
    local output_dir
    output_dir=$(get_output_dir "$type")

    mkdir -p "$target_dir"

    if [[ "$type" == "static" ]]; then
        # 纯静态网站 — 无需构建，直接部署
        cat > "$target_dir/cloudflare-pages.yml" << YAMLEOF
name: Deploy to Cloudflare Pages

on:
  push:
    branches: [main, master]
  workflow_dispatch:

permissions:
  contents: read
  deployments: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Deploy to Cloudflare Pages
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: \${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: \${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy . --project-name=${PROJECT_NAME}
YAMLEOF

    elif [[ "$type" == "next" ]]; then
        cat > "$target_dir/cloudflare-pages.yml" << YAMLEOF
name: Deploy to Cloudflare Pages

on:
  push:
    branches: [main, master]
  workflow_dispatch:

permissions:
  contents: read
  deployments: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build & Export
        run: npx next build

      - name: Deploy to Cloudflare Pages
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: \${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: \${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy ./out --project-name=${PROJECT_NAME}
YAMLEOF

    else
        # Vite / React / Vue / Astro 等 — npm run build 后部署
        cat > "$target_dir/cloudflare-pages.yml" << YAMLEOF
name: Deploy to Cloudflare Pages

on:
  push:
    branches: [main, master]
  workflow_dispatch:

permissions:
  contents: read
  deployments: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Deploy to Cloudflare Pages
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: \${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: \${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy ${output_dir} --project-name=${PROJECT_NAME}
YAMLEOF
    fi
}

# --------------- 检查 Cloudflare 配置 ---------------
check_cloudflare() {
    # 检查 wrangler 是否可用（通过 npx）
    if ! npx --yes wrangler --version &>/dev/null; then
        warn "wrangler 暂不可用，将通过 GitHub Actions 部署"
        return 1
    fi

    # 检查是否已登录 Cloudflare
    if ! npx wrangler whoami &>/dev/null; then
        warn "未登录 Cloudflare。部署工作流需要手动配置 Secrets"
        return 1
    fi

    return 0
}

# --------------- Cloudflare 配置指引 ---------------
get_cloudflare_account_id() {
    # 优先使用环境变量
    if [[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
        echo "$CLOUDFLARE_ACCOUNT_ID"
        return
    fi
    # 从 wrangler 自动检测
    if npx wrangler whoami &>/dev/null 2>&1; then
        local id
        id=$(npx wrangler whoami 2>/dev/null | grep -oP 'Account ID\s*\K[a-f0-9]+' | head -1 || true)
        if [[ -n "$id" ]]; then
            echo "$id"
            return
        fi
    fi
    echo "YOUR_ACCOUNT_ID"
}

print_cloudflare_setup_guide() {
    local ACCOUNT_ID
    ACCOUNT_ID=$(get_cloudflare_account_id)
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  ${CYAN}☁️  Cloudflare Pages 自动部署设置${NC}                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════╣${NC}"
    if [[ "$ACCOUNT_ID" != "YOUR_ACCOUNT_ID" ]]; then
    echo -e "${YELLOW}║${NC}  Account ID: ${GREEN}${ACCOUNT_ID}${NC}  ${YELLOW}║${NC}"
    fi
    echo -e "${YELLOW}║${NC}                                                       ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  还需创建 API Token:                                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  1. 打开 ${BLUE}https://dash.cloudflare.com/profile/api-tokens${NC}  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  2. Create Token → Cloudflare Pages 模板               ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  3. 复制 Token 后运行:                                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}     gh secret set CLOUDFLARE_API_TOKEN -b\"your-token\"  ${YELLOW}║${NC}"
    if [[ "$ACCOUNT_ID" != "YOUR_ACCOUNT_ID" ]]; then
    echo -e "${YELLOW}║${NC}     gh secret set CLOUDFLARE_ACCOUNT_ID -b\"${ACCOUNT_ID}\" ${YELLOW}║${NC}"
    else
    echo -e "${YELLOW}║${NC}     gh secret set CLOUDFLARE_ACCOUNT_ID -b\"your-id\"    ${YELLOW}║${NC}"
    fi
    echo -e "${YELLOW}║${NC}                                                       ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${CYAN}💡 也可以用 --deploy-now 立即部署（无需 API Token）${NC}     ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# --------------- 本地直接部署 ---------------
deploy_to_cloudflare() {
    local type="$1"
    local output_dir
    output_dir=$(get_output_dir "$type")

    info "☁️  通过 wrangler 直接部署到 Cloudflare Pages..."

    # 如果是前端框架项目，需要先构建
    if [[ "$type" != "static" ]]; then
        if [[ -f "package.json" ]]; then
            info "🔨 构建项目..."
            npm install --silent 2>&1 | tail -1
            npm run build 2>&1 | tail -3 || {
                warn "构建失败，尝试跳过构建直接部署"
            }
        fi
    fi

    # 先创建 Cloudflare Pages 项目（如果不存在）
    info "📦 检查/创建 Cloudflare Pages 项目..."
    npx wrangler pages project create "$PROJECT_NAME" --production-branch=main 2>&1 | tail -2 || true

    # 部署
    if [[ -d "$output_dir" ]]; then
        info "📤 部署目录: $output_dir"
        DEPLOY_OUTPUT=$(npx wrangler pages deploy "$output_dir" --project-name="$PROJECT_NAME" --branch=main 2>&1)
        echo "$DEPLOY_OUTPUT"

        # 提取部署 URL
        DEPLOY_URL=$(echo "$DEPLOY_OUTPUT" | grep -oP 'https://[a-z0-9-]+\.pages\.dev' | head -1 || true)
        if [[ -z "$DEPLOY_URL" ]]; then
            DEPLOY_URL="https://${PROJECT_NAME}.pages.dev"
        fi
        success "部署完成: ${DEPLOY_URL}"
    else
        warn "构建目录 $output_dir 不存在，无法部署"
        info "可稍后手动部署: cd ${PROJECT_DIR} && npx wrangler pages deploy ${output_dir} --project-name=${PROJECT_NAME}"
        DEPLOY_URL=""
    fi
}

# --------------- 主流程 ---------------
# 确保工作目录存在
if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$WORKSPACE"
fi

PROJECT_DIR="${WORKSPACE}/${PROJECT_NAME}"

echo ""
info "📦 准备创建项目: $PROJECT_NAME"
info "📂 工作目录: ${WORKSPACE}"

# 检查目录是否存在
if [[ -d "$PROJECT_DIR" ]]; then
    info "📁 目录已存在，使用现有目录: $PROJECT_DIR"
    cd "$PROJECT_DIR"

    # 检测项目类型
    DETECTED_TYPE=$(detect_project_type ".")
    if [[ -z "$PROJECT_TYPE" ]]; then
        PROJECT_TYPE="$DETECTED_TYPE"
    fi

    # 如果还不是 git 仓库，初始化
    if [[ ! -d ".git" ]]; then
        info "🔧 初始化 Git 仓库..."
        if [[ "$DRY_RUN" == false ]]; then
            git init -b main
        fi
    else
        info "✅ Git 仓库已存在"
    fi
else
    # 创建新目录
    info "📁 创建项目目录: $PROJECT_DIR"
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$PROJECT_DIR"
        cd "$PROJECT_DIR"
        git init -b main
    fi
fi

# 确定项目类型（空目录默认 generic）
if [[ -z "$PROJECT_TYPE" ]]; then
    PROJECT_TYPE="generic"
fi

success "项目类型: $PROJECT_TYPE"
success "可见性: $VISIBILITY"

# 确定部署模式
if [[ -z "$DEPLOY_MODE" ]]; then
    if needs_deploy "$PROJECT_TYPE"; then
        DEPLOY_MODE="cloudflare"
    else
        DEPLOY_MODE="none"
    fi
fi
success "部署方式: $DEPLOY_MODE"

# --------------- 创建 GitHub 仓库 ---------------
if [[ "$DRY_RUN" == false ]]; then
    info "🐙 在 GitHub 上创建仓库..."

    if [[ -n "$ORG" ]] && [[ "$ORG" != "$GH_USER" ]]; then
        gh repo create "${ORG}/${PROJECT_NAME}" --"${VISIBILITY}" --source=. --remote=origin --push 2>&1 || {
            gh repo create "${ORG}/${PROJECT_NAME}" --"${VISIBILITY}" --source=. --remote=origin 2>&1
        }
    else
        gh repo create "${PROJECT_NAME}" --"${VISIBILITY}" --source=. --remote=origin --push 2>&1 || {
            gh repo create "${PROJECT_NAME}" --"${VISIBILITY}" --source=. --remote=origin 2>&1
        }
    fi
else
    info "[DRY-RUN] gh repo create ${REPO_OWNER}/${PROJECT_NAME} --${VISIBILITY} --source=. --remote=origin"
fi

success "GitHub 仓库已创建: ${REPO_URL}"

# --------------- 配置 Cloudflare Pages 部署 ---------------
if [[ "$DEPLOY_MODE" == "cloudflare" ]]; then
    info "☁️  配置 Cloudflare Pages 部署..."

    WORKFLOW_DIR=".github/workflows"

    if [[ "$DRY_RUN" == false ]]; then
        generate_cloudflare_workflow "$PROJECT_TYPE" "$WORKFLOW_DIR"
        info "📄 已生成 GitHub Actions 工作流: ${WORKFLOW_DIR}/cloudflare-pages.yml"
    else
        info "[DRY-RUN] 生成 Cloudflare Pages 部署工作流"
    fi
fi

# --------------- 补充文件 ---------------
if [[ "$DRY_RUN" == false ]]; then
    # 生成 .gitignore（如果不存在）
    if [[ ! -f ".gitignore" ]]; then
        generate_gitignore "$PROJECT_TYPE" ".gitignore"
        info "📄 已生成 .gitignore"
    fi

    # 如果是静态网站但没有 index.html，创建一个
    if [[ "$PROJECT_TYPE" == "static" ]] && [[ ! -f "index.html" ]]; then
        cat > "index.html" << HTMLEOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${PROJECT_NAME}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex; align-items: center; justify-content: center;
            min-height: 100vh; background: linear-gradient(135deg, #f38020 0%, #f8991c 50%, #faae40 100%);
            color: #fff;
        }
        .container { text-align: center; }
        h1 { font-size: 3rem; margin-bottom: 0.5rem; }
        p { font-size: 1.2rem; opacity: 0.85; }
        .badge { display: inline-block; margin-top: 1.5rem; padding: 0.5rem 1.2rem;
                 background: rgba(255,255,255,0.2); border-radius: 2rem; font-size: 0.9rem; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 ${PROJECT_NAME}</h1>
        <p>项目已就绪！通过 Cloudflare Pages 自动部署。</p>
        <div class="badge">☁️ Powered by Cloudflare Pages</div>
    </div>
</body>
</html>
HTMLEOF
        info "📄 已生成 index.html 模板"
    fi
fi

# --------------- 提交并推送 ---------------
if [[ "$DRY_RUN" == false ]]; then
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        info "📝 提交初始文件..."
        git add -A
        git commit -m "🎉 初始化项目: ${PROJECT_NAME}

通过 create-project 自动创建
- 项目类型: ${PROJECT_TYPE}
- 部署方式: Cloudflare Pages
" 2>/dev/null || info "已跳过 commit（无变更或已配置）"
    fi

    if [[ "$NO_PUSH" == false ]]; then
        info "⬆️  推送到 GitHub..."
        if git remote get-url origin &>/dev/null; then
            git push -u origin main 2>&1 || git push -u origin master 2>&1 || {
                warn "推送失败，请手动执行: git push -u origin main"
            }
        fi
    fi
fi

# --------------- 立即部署（可选） ---------------
if [[ "$DEPLOY_NOW" == true ]] && [[ "$DEPLOY_MODE" == "cloudflare" ]]; then
    if npx wrangler whoami &>/dev/null; then
        deploy_to_cloudflare "$PROJECT_TYPE"
    else
        warn "wrangler 未登录，跳过立即部署。请先运行: npx wrangler login"
    fi
fi

# --------------- 输出结果 ---------------
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}✨ 项目创建完成!${NC}                                              ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  📂 本地路径:     ${PROJECT_DIR}"
echo -e "${GREEN}║${NC}  🐙 仓库地址:     ${REPO_URL}"
if [[ "$DEPLOY_MODE" == "cloudflare" ]]; then
echo -e "${GREEN}║${NC}  ☁️  部署平台:     Cloudflare Pages"
if [[ "$DEPLOY_NOW" == true ]] && [[ -n "${DEPLOY_URL:-}" ]]; then
echo -e "${GREEN}║${NC}  🌐 网站地址:     ${DEPLOY_URL}"
fi
echo -e "${GREEN}║${NC}  ⚡ 推送代码 → GitHub Actions → 自动部署"
fi
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  🔑 下一步:                                                 ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}    cd ${PROJECT_DIR}                                        ${GREEN}║${NC}"

if [[ "$DEPLOY_MODE" == "cloudflare" ]]; then
    echo -e "${GREEN}║${NC}                                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${YELLOW}⚡ 两种部署方式:${NC}                                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ${CYAN}① 立即部署${NC}: create-project <name> --deploy-now          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    ${CYAN}② 自动部署${NC}: 需先配置 Cloudflare API Token               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}       gh secret set CLOUDFLARE_API_TOKEN -b\"你的token\"      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}       gh secret set CLOUDFLARE_ACCOUNT_ID -b\"你的ID\"        ${GREEN}║${NC}"
fi
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 输出 Cloudflare 配置指引
if [[ "$DEPLOY_MODE" == "cloudflare" ]]; then
    print_cloudflare_setup_guide
fi
