#!/bin/bash
# ============================================================
# publish-check.sh — 发布前安全审查
# 在 git push 前运行，检测是否有敏感信息泄露
# ============================================================
# 用法:
#   bash scripts/publish-check.sh          # 检查所有文件
#   bash scripts/publish-check.sh --strict # 严格模式（报错即退出）
# ============================================================

set -euo pipefail
STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; WARN=0; FAIL=0

check() {
    local severity="$1" pattern="$2" message="$3"
    local files
    files=$(git ls-files | grep -v '.gitignore' | xargs grep -lI "$pattern" 2>/dev/null || true)
    if [[ -n "$files" ]]; then
        if [[ "$severity" == "ERROR" ]]; then
            echo -e "  ${RED}❌ FAIL${NC}  $message"
            echo "         文件: $files"
            ((FAIL++))
        else
            echo -e "  ${YELLOW}⚠️  WARN${NC}  $message"
            echo "         文件: $files"
            ((WARN++))
        fi
    else
        echo -e "  ${GREEN}✅ PASS${NC}  $message"
        ((PASS++))
    fi
}

echo ""
echo -e "${YELLOW}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${NC}  🔍 发布前安全审查                                     ${YELLOW}║${NC}"
echo -e "${YELLOW}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ===== 敏感信息检测 =====
echo -e "${YELLOW}── 敏感信息检测 ──${NC}"

check ERROR '[a-f0-9]{32}' \
    "疑似 Cloudflare Account ID (32位hex)"

check ERROR 'gho_[A-Za-z0-9_]{36,}' \
    "GitHub OAuth Token (gho_...)"

check ERROR 'ghp_[A-Za-z0-9_]{36,}' \
    "GitHub Personal Access Token (ghp_...)"

check ERROR 'ghs_[A-Za-z0-9_]{36,}' \
    "GitHub Server Token (ghs_...)"

check WARN '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
    "UUID/GUID (可能是 API Key)"

check WARN 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{0,}' \
    "JWT Token"

check WARN 'Bearer [A-Za-z0-9_-]{20,}' \
    "Bearer Token"

check WARN 'password|passwd|secret_key|api_key.*=.*["'"'"'][A-Za-z0-9]{8,}' \
    "硬编码的密码/密钥"

# ===== 个人信息检测 =====
echo ""
echo -e "${YELLOW}── 个人信息检测 ──${NC}"

check WARN '@(gmail|qq|163|outlook|hotmail|foxmail)\.com' \
    "邮箱地址"

check WARN '[^/]D:\\\\[A-Za-z]' \
    "Windows 绝对路径 (D:\...)"

check WARN '/home/[a-z]+/' \
    "Linux 家目录路径"

# ===== 文件结构检查 =====
echo ""
echo -e "${YELLOW}── 文件结构检查 ──${NC}"

if git ls-files | grep -q '\.env$' && ! git ls-files | grep -q '\.env\.example'; then
    echo -e "  ${RED}❌ FAIL${NC}  存在 .env 但没有 .env.example"
    ((FAIL++))
else
    echo -e "  ${GREEN}✅ PASS${NC}  .env 管理合理"
    ((PASS++))
fi

if [[ -f ".gitignore" ]]; then
    if grep -q '\.env' .gitignore; then
        echo -e "  ${GREEN}✅ PASS${NC}  .gitignore 包含 .env"
        ((PASS++))
    else
        echo -e "  ${YELLOW}⚠️  WARN${NC}  .gitignore 未包含 .env"
        ((WARN++))
    fi
else
    echo -e "  ${YELLOW}⚠️  WARN${NC}  缺少 .gitignore"
    ((WARN++))
fi

# If SKILL.md exists, check it doesn't have account info
if [[ -f "SKILL.md" ]]; then
    if grep -qE '(Account ID|用户名|username|email|password|token).*[:=].*[`"'"'"']' SKILL.md 2>/dev/null; then
        echo -e "  ${YELLOW}⚠️  WARN${NC}  SKILL.md 可能包含账户信息"
        ((WARN++))
    else
        echo -e "  ${GREEN}✅ PASS${NC}  SKILL.md 无账户信息"
        ((PASS++))
    fi
fi

# ===== 结果 =====
echo ""
echo -e "${YELLOW}────────────────────────────────────────────────────${NC}"
TOTAL=$((PASS + WARN + FAIL))
echo -e "  通过: ${GREEN}${PASS}${NC}  警告: ${YELLOW}${WARN}${NC}  失败: ${RED}${FAIL}${NC}  总计: ${TOTAL}"

if [[ "$FAIL" -gt 0 ]]; then
    echo ""
    echo -e "${RED}❌ 发现 ${FAIL} 个严重问题，建议修复后再发布。${NC}"
    echo -e "   使用 --strict 模式可阻止推送。"
    if [[ "$STRICT" == true ]]; then
        exit 1
    fi
elif [[ "$WARN" -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  有 ${WARN} 个警告，请人工确认是否安全。${NC}"
else
    echo ""
    echo -e "${GREEN}✅ 全部通过，可以安全发布。${NC}"
fi
echo ""
