#!/bin/bash

# ==============================================================================
# Claude Code 安装配置脚本
# 版本: 1.1.0
# 用途: 自动化 Claude Code CLI 的安装和配置流程
# ==============================================================================

# ------------------------------------------------------------------------------
# 信号处理 - 优雅退出
# ------------------------------------------------------------------------------
cleanup() {
    local exit_code=$?

    # 清理临时文件
    rm -f /tmp/verify_response.json 2>/dev/null
    rm -f /tmp/claude_install_*.tmp 2>/dev/null

    # 如果是被中断的，显示提示
    if [[ $exit_code -eq 130 ]] || [[ $exit_code -eq 143 ]]; then
        echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}  操作已被用户中断${NC}"
        echo -e "${YELLOW}  如需继续，请重新运行脚本${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi

    exit $exit_code
}

# 捕获信号
trap cleanup EXIT
trap 'exit 130' INT TERM

# ------------------------------------------------------------------------------
# 命令行参数解析
# ------------------------------------------------------------------------------
DRY_RUN=false
VERBOSE=false
SKIP_CONFIRM=false

show_help() {
    cat << EOF
Claude Code 安装配置脚本 v1.1.0

用法: $(basename "$0") [选项]

选项:
  -n, --dry-run      预览模式，只显示将要执行的操作，不实际执行
  -y, --yes          跳过所有确认提示，使用默认值
  -v, --verbose      显示详细输出
  -h, --help         显示帮助信息
  --version          显示版本信息

示例:
  $(basename "$0")              交互式安装
  $(basename "$0") --dry-run    预览将要执行的操作
  $(basename "$0") -y           自动确认所有提示

EOF
    exit 0
}

show_version() {
    echo "Claude Code 安装配置脚本 v1.1.0"
    exit 0
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        --version)
            show_version
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# dry-run 模式提示
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}  🔍 DRY-RUN 模式 - 只预览不执行${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi

# ------------------------------------------------------------------------------
# 错误处理
# ------------------------------------------------------------------------------
set -e  # 遇到错误立即退出

# ------------------------------------------------------------------------------
# 颜色定义
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# 全局变量
# ------------------------------------------------------------------------------
CLAUDE_DIR="$HOME/.claude"
CLAUDE_JSON_FILE="$HOME/.claude.json"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
CONFIG_FILE="$CLAUDE_DIR/config.json"
RULES_DIR="$CLAUDE_DIR/rules"
PLUGINS_FILE="$CLAUDE_DIR/plugins/installed_plugins.json"

# 用户配置
USER_BASE_URL=""
USER_API_KEY=""
USER_MODEL=""
USER_LANGUAGE="简体中文"

# Claude Team 配置
TEAM_MEMBERS=()
TEAM_MODELS=()
TEAM_PROVIDERS=()

# 插件列表 - 基础插件
BASIC_PLUGIN_NAMES=(
    "superpowers"
    "code-review"
    "security-guidance"
    "feature-dev"
    "claude-md-management"
    "code-simplifier"
)

# 插件列表 - 开发支持插件
DEV_PLUGIN_NAMES=(
    "typescript-lsp"
    "kotlin-lsp"
    "swift-lsp"
    "frontend-design"
    "pr-review-toolkit"
    "figma"
    "qodo-skills"
    "skill-creator"
)

# 获取插件描述
get_plugin_desc() {
    case "$1" in
        "superpowers") echo "增强 Power skills" ;;
        "code-review") echo "代码审查" ;;
        "frontend-design") echo "前端设计" ;;
        "pr-review-toolkit") echo "PR 审查工具" ;;
        "feature-dev") echo "功能开发" ;;
        "claude-md-management") echo "CLAUDE.md 管理" ;;
        "figma") echo "Figma 集成" ;;
        "security-guidance") echo "安全指导" ;;
        "typescript-lsp") echo "TypeScript LSP" ;;
        "kotlin-lsp") echo "Kotlin LSP" ;;
        "swift-lsp") echo "Swift LSP" ;;
        "qodo-skills") echo "Qodo Skills" ;;
        "skill-creator") echo "Skill Creator" ;;
        "code-simplifier") echo "代码简化器" ;;
        *) echo "" ;;
    esac
}

# 规则集 (名称数组)
AVAILABLE_RULE_NAMES=(
    "common"
    "typescript"
    "python"
    "golang"
    "swift"
)

# 获取规则描述
get_rule_desc() {
    case "$1" in
        "common") echo "通用规则 (必选)" ;;
        "typescript") echo "TypeScript/JavaScript" ;;
        "python") echo "Python" ;;
        "golang") echo "Go" ;;
        "swift") echo "Swift" ;;
        *) echo "" ;;
    esac
}

# 测试环境 (名称数组)
AVAILABLE_TEST_ENV_NAMES=(
    "playwright"
    "jest"
    "pytest"
)

# 获取测试环境描述
get_test_env_desc() {
    case "$1" in
        "playwright") echo "Playwright E2E 测试" ;;
        "jest") echo "Jest JavaScript 单元测试" ;;
        "pytest") echo "Pytest Python 单元测试" ;;
        *) echo "" ;;
    esac
}

# ------------------------------------------------------------------------------
# 职业角色配置
# ------------------------------------------------------------------------------

# 角色名称数组
TECH_ROLE_NAMES=("backend_engineer" "frontend_engineer" "mobile_engineer" "fullstack_engineer" "ai_engineer" "data_engineer")
OPS_ROLE_NAMES=("devops_engineer" "security_engineer")
QUALITY_ROLE_NAMES=("test_engineer")
ARCH_ROLE_NAMES=("architect" "business_manager" "project_manager" "product_manager")
DESIGN_ROLE_NAMES=("ui_ux_designer")
CONTENT_ROLE_NAMES=("content_creator" "tech_writer")
EDUCATION_ROLE_NAMES=("teacher" "student")
GENERAL_ROLE_NAMES=("general_user")

# 获取角色中文名称
get_role_name() {
    case "$1" in
        "backend_engineer") echo "后端开发工程师" ;;
        "frontend_engineer") echo "前端开发工程师" ;;
        "mobile_engineer") echo "移动端开发工程师" ;;
        "fullstack_engineer") echo "全栈工程师" ;;
        "ai_engineer") echo "AI/ML 工程师" ;;
        "data_engineer") echo "数据工程师" ;;
        "devops_engineer") echo "DevOps/SRE 工程师" ;;
        "security_engineer") echo "安全工程师" ;;
        "test_engineer") echo "测试工程师" ;;
        "architect") echo "系统架构师" ;;
        "business_manager") echo "业务经理" ;;
        "project_manager") echo "项目经理" ;;
        "product_manager") echo "产品经理" ;;
        "ui_ux_designer") echo "UI/UX 设计师" ;;
        "content_creator") echo "自媒体从业者" ;;
        "tech_writer") echo "技术文档撰写者" ;;
        "teacher") echo "教师" ;;
        "student") echo "学生" ;;
        "general_user") echo "普通用户" ;;
        *) echo "$1" ;;
    esac
}

# 获取角色配置 (规则|插件|技能|MCP)
get_role_config() {
    case "$1" in
        # 技术开发类
        "backend_engineer") echo "common,python,golang,typescript|typescript-lsp,kotlin-lsp,code-review,security-guidance|backend-patterns,api-design,database-migrations,postgres-patterns|postgres,redis" ;;
        "frontend_engineer") echo "common,typescript|typescript-lsp,frontend-design,figma|frontend-patterns,e2e-testing|figma" ;;
        "mobile_engineer") echo "common,swift,typescript|swift-lsp,kotlin-lsp,frontend-design|swiftui-patterns,swift-actor-persistence|firebase" ;;
        "fullstack_engineer") echo "common,typescript,python,golang|typescript-lsp,frontend-design,code-review,security-guidance,superpowers|frontend-patterns,backend-patterns,api-design,deployment-patterns,docker-patterns|postgres,redis,docker" ;;
        "ai_engineer") echo "common,python|feature-dev,code-review|foundation-models-on-device,agent-harness-construction,continuous-learning,eval-harness|huggingface,wandb" ;;
        "data_engineer") echo "common,python|code-review,qodo-skills|postgres-patterns,clickhouse-io,database-migrations,python-patterns|postgres,clickhouse" ;;

        # 运维安全类
        "devops_engineer") echo "common,golang|code-review,security-guidance|deployment-patterns,docker-patterns,continuous-agent-loop|kubernetes,docker" ;;
        "security_engineer") echo "common|security-guidance,code-review|security-scan,django-security,springboot-security|sonarqube" ;;

        # 质量保障类
        "test_engineer") echo "common,python,typescript|playground,code-review|e2e-testing,python-testing,golang-testing,verification-loop|playwright" ;;

        # 架构管理类
        "architect") echo "common,typescript,python,golang|superpowers,feature-dev,claude-md-management,skill-creator|agentic-engineering,ai-first-engineering,iterative-retrieval,eval-harness|" ;;
        "business_manager") echo "common|linear,claude-md-management,playground|market-research,investor-materials,investor-outreach,article-writing|notion,linear" ;;
        "project_manager") echo "common|linear,claude-md-management,playground|article-writing,frontend-slides,market-research|linear,notion" ;;
        "product_manager") echo "common|figma,linear,claude-md-management,playground|market-research,investor-materials,article-writing,frontend-slides|figma,linear,notion" ;;

        # 设计类
        "ui_ux_designer") echo "common|figma,frontend-design,playground|frontend-patterns,liquid-glass-design,frontend-slides,article-writing|figma" ;;

        # 内容创作类
        "content_creator") echo "common|figma,playground,skill-creator|content-engine,article-writing,frontend-slides,market-research|notion" ;;
        "tech_writer") echo "common|claude-md-management,skill-creator,playground|article-writing,frontend-slides|notion" ;;

        # 教育学习类
        "teacher") echo "common|playground,claude-md-management,figma,learning-output-style|article-writing,frontend-slides,content-engine|notion" ;;
        "student") echo "common|playground,learning-output-style,typescript-lsp,code-review|article-writing,python-patterns|github" ;;

        # 普通用户
        "general_user") echo "common|playground|article-writing|" ;;
        *) echo "" ;;
    esac
}

# Notebook LM 角色推荐程度
get_notebook_lm_recommendation() {
    case "$1" in
        "teacher"|"student") echo "5" ;;
        "content_creator"|"product_manager"|"business_manager") echo "4" ;;
        "architect"|"ai_engineer"|"data_engineer") echo "3" ;;
        "ui_ux_designer"|"project_manager"|"devops_engineer"|"security_engineer"|"test_engineer"|"backend_engineer"|"frontend_engineer"|"mobile_engineer"|"fullstack_engineer") echo "2" ;;
        "general_user") echo "2" ;;
        "tech_writer") echo "4" ;;
        *) echo "0" ;;
    esac
}

# 用户选择的角色
SELECTED_ROLES=""

# ------------------------------------------------------------------------------
# 工具函数
# ------------------------------------------------------------------------------

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗        ║"
    echo "║    ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝        ║"
    echo "║    ██║     ██║     ███████║██║   ██║██║  ██║█████╗          ║"
    echo "║    ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝          ║"
    echo "║    ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗        ║"
    echo "║     ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝        ║"
    echo "║                                                              ║"
    echo "║              Code CLI 安装配置脚本 v1.0.0                    ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  📌 $1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_option() {
    echo -e "  ${CYAN}[$1]${NC} $2"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 确认提示
confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local response

    # skip-confirm 模式下自动确认
    if [[ "$SKIP_CONFIRM" == "true" ]]; then
        [[ "$VERBOSE" == "true" ]] && echo -e "${CYAN}[自动确认] $prompt${NC}"
        return 0
    fi

    # dry-run 模式下显示预览
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${PURPLE}[DRY-RUN] 将询问: $prompt [默认: $default]${NC}"
        return 0
    fi

    if [[ "$default" == "y" ]]; then
        echo -en "${YELLOW}$prompt [Y/n]: ${NC}"
    else
        echo -en "${YELLOW}$prompt [y/N]: ${NC}"
    fi

    read -r response
    response="${response:-$default}"

    [[ "$response" =~ ^[Yy]$ ]]
}

# 获取用户输入（带默认值）
get_input() {
    local prompt="$1"
    local default="$2"
    local is_secret="${3:-false}"
    local response

    # dry-run 模式下返回默认值
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${PURPLE}[DRY-RUN] 输入: $prompt = ${default:-"(空)"}${NC}"
        echo "${default}"
        return
    fi

    if [[ -n "$default" ]]; then
        echo -en "${BLUE}$prompt [默认: $default]: ${NC}"
    else
        echo -en "${BLUE}$prompt: ${NC}"
    fi

    if [[ "$is_secret" == "true" ]]; then
        read -rs response
        echo
    else
        read -r response
    fi

    echo "${response:-$default}"
}

# ------------------------------------------------------------------------------
# 配置备份功能
# ------------------------------------------------------------------------------
backup_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$CLAUDE_DIR/backups/$timestamp"

    # dry-run 模式
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${PURPLE}[DRY-RUN] 将创建备份目录: $backup_dir${NC}"
        [[ -f "$SETTINGS_FILE" ]] && echo -e "${PURPLE}[DRY-RUN] 将备份: settings.json${NC}"
        [[ -f "$CONFIG_FILE" ]] && echo -e "${PURPLE}[DRY-RUN] 将备份: config.json${NC}"
        [[ -d "$RULES_DIR" ]] && echo -e "${PURPLE}[DRY-RUN] 将备份: rules/${NC}"
        return 0
    fi

    mkdir -p "$backup_dir"

    local backup_count=0

    if [[ -f "$SETTINGS_FILE" ]]; then
        cp "$SETTINGS_FILE" "$backup_dir/settings.json"
        ((backup_count++))
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$backup_dir/config.json"
        ((backup_count++))
    fi

    if [[ -d "$RULES_DIR" ]]; then
        cp -r "$RULES_DIR" "$backup_dir/rules"
        ((backup_count++))
    fi

    if [[ $backup_count -gt 0 ]]; then
        echo "$timestamp" > "$CLAUDE_DIR/backups/.latest"
        print_success "配置已备份到: $backup_dir ($backup_count 个文件)"
        return 0
    fi

    return 1
}

# 列出可用备份
list_backups() {
    local backup_dir="$CLAUDE_DIR/backups"

    if [[ ! -d "$backup_dir" ]]; then
        echo ""
        return 0
    fi

    ls -1 "$backup_dir" | grep -E "^[0-9]{8}_[0-9]{6}$" | sort -r
}

# 恢复配置
rollback_config() {
    local backups=$(list_backups)

    if [[ -z "$backups" ]]; then
        print_warning "没有可用的备份"
        return 1
    fi

    echo -e "\n${WHITE}━━━ 可用备份 ━━━${NC}"

    local i=1
    local backup_array=()
    for backup in $backups; do
        local date_str=$(echo "$backup" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
        echo -e "  ${CYAN}[$i]${NC} $date_str"
        backup_array+=("$backup")
        ((i++))
    done

    echo -e "  ${CYAN}[0]${NC} 取消"
    echo

    local choice
    echo -en "${BLUE}选择要恢复的备份 [0-$((i-1))]: ${NC}"
    read -r choice

    if [[ "$choice" == "0" ]] || [[ -z "$choice" ]]; then
        return 0
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#backup_array[@]} ]]; then
        local selected_backup="${backup_array[$((choice-1))]}"
        local backup_path="$CLAUDE_DIR/backups/$selected_backup"

        print_info "正在恢复备份..."

        if [[ -f "$backup_path/settings.json" ]]; then
            cp "$backup_path/settings.json" "$SETTINGS_FILE"
        fi

        if [[ -f "$backup_path/config.json" ]]; then
            cp "$backup_path/config.json" "$CONFIG_FILE"
        fi

        if [[ -d "$backup_path/rules" ]]; then
            rm -rf "$RULES_DIR"
            cp -r "$backup_path/rules" "$RULES_DIR"
        fi

        print_success "配置已恢复到: $(echo $selected_backup | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5/')"
        return 0
    fi

    print_error "无效选择"
    return 1
}

# ------------------------------------------------------------------------------
# 配置预览功能
# ------------------------------------------------------------------------------
preview_config() {
    echo -e "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}                      配置预览${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "  ${CYAN}API URL:${NC}      ${GREEN}$USER_BASE_URL${NC}"
    echo -e "  ${CYAN}API Key:${NC}      ${GREEN}$(echo $USER_API_KEY | sed 's/.\{4\}$/****/')${NC}"
    echo -e "  ${CYAN}模型:${NC}         ${GREEN}$USER_MODEL${NC}"
    echo -e "  ${CYAN}语言:${NC}         ${GREEN}$USER_LANGUAGE${NC}"
    echo
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}⚠️  重要提示:${NC}"
    echo -e "${YELLOW}  • 错误的 API URL 或模型名称可能导致按量计费${NC}"
    echo -e "${YELLOW}  • 请确认以上配置正确后再保存${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    if ! confirm "确认保存以上配置?" "y"; then
        return 1
    fi

    return 0
}

# ------------------------------------------------------------------------------
# 快捷配置模式
# ------------------------------------------------------------------------------
quick_setup_bailian() {
    echo -e "\n${WHITE}━━━ 快捷配置: 阿里云百炼月套餐 ━━━${NC}"
    echo
    echo -e "${GREEN}此模式将自动配置以下默认值:${NC}"
    echo -e "  ${CYAN}•${NC} API URL: https://coding.dashscope.aliyuncs.com/apps/anthropic"
    echo -e "  ${CYAN}•${NC} 主模型:   glm-5"
    echo -e "  ${CYAN}•${NC} 语言:      简体中文"
    echo

    # dry-run 模式
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${PURPLE}[DRY-RUN] 将提示输入 API Key${NC}"
        echo -e "${PURPLE}[DRY-RUN] 将验证 API 连接${NC}"
        echo -e "${PURPLE}[DRY-RUN] 将备份现有配置${NC}"
        echo -e "${PURPLE}[DRY-RUN] 将生成配置文件: $SETTINGS_FILE${NC}"
        return 0
    fi

    local api_key=$(get_input "请输入阿里云百炼 API Key" "" "true")

    if [[ -z "$api_key" ]]; then
        print_error "API Key 不能为空"
        return 1
    fi

    USER_BASE_URL="https://coding.dashscope.aliyuncs.com/apps/anthropic"
    USER_API_KEY="$api_key"
    USER_MODEL="glm-5"
    USER_LANGUAGE="简体中文"

    # API Key 存储方式选择
    echo
    print_info "选择 API Key 存储方式"
    configure_api_key_storage "$USER_API_KEY" "ANTHROPIC_AUTH_TOKEN" >/dev/null

    # 备份旧配置
    backup_config

    # 生成配置文件
    mkdir -p "$CLAUDE_DIR"

    # 检测存储方式并生成对应配置
    local storage_method
    storage_method=$(detect_api_key_storage "ANTHROPIC_AUTH_TOKEN")

    case "$storage_method" in
        "environment")
            cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "\${ANTHROPIC_AUTH_TOKEN}",
    "ANTHROPIC_BASE_URL": "${USER_BASE_URL}",
    "ANTHROPIC_MODEL": "${USER_MODEL}"
  },
  "model": "${USER_MODEL}",
  "language": "${USER_LANGUAGE}"
}
EOF
            print_success "API Key 已安全存储在环境变量中"
            ;;
        "keyring")
            cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "\$(~/.claude/scripts/get-api-key.sh anthropic-api-key 2>/dev/null || echo '')",
    "ANTHROPIC_BASE_URL": "${USER_BASE_URL}",
    "ANTHROPIC_MODEL": "${USER_MODEL}"
  },
  "model": "${USER_MODEL}",
  "language": "${USER_LANGUAGE}"
}
EOF
            print_success "API Key 已安全存储在系统密钥环中"
            ;;
        *)
            cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "${USER_API_KEY}",
    "ANTHROPIC_BASE_URL": "${USER_BASE_URL}",
    "ANTHROPIC_MODEL": "${USER_MODEL}"
  },
  "model": "${USER_MODEL}",
  "language": "${USER_LANGUAGE}"
}
EOF
            print_warning "API Key 以明文存储在配置文件中"
            ;;
    esac

    # 跳过官方登录流程
    skip_onboarding

    print_success "快捷配置完成!"
    if [[ $verify_result -ne 0 ]]; then
        print_warning "请运行 'echo hi | claude -p' 测试 API 连接"
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 配置导出/导入功能
# ------------------------------------------------------------------------------
export_config() {
    local export_path="${1:-$HOME/claude-config-export.json}"

    echo -e "\n${WHITE}━━━ 导出配置 ━━━${NC}"

    if [[ ! -f "$SETTINGS_FILE" ]]; then
        print_error "没有可导出的配置"
        return 1
    fi

    # 读取配置并脱敏
    local config=$(cat "$SETTINGS_FILE")

    # 脱敏 API Key
    config=$(echo "$config" | sed 's/"ANTHROPIC_AUTH_TOKEN": "[^"]*"/"ANTHROPIC_AUTH_TOKEN": "***YOUR_API_KEY***"/g')

    # 添加导出信息
    local export_content=$(cat << EOF
{
  "_export_info": {
    "exported_at": "$(date -Iseconds)",
    "script_version": "1.0.0",
    "note": "API Key 已脱敏，导入时需要重新填写"
  },
  "settings": $config
}
EOF
)

    echo "$export_content" > "$export_path"
    print_success "配置已导出到: $export_path"
    print_warning "注意: API Key 已脱敏，导入时需要重新填写"
}

import_config() {
    local import_path="$1"

    if [[ -z "$import_path" ]]; then
        echo -e "\n${WHITE}━━━ 导入配置 ━━━${NC}"
        echo -e "${CYAN}请输入配置文件路径:${NC}"
        read -r import_path
    fi

    if [[ ! -f "$import_path" ]]; then
        print_error "文件不存在: $import_path"
        return 1
    fi

    # 读取配置
    local config=$(cat "$import_path")

    # 检查是否是导出格式
    if echo "$config" | grep -q "_export_info"; then
        config=$(echo "$config" | grep -A 1000 '"settings"' | sed 's/.*"settings": //' | sed 's/}$//')
    fi

    # 提取配置值
    local base_url=$(echo "$config" | grep -o '"ANTHROPIC_BASE_URL": "[^"]*"' | sed 's/.*: "//;s/"$//')
    local model=$(echo "$config" | grep -o '"ANTHROPIC_MODEL": "[^"]*"' | head -n 1 | sed 's/.*: "//;s/"$//')

    # 检查是否需要填写 API Key
    if echo "$config" | grep -q "YOUR_API_KEY"; then
        echo -e "\n${YELLOW}配置文件中的 API Key 已脱敏，需要重新填写${NC}"
        local api_key=$(get_input "请输入 API Key" "" "true")

        if [[ -z "$api_key" ]]; then
            print_error "API Key 不能为空"
            return 1
        fi

        config=$(echo "$config" | sed "s/YOUR_API_KEY/$api_key/g")
    fi

    # 备份当前配置
    backup_config

    # 保存导入的配置
    echo "$config" > "$SETTINGS_FILE"

    print_success "配置已导入"
    print_info "API URL: $base_url"
    print_info "模型: $model"
}

# 选择菜单（单选）
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected

    echo -e "\n${CYAN}$prompt${NC}"
    echo -e "${CYAN}─────────────────────────────────────${NC}"

    local i=1
    for opt in "${options[@]}"; do
        echo -e "  ${WHITE}$i)${NC} $opt"
        ((i++))
    done

    echo -e "  ${WHITE}0)${NC} 跳过"
    echo -e "${CYAN}─────────────────────────────────────${NC}"

    while true; do
        echo -en "${BLUE}请选择 [0-${#options[@]}]: ${NC}"
        read -r selected

        if [[ "$selected" == "0" ]]; then
            echo ""
            return 0
        fi

        if [[ "$selected" =~ ^[0-9]+$ ]] && [[ "$selected" -ge 1 ]] && [[ "$selected" -le ${#options[@]} ]]; then
            echo "${options[$((selected-1))]}"
            return $((selected-1))
        fi

        print_error "无效选择，请重新输入"
    done
}

# 多选菜单
select_multiple() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=()
    local choices

    echo -e "\n${CYAN}$prompt${NC}"
    echo -e "${CYAN}─────────────────────────────────────${NC}"

    local i=1
    for opt in "${options[@]}"; do
        echo -e "  ${WHITE}$i)${NC} $opt"
        ((i++))
    done

    echo -e "${CYAN}─────────────────────────────────────${NC}"
    echo -e "${BLUE}输入编号（多个用空格分隔，0 表示全部，回车跳过）: ${NC}"

    while true; do
        read -r choices

        if [[ -z "$choices" ]]; then
            break
        fi

        if [[ "$choices" == "0" ]]; then
            selected=("${options[@]}")
            break
        fi

        local valid=true
        for choice in $choices; do
            if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#options[@]} ]]; then
                valid=false
                break
            fi
        done

        if [[ "$valid" == "true" ]]; then
            for choice in $choices; do
                selected+=("${options[$((choice-1))]}")
            done
            break
        fi

        print_error "无效输入，请重新选择"
    done

    echo "${selected[@]}"
}

# ------------------------------------------------------------------------------
# 职业角色选择
# ------------------------------------------------------------------------------
select_roles() {
    print_step "职业角色选择"

    echo -e "${CYAN}请选择您的职业角色，系统将自动为您配置专业技能:${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}\n"

    SELECTED_ROLES=""

    # 显示角色分类
    echo -e "${WHITE}📂 技术开发类${NC}"
    for role in "${TECH_ROLE_NAMES[@]}"; do
        echo -e "  ${CYAN}•${NC} $(get_role_name "$role")"
    done

    echo -e "\n${WHITE}📂 运维安全类${NC}"
    for role in "${OPS_ROLE_NAMES[@]}"; do
        echo -e "  ${CYAN}•${NC} $(get_role_name "$role")"
    done

    echo -e "\n${WHITE}📂 质量保障类${NC}"
    for role in "${QUALITY_ROLE_NAMES[@]}"; do
        echo -e "  ${CYAN}•${NC} $(get_role_name "$role")"
    done

    echo -e "\n${WHITE}📂 架构管理类${NC}"
    for role in "${ARCH_ROLE_NAMES[@]}"; do
        echo -e "  ${CYAN}•${NC} $(get_role_name "$role")"
    done

    echo -e "\n${WHITE}📂 设计类${NC}"
    for role in "${DESIGN_ROLE_NAMES[@]}"; do
        echo -e "  ${CYAN}•${NC} $(get_role_name "$role")"
    done

    echo -e "\n${WHITE}📂 内容创作类${NC}"
    for role in "${CONTENT_ROLE_NAMES[@]}"; do
        echo -e "  ${CYAN}•${NC} $(get_role_name "$role")"
    done

    echo -e "\n${WHITE}📂 教育学习类${NC}"
    for role in "${EDUCATION_ROLE_NAMES[@]}"; do
        echo -e "  ${CYAN}•${NC} $(get_role_name "$role")"
    done

    echo -e "\n${WHITE}📂 普通用户${NC}"
    for role in "${GENERAL_ROLE_NAMES[@]}"; do
        echo -e "  ${CYAN}•${NC} $(get_role_name "$role")"
    done

    echo -e "\n${CYAN}─────────────────────────────────────────────────────────────${NC}"

    # 构建所有角色列表
    local all_roles=()
    local all_role_names=()

    # 合并所有角色
    for role in "${TECH_ROLE_NAMES[@]}"; do
        all_roles+=("$role")
        all_role_names+=("$(get_role_name "$role")")
    done
    for role in "${OPS_ROLE_NAMES[@]}"; do
        all_roles+=("$role")
        all_role_names+=("$(get_role_name "$role")")
    done
    for role in "${QUALITY_ROLE_NAMES[@]}"; do
        all_roles+=("$role")
        all_role_names+=("$(get_role_name "$role")")
    done
    for role in "${ARCH_ROLE_NAMES[@]}"; do
        all_roles+=("$role")
        all_role_names+=("$(get_role_name "$role")")
    done
    for role in "${DESIGN_ROLE_NAMES[@]}"; do
        all_roles+=("$role")
        all_role_names+=("$(get_role_name "$role")")
    done
    for role in "${CONTENT_ROLE_NAMES[@]}"; do
        all_roles+=("$role")
        all_role_names+=("$(get_role_name "$role")")
    done
    for role in "${EDUCATION_ROLE_NAMES[@]}"; do
        all_roles+=("$role")
        all_role_names+=("$(get_role_name "$role")")
    done
    for role in "${GENERAL_ROLE_NAMES[@]}"; do
        all_roles+=("$role")
        all_role_names+=("$(get_role_name "$role")")
    done

    # 交互式选择
    echo -e "\n${BLUE}请输入角色编号（多个用空格分隔，0 表示跳过）: ${NC}"
    echo -e "${BLUE}例如: 1 3 5 表示选择第1、3、5个角色${NC}\n"

    local i=1
    for name in "${all_role_names[@]}"; do
        printf "  ${WHITE}%2d)${NC} %s\n" "$i" "$name"
        ((i++))
    done

    echo
    echo -en "${BLUE}请选择: ${NC}"
    read -r choices

    if [[ -z "$choices" ]]; then
        print_info "跳过角色选择，将使用默认配置"
        return 0
    fi

    # 解析选择
    for choice in $choices; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#all_roles[@]} ]]; then
            local role_key="${all_roles[$((choice-1))]}"
            if [[ -z "$SELECTED_ROLES" ]]; then
                SELECTED_ROLES="$role_key"
            else
                SELECTED_ROLES="$SELECTED_ROLES $role_key"
            fi
            print_success "已选择: ${all_role_names[$((choice-1))]}"
        fi
    done

    if [[ -z "$SELECTED_ROLES" ]]; then
        print_info "未选择任何角色，将使用默认配置"
    else
        print_info "已选择角色: $SELECTED_ROLES"
    fi

    echo
}

# ------------------------------------------------------------------------------
# 文档分析服务配置 (支持多种方案)
# ------------------------------------------------------------------------------
configure_document_analysis() {
    print_step "文档分析服务配置"

    echo -e "${CYAN}文档分析服务可以基于上传的文档进行智能问答、摘要生成等操作${NC}\n"

    # 检查是否有推荐角色
    local recommend_level=0
    for role in $SELECTED_ROLES; do
        local level=$(get_notebook_lm_recommendation "$role")
        if [[ "$level" -gt "$recommend_level" ]]; then
            recommend_level="$level"
        fi
    done

    if [[ "$recommend_level" -ge 4 ]]; then
        print_info "根据您选择的角色，强烈推荐配置文档分析服务"
        echo -e "${CYAN}适用场景: 文档分析、研究学习、内容创作${NC}"
    elif [[ "$recommend_level" -ge 3 ]]; then
        print_info "根据您选择的角色，推荐配置文档分析服务"
    fi

    # 显示选项
    echo
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  请选择文档分析服务:${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${GREEN}[1] Open NotebookLM 本地部署 (推荐)${NC}"
    echo -e "    ${CYAN}•${NC} 完全离线运行，数据隐私安全"
    echo -e "    ${CYAN}•${NC} 支持 PDF/Docx/网页/TXT"
    echo -e "    ${CYAN}•${NC} 国内可直接访问 GitHub 安装"
    echo -e "    ${CYAN}•${NC} 可配合阿里云百炼 API 使用"
    echo -e "    ${CYAN}•${NC} 项目: github.com/gabrielchua/open-notebooklm"
    echo
    echo -e "${CYAN}[2]${NC} 阿里云百炼文档理解"
    echo -e "    ${CYAN}•${NC} 已配置 API，开箱即用"
    echo -e "    ${CYAN}•${NC} 国内访问稳定"
    echo -e "    ${CYAN}•${NC} 支持长文档、多格式"
    echo
    echo -e "${CYAN}[3]${NC} 跳过配置"
    echo
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local choice
    echo -en "${BLUE}请选择 [1-3]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            configure_open_notebooklm
            ;;
        2)
            configure_bailian_doc
            ;;
        3)
            print_info "跳过文档分析服务配置"
            ;;
        *)
            print_warning "无效选择，跳过配置"
            ;;
    esac

    echo
}

# ------------------------------------------------------------------------------
# Open NotebookLM 本地部署配置
# ------------------------------------------------------------------------------
configure_open_notebooklm() {
    echo -e "\n${WHITE}━━━ Open NotebookLM 本地部署 ━━━${NC}"
    echo
    echo -e "${GREEN}Open NotebookLM 是 NotebookLM 的开源替代方案${NC}"
    echo -e "${GREEN}支持完全本地运行，保护数据隐私${NC}\n"

    echo -e "${WHITE}部署方式选择:${NC}"
    echo -e "  ${CYAN}[1]${NC} 使用阿里云百炼 API (推荐国内用户)"
    echo -e "  ${CYAN}[2]${NC} 使用本地 Ollama 模型"
    echo -e "  ${CYAN}[3]${NC} 使用 DeepSeek API"
    echo -e "  ${CYAN}[4]${NC} 仅获取安装指南，稍后手动配置"
    echo

    local deploy_choice
    echo -en "${BLUE}请选择 [1-4]: ${NC}"
    read -r deploy_choice

    case "$deploy_choice" in
        1)
            # 使用阿里云百炼 API (月套餐模型)
            echo
            print_info "配置 Open NotebookLM + 阿里云百炼 (月套餐模型)"

            local api_key=$(get_input "阿里云百炼 API Key" "$USER_API_KEY" "true")
            if [[ -z "$api_key" ]]; then
                print_error "API Key 不能为空"
                return 1
            fi

            echo
            echo -e "${WHITE}模型配置 (月套餐推荐):${NC}"
            echo -e "  ${CYAN}[1]${NC} 使用默认月套餐模型 (glm-5 + qwen3.5-plus)"
            echo -e "  ${CYAN}[2]${NC} 自定义模型配置"
            echo
            local model_choice
            echo -en "${BLUE}请选择 [1-2]: ${NC}"
            read -r model_choice

            local main_model="glm-5"
            local second_model="qwen3.5-plus"

            if [[ "$model_choice" == "2" ]]; then
                main_model=$(get_input "主模型名称" "glm-5")
                second_model=$(get_input "第二模型名称" "qwen3.5-plus")
            fi

            # 生成配置
            cat > "$CLAUDE_DIR/open-notebooklm-config.json" << EOF
{
  "llm_provider": "openai",
  "api_key": "${api_key}",
  "base_url": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
  "model": "${main_model}",
  "second_model": "${second_model}",
  "embedding_model": "text-embedding-v3",
  "embedding_base_url": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
  "description": "阿里云百炼月套餐模型配置"
}
EOF

            print_success "配置已保存到: $CLAUDE_DIR/open-notebooklm-config.json"
            echo
            echo -e "${WHITE}模型配置:${NC}"
            echo -e "  主模型: ${GREEN}${main_model}${NC}"
            echo -e "  第二模型: ${GREEN}${second_model}${NC}"
            echo -e "  Embedding: ${GREEN}text-embedding-v3${NC}"
            ;;
        2)
            # 使用本地 Ollama
            print_info "配置 Open NotebookLM + Ollama 本地模型"

            if ! command_exists ollama; then
                print_warning "Ollama 未安装"
                echo -e "${CYAN}安装 Ollama: https://ollama.ai${NC}"
                echo
                if confirm "是否现在安装 Ollama?" "y"; then
                    curl -fsSL https://ollama.ai/install.sh | sh
                fi
            fi

            local ollama_model=$(get_input "Ollama 模型名称" "qwen2.5:7b")

            cat > "$CLAUDE_DIR/open-notebooklm-config.json" << EOF
{
  "llm_provider": "ollama",
  "ollama_base_url": "http://localhost:11434",
  "model": "${ollama_model}",
  "embedding_model": "all-MiniLM-L6-v2"
}
EOF

            print_success "配置已保存"
            print_info "请确保 Ollama 已运行: ollama serve"
            print_info "拉取模型: ollama pull $ollama_model"
            ;;
        3)
            # 使用 DeepSeek API
            print_info "配置 Open NotebookLM + DeepSeek"

            local deepseek_key=$(get_input "DeepSeek API Key" "" "true")
            if [[ -z "$deepseek_key" ]]; then
                print_error "API Key 不能为空"
                return 1
            fi

            cat > "$CLAUDE_DIR/open-notebooklm-config.json" << EOF
{
  "llm_provider": "openai",
  "api_key": "${deepseek_key}",
  "base_url": "https://api.deepseek.com/v1",
  "model": "deepseek-chat",
  "embedding_model": "all-MiniLM-L6-v2"
}
EOF

            print_success "配置已保存"
            ;;
        4)
            # 仅显示安装指南
            print_info "Open NotebookLM 安装指南:"
            echo
            echo -e "${WHITE}1. 克隆项目:${NC}"
            echo -e "   git clone https://github.com/gabrielchua/open-notebooklm.git"
            echo
            echo -e "${WHITE}2. 安装依赖:${NC}"
            echo -e "   cd open-notebooklm"
            echo -e "   pip install -r requirements.txt"
            echo
            echo -e "${WHITE}3. 配置环境变量:${NC}"
            echo -e "   复制 .env.example 为 .env 并填写配置"
            echo
            echo -e "${WHITE}4. 启动服务:${NC}"
            echo -e "   python app.py"
            echo
            echo -e "${WHITE}5. 访问界面:${NC}"
            echo -e "   http://localhost:7860"
            echo
            echo -e "${WHITE}Ollama 本地模型 (可选):${NC}"
            echo -e "   安装: curl -fsSL https://ollama.ai/install.sh | sh"
            echo -e "   运行: ollama serve"
            echo -e "   拉取模型: ollama pull qwen2.5:7b"
            echo
            echo -e "${WHITE}衍生项目 (完全本地化):${NC}"
            echo -e "   codeberg.org/research_coder/open-notebooklm-ollama"
            echo
            ;;
    esac

    print_success "Open NotebookLM 配置完成"
}

# ------------------------------------------------------------------------------
# 阿里云百炼文档理解配置
# ------------------------------------------------------------------------------
configure_bailian_doc() {
    echo -e "\n${WHITE}━━━ 阿里云百炼文档理解 ━━━${NC}\n"

    local api_key=$(get_input "阿里云百炼 API Key" "$USER_API_KEY" "true")
    if [[ -z "$api_key" ]]; then
        print_error "API Key 不能为空"
        return 1
    fi

    # 更新或创建 MCP 配置
    local mcp_config="\"bailian-doc\": {
      \"command\": \"npx\",
      \"args\": [\"-y\", \"mcp-server-bailian\"],
      \"env\": {
        \"DASHSCOPE_API_KEY\": \"${api_key}\",
        \"DASHSCOPE_BASE_URL\": \"https://coding.dashscope.aliyuncs.com/apps/anthropic\"
      }
    }"

    update_mcp_config "bailian-doc" "$mcp_config"
    print_success "阿里云百炼文档理解配置完成"
}

# ------------------------------------------------------------------------------
# 文档处理增强模块
# ------------------------------------------------------------------------------
configure_document_processor_enhanced() {
    echo -e "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           文档处理增强配置${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    echo -e "${GREEN}支持功能:${NC}"
    echo -e "  ${CYAN}•${NC} 多格式解析 (PDF/Word/Excel/PPT/TXT)"
    echo -e "  ${CYAN}•${NC} 智能摘要生成"
    echo -e "  ${CYAN}•${NC} 格式转换 (PDF↔Word↔Markdown)"
    echo -e "  ${CYAN}•${NC} 表格提取"
    echo -e "  ${CYAN}•${NC} 批量处理"
    echo

    echo -e "${WHITE}请选择处理方式:${NC}"
    echo -e "  ${GREEN}[1]${NC} 本地处理 (Python) - 数据不出本地"
    echo -e "  ${CYAN}[2]${NC} 云端处理 (API) - 能力更强"
    echo -e "  ${CYAN}[3]${NC} 跳过配置"
    echo

    local choice
    echo -en "${BLUE}请选择 [1-3]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            install_document_processor_local
            ;;
        2)
            configure_document_processor_cloud
            ;;
        3)
            print_info "跳过文档处理增强配置"
            ;;
        *)
            print_warning "无效选择"
            return 1
            ;;
    esac
}

# 本地文档处理安装
install_document_processor_local() {
    echo -e "\n${WHITE}━━━ 安装本地文档处理工具 ━━━${NC}\n"

    # 检查 Python
    if ! command_exists python3; then
        print_error "需要先安装 Python 3"
        return 1
    fi

    print_info "安装文档处理依赖..."

    # 核心文档处理库
    local packages=(
        "unstructured"
        "PyMuPDF"
        "python-docx"
        "openpyxl"
        "python-pptx"
        "pandas"
        "beautifulsoup4"
        "lxml"
        "markdown"
        "pdfplumber"
    )

    # 安装依赖
    pip3 install "${packages[@]}" 2>/dev/null || {
        print_error "安装失败，请手动执行:"
        echo "pip3 install unstructured PyMuPDF python-docx openpyxl python-pptx pandas beautifulsoup4 lxml markdown pdfplumber"
        return 1
    }

    # 创建配置文件
    cat > "$CLAUDE_DIR/document-processor-config.json" << EOF
{
  "provider": "local",
  "python_path": "$(which python3)",
  "supported_formats": ["pdf", "docx", "xlsx", "pptx", "txt", "md", "html"],
  "output_dir": "$HOME/document_output",
  "features": {
    "parse": true,
    "summarize": true,
    "convert": true,
    "extract_tables": true
  }
}
EOF

    mkdir -p "$HOME/document_output"

    print_success "本地文档处理工具安装完成"
    print_info "已安装: unstructured, PyMuPDF, python-docx, openpyxl, python-pptx"
}

# 云端文档处理配置
configure_document_processor_cloud() {
    echo -e "\n${WHITE}━━━ 云端文档处理配置 ━━━${NC}\n"

    echo -e "${WHITE}请选择云端服务:${NC}"
    echo -e "  ${GREEN}[1]${NC} 阿里云文档智能"
    echo -e "  ${CYAN}[2]${NC} Open NotebookLM API"
    echo

    local choice
    echo -en "${BLUE}请选择 [1-2]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            local api_key=$(get_input "阿里云 API Key" "" "true")
            if [[ -z "$api_key" ]]; then
                print_error "API Key 不能为空"
                return 1
            fi

            cat > "$CLAUDE_DIR/document-processor-config.json" << EOF
{
  "provider": "alibaba",
  "api_key": "${api_key}",
  "endpoint": "https://ocr-api.cn-hangzhou.aliyuncs.com",
  "features": {
    "parse": true,
    "summarize": true,
    "convert": false,
    "extract_tables": true
  }
}
EOF
            print_success "阿里云文档智能配置完成"
            ;;
        2)
            configure_open_notebooklm
            ;;
        *)
            print_warning "无效选择"
            return 1
            ;;
    esac

    chmod 600 "$CLAUDE_DIR/document-processor-config.json"
}

# ------------------------------------------------------------------------------
# 数据分析增强模块
# ------------------------------------------------------------------------------
configure_data_analysis_enhanced() {
    echo -e "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           数据分析增强配置${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    echo -e "${GREEN}支持功能:${NC}"
    echo -e "  ${CYAN}•${NC} 智能数据清洗"
    echo -e "  ${CYAN}•${NC} 可视化报表生成"
    echo -e "  ${CYAN}•${NC} 数据对比分析"
    echo -e "  ${CYAN}•${NC} SQL 查询生成"
    echo -e "  ${CYAN}•${NC} 自动化报告输出"
    echo

    echo -e "${WHITE}请选择处理方式:${NC}"
    echo -e "  ${GREEN}[1]${NC} 本地处理 (Python) - 数据不出本地"
    echo -e "  ${CYAN}[2]${NC} 云端处理 (API) - 能力更强"
    echo -e "  ${CYAN}[3]${NC} 跳过配置"
    echo

    local choice
    echo -en "${BLUE}请选择 [1-3]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            install_data_analysis_local
            ;;
        2)
            configure_data_analysis_cloud
            ;;
        3)
            print_info "跳过数据分析增强配置"
            ;;
        *)
            print_warning "无效选择"
            return 1
            ;;
    esac
}

# 本地数据分析安装
install_data_analysis_local() {
    echo -e "\n${WHITE}━━━ 安装本地数据分析工具 ━━━${NC}\n"

    # 检查 Python
    if ! command_exists python3; then
        print_error "需要先安装 Python 3"
        return 1
    fi

    print_info "安装数据分析依赖..."

    # 数据分析核心库
    local packages=(
        "pandas"
        "numpy"
        "matplotlib"
        "seaborn"
        "plotly"
        "scipy"
        "scikit-learn"
        "openpyxl"
        "xlrd"
        "jinja2"
        "tabulate"
    )

    # 安装依赖
    pip3 install "${packages[@]}" 2>/dev/null || {
        print_error "安装失败，请手动执行:"
        echo "pip3 install pandas numpy matplotlib seaborn plotly scipy scikit-learn openpyxl xlrd jinja2 tabulate"
        return 1
    }

    # 创建配置文件
    cat > "$CLAUDE_DIR/data-analysis-config.json" << EOF
{
  "provider": "local",
  "python_path": "$(which python3)",
  "output_dir": "$HOME/analysis_output",
  "default_chart_format": "png",
  "figure_dpi": 150,
  "features": {
    "data_cleaning": true,
    "visualization": true,
    "comparison": true,
    "sql_generation": true,
    "auto_report": true
  }
}
EOF

    mkdir -p "$HOME/analysis_output"

    print_success "本地数据分析工具安装完成"
    print_info "已安装: pandas, numpy, matplotlib, seaborn, plotly, scipy, scikit-learn"
}

# 云端数据分析配置
configure_data_analysis_cloud() {
    echo -e "\n${WHITE}━━━ 云端数据分析配置 ━━━${NC}\n"

    local api_key=$(get_input "API Key" "" "true")
    if [[ -z "$api_key" ]]; then
        print_error "API Key 不能为空"
        return 1
    fi

    local api_url=$(get_input "API URL" "https://coding.dashscope.aliyuncs.com/apps/anthropic")

    cat > "$CLAUDE_DIR/data-analysis-config.json" << EOF
{
  "provider": "cloud",
  "api_key": "${api_key}",
  "api_url": "${api_url}",
  "features": {
    "data_cleaning": true,
    "visualization": true,
    "comparison": true,
    "sql_generation": true,
    "auto_report": true
  }
}
EOF

    chmod 600 "$CLAUDE_DIR/data-analysis-config.json"
    print_success "云端数据分析配置完成"
}

# ------------------------------------------------------------------------------
# 翻译服务模块
# ------------------------------------------------------------------------------
configure_translation_service() {
    echo -e "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           翻译服务配置${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    echo -e "${GREEN}支持功能:${NC}"
    echo -e "  ${CYAN}•${NC} 多语言翻译"
    echo -e "  ${CYAN}•${NC} 文档翻译"
    echo -e "  ${CYAN}•${NC} 实时翻译"
    echo

    echo -e "${WHITE}请选择处理方式:${NC}"
    echo -e "  ${GREEN}[1]${NC} 本地处理 - 数据不出本地"
    echo -e "  ${CYAN}[2]${NC} 云端处理 (API) - 翻译质量更高"
    echo -e "  ${CYAN}[3]${NC} 跳过配置"
    echo

    local choice
    echo -en "${BLUE}请选择 [1-3]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            install_translation_local
            ;;
        2)
            configure_translation_cloud
            ;;
        3)
            print_info "跳过翻译服务配置"
            ;;
        *)
            print_warning "无效选择"
            return 1
            ;;
    esac
}

# 本地翻译安装
install_translation_local() {
    echo -e "\n${WHITE}━━━ 安装本地翻译工具 ━━━${NC}\n"

    if ! command_exists python3; then
        print_error "需要先安装 Python 3"
        return 1
    fi

    print_info "安装翻译依赖..."

    pip3 install deep-translator translatepy 2>/dev/null || {
        print_error "安装失败，请手动执行:"
        echo "pip3 install deep-translator translatepy"
        return 1
    }

    cat > "$CLAUDE_DIR/translation-config.json" << EOF
{
  "provider": "local",
  "python_path": "$(which python3)",
  "default_source": "auto",
  "default_target": "zh",
  "supported_languages": ["zh", "en", "ja", "ko", "fr", "de", "es", "ru"]
}
EOF

    print_success "本地翻译工具安装完成"
    print_info "支持语言: 中文、英文、日文、韩文、法文、德文、西班牙文、俄文"
}

# 云端翻译配置
configure_translation_cloud() {
    echo -e "\n${WHITE}━━━ 云端翻译配置 ━━━${NC}\n"

    echo -e "${WHITE}请选择翻译服务:${NC}"
    echo -e "  ${GREEN}[1]${NC} 阿里云机器翻译"
    echo -e "  ${CYAN}[2]${NC} DeepL API"
    echo -e "  ${CYAN}[3]${NC} 自定义 API"
    echo

    local choice
    echo -en "${BLUE}请选择 [1-3]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            local api_key=$(get_input "阿里云 API Key" "" "true")
            if [[ -z "$api_key" ]]; then
                print_error "API Key 不能为空"
                return 1
            fi

            cat > "$CLAUDE_DIR/translation-config.json" << EOF
{
  "provider": "alibaba",
  "api_key": "${api_key}",
  "endpoint": "https://mt.cn-hangzhou.aliyuncs.com",
  "default_source": "auto",
  "default_target": "zh"
}
EOF
            print_success "阿里云翻译配置完成"
            ;;
        2)
            local api_key=$(get_input "DeepL API Key" "" "true")
            if [[ -z "$api_key" ]]; then
                print_error "API Key 不能为空"
                return 1
            fi

            cat > "$CLAUDE_DIR/translation-config.json" << EOF
{
  "provider": "deepl",
  "api_key": "${api_key}",
  "endpoint": "https://api.deepl.com/v2",
  "default_source": "auto",
  "default_target": "ZH"
}
EOF
            print_success "DeepL 翻译配置完成"
            ;;
        3)
            local api_url=$(get_input "API URL" "")
            local api_key=$(get_input "API Key" "" "true")

            cat > "$CLAUDE_DIR/translation-config.json" << EOF
{
  "provider": "custom",
  "api_url": "${api_url}",
  "api_key": "${api_key}",
  "default_source": "auto",
  "default_target": "zh"
}
EOF
            print_success "自定义翻译 API 配置完成"
            ;;
        *)
            print_warning "无效选择"
            return 1
            ;;
    esac

    chmod 600 "$CLAUDE_DIR/translation-config.json"
}

# ------------------------------------------------------------------------------
# 更新 MCP 配置的辅助函数
# ------------------------------------------------------------------------------
update_mcp_config() {
    local server_name="$1"
    local server_config="$2"

    print_info "更新 MCP 配置..."

    if [[ -f "$CONFIG_FILE" ]]; then
        # 已有配置文件，追加或更新
        if command_exists jq; then
            local temp_file=$(mktemp)
            jq ".mcpServers += {\"${server_name}\": $(echo "$server_config" | jq -R . | jq -s .[0])}" "$CONFIG_FILE" > "$temp_file" 2>/dev/null || {
                print_warning "使用简单方式更新配置"
                echo "$server_config" >> "$CLAUDE_DIR/${server_name}-config.json"
            }
            [[ -f "$temp_file" ]] && mv "$temp_file" "$CONFIG_FILE"
        else
            # 没有 jq，创建单独配置文件
            echo "$server_config" > "$CLAUDE_DIR/${server_name}-config.json"
            print_info "配置已保存到: $CLAUDE_DIR/${server_name}-config.json"
        fi
    else
        # 创建新的配置文件
        cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    ${server_config}
  }
}
EOF
    fi

    chmod 600 "$CONFIG_FILE"
}

# 保留旧函数名作为别名
configure_notebook_lm() {
    configure_document_analysis
}

# ------------------------------------------------------------------------------
# P1: 语音转文字服务配置
# ------------------------------------------------------------------------------
configure_speech_to_text() {
    echo -e "\n${WHITE}━━━ 语音转文字服务配置 ━━━${NC}"
    echo
    echo -e "${GREEN}语音转文字服务支持:${NC}"
    echo -e "  ${CYAN}•${NC} 会议录音转写"
    echo -e "  ${CYAN}•${NC} 实时语音转文字"
    echo -e "  ${CYAN}•${NC} 视频字幕生成"
    echo

    echo -e "${WHITE}请选择语音服务:${NC}"
    echo -e "  ${GREEN}[1]${NC} 阿里云语音识别 (推荐国内用户)"
    echo -e "  ${CYAN}[2]${NC} OpenAI Whisper API"
    echo -e "  ${CYAN}[3]${NC} 本地 Whisper 模型"
    echo -e "  ${CYAN}[4]${NC} 跳过配置"
    echo

    local choice
    echo -en "${BLUE}请选择 [1-4]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            configure_alibaba_asr
            ;;
        2)
            configure_openai_whisper
            ;;
        3)
            install_local_whisper
            ;;
        4)
            print_info "跳过语音转文字配置"
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac
}

configure_alibaba_asr() {
    echo -e "\n${WHITE}━━━ 阿里云语音识别 ━━━${NC}\n"

    local api_key=$(get_input "阿里云 API Key (AppKey)" "" "true")
    if [[ -z "$api_key" ]]; then
        print_error "API Key 不能为空"
        return 1
    fi

    local app_key=$(get_input "ASR AppKey" "")
    local access_key=$(get_input "AccessKey ID" "" "true")
    local access_secret=$(get_input "AccessKey Secret" "" "true")

    # 生成配置文件
    cat > "$CLAUDE_DIR/asr-config.json" << EOF
{
  "provider": "alibaba",
  "app_key": "${app_key}",
  "access_key_id": "${access_key}",
  "access_key_secret": "${access_secret}",
  "region": "cn-shanghai",
  "format": "pcm",
  "sample_rate": 16000
}
EOF

    chmod 600 "$CLAUDE_DIR/asr-config.json"
    print_success "阿里云语音识别配置完成"
    print_info "获取 AppKey: https://nls-portal.console.aliyun.com/"
}

configure_openai_whisper() {
    echo -e "\n${WHITE}━━━ OpenAI Whisper API ━━━${NC}\n"

    local api_key=$(get_input "OpenAI API Key" "" "true")
    if [[ -z "$api_key" ]]; then
        print_error "API Key 不能为空"
        return 1
    fi

    local base_url=$(get_input "API Base URL" "https://api.openai.com/v1")

    # 更新 MCP 配置
    local mcp_config="\"whisper\": {
      \"command\": \"npx\",
      \"args\": [\"-y\", \"mcp-server-whisper\"],
      \"env\": {
        \"OPENAI_API_KEY\": \"${api_key}\",
        \"OPENAI_BASE_URL\": \"${base_url}\"
      }
    }"

    update_mcp_config "whisper" "$mcp_config"
    print_success "OpenAI Whisper 配置完成"
}

install_local_whisper() {
    echo -e "\n${WHITE}━━━ 本地 Whisper 安装 ━━━${NC}\n"

    # 检查 Python
    if ! command_exists python3; then
        print_error "需要先安装 Python 3"
        return 1
    fi

    print_info "安装 Whisper 及依赖..."

    # 安装 Whisper
    pip3 install openai-whisper ffmpeg-python 2>/dev/null || {
        print_error "安装失败，请手动执行: pip3 install openai-whisper ffmpeg-python"
        return 1
    }

    # 检查 ffmpeg
    if ! command_exists ffmpeg; then
        print_warning "ffmpeg 未安装，语音处理需要此依赖"
        if [[ "$(uname)" == "Darwin" ]]; then
            print_info "安装命令: brew install ffmpeg"
        else
            print_info "安装命令: apt install ffmpeg 或 yum install ffmpeg"
        fi
    fi

    # 生成配置
    cat > "$CLAUDE_DIR/whisper-local-config.json" << EOF
{
  "provider": "local",
  "model": "base",
  "device": "auto",
  "language": "zh"
}
EOF

    print_success "本地 Whisper 安装完成"
    print_info "使用方法: whisper audio.mp3 --language zh --model base"
}

# ------------------------------------------------------------------------------
# P1: 数据分析服务配置
# ------------------------------------------------------------------------------
configure_data_analysis() {
    echo -e "\n${WHITE}━━━ 数据分析服务配置 ━━━${NC}"
    echo
    echo -e "${GREEN}数据分析服务支持:${NC}"
    echo -e "  ${CYAN}•${NC} Excel/CSV 表格处理"
    echo -e "  ${CYAN}•${NC} 数据清洗与转换"
    echo -e "  ${CYAN}•${NC} 图表生成与可视化"
    echo -e "  ${CYAN}•${NC} 统计分析与报表输出"
    echo

    echo -e "${WHITE}请选择配置方式:${NC}"
    echo -e "  ${GREEN}[1]${NC} 安装本地数据分析工具 (推荐)"
    echo -e "  ${CYAN}[2]${NC} 配置云端数据分析 API"
    echo -e "  ${CYAN}[3]${NC} 跳过配置"
    echo

    local choice
    echo -en "${BLUE}请选择 [1-3]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            install_data_analysis_tools
            ;;
        2)
            configure_cloud_analysis
            ;;
        3)
            print_info "跳过数据分析配置"
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac
}

install_data_analysis_tools() {
    echo -e "\n${WHITE}━━━ 安装数据分析工具 ━━━${NC}\n"

    # 检查 Python
    if ! command_exists python3; then
        print_error "需要先安装 Python 3"
        return 1
    fi

    print_info "安装 Python 数据分析库..."

    # 核心数据分析库
    local packages=(
        "pandas"
        "numpy"
        "matplotlib"
        "seaborn"
        "openpyxl"
        "xlrd"
        "python-docx"
        "python-pptx"
        "plotly"
        "scipy"
        "scikit-learn"
    )

    pip3 install "${packages[@]}" 2>/dev/null || {
        print_error "安装失败，请手动执行"
        echo "pip3 install pandas numpy matplotlib seaborn openpyxl python-docx python-pptx plotly scipy scikit-learn"
        return 1
    }

    # 创建数据分析配置
    cat > "$CLAUDE_DIR/data-analysis-config.json" << EOF
{
  "provider": "local",
  "python_path": "$(which python3)",
  "packages": ["pandas", "numpy", "matplotlib", "seaborn", "openpyxl"],
  "output_dir": "$HOME/analysis_output",
  "default_format": "png",
  "figure_dpi": 150
}
EOF

    mkdir -p "$HOME/analysis_output"

    print_success "数据分析工具安装完成"
    print_info "已安装: pandas, numpy, matplotlib, seaborn, openpyxl 等"
}

configure_cloud_analysis() {
    echo -e "\n${WHITE}━━━ 云端数据分析 API ━━━${NC}\n"

    echo -e "${WHITE}请选择云端服务:${NC}"
    echo -e "  ${CYAN}[1]${NC} 阿里云数据分析"
    echo -e "  ${CYAN}[2]${NC} 自定义 API"
    echo

    local cloud_choice
    echo -en "${BLUE}请选择 [1-2]: ${NC}"
    read -r cloud_choice

    case "$cloud_choice" in
        1)
            local api_key=$(get_input "阿里云 API Key" "" "true")
            if [[ -z "$api_key" ]]; then
                print_error "API Key 不能为空"
                return 1
            fi

            cat > "$CLAUDE_DIR/data-analysis-config.json" << EOF
{
  "provider": "alibaba",
  "api_key": "${api_key}",
  "endpoint": "https://dataanalysis.cn-shanghai.aliyuncs.com"
}
EOF
            print_success "阿里云数据分析配置完成"
            ;;
        2)
            local api_url=$(get_input "API URL" "")
            local api_key=$(get_input "API Key" "" "true")

            cat > "$CLAUDE_DIR/data-analysis-config.json" << EOF
{
  "provider": "custom",
  "api_url": "${api_url}",
  "api_key": "${api_key}"
}
EOF
            print_success "自定义 API 配置完成"
            ;;
    esac

    chmod 600 "$CLAUDE_DIR/data-analysis-config.json"
}

# ------------------------------------------------------------------------------
# P1: 任务管理服务配置
# ------------------------------------------------------------------------------
configure_task_management() {
    echo -e "\n${WHITE}━━━ 任务管理服务配置 ━━━${NC}"
    echo
    echo -e "${GREEN}任务管理服务支持:${NC}"
    echo -e "  ${CYAN}•${NC} 待办清单管理"
    echo -e "  ${CYAN}•${NC} 项目进度跟踪"
    echo -e "  ${CYAN}•${NC} 提醒通知"
    echo -e "  ${CYAN}•${NC} 团队协作"
    echo

    echo -e "${WHITE}请选择任务管理工具:${NC}"
    echo -e "  ${GREEN}[1]${NC} Linear (推荐)"
    echo -e "  ${CYAN}[2]${NC} 本地任务管理"
    echo -e "  ${CYAN}[3]${NC} 配置 Notion"
    echo -e "  ${CYAN}[4]${NC} 跳过配置"
    echo

    local choice
    echo -en "${BLUE}请选择 [1-4]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            configure_linear_task
            ;;
        2)
            configure_local_tasks
            ;;
        3)
            configure_notion
            ;;
        4)
            print_info "跳过任务管理配置"
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac
}

configure_linear_task() {
    echo -e "\n${WHITE}━━━ Linear 任务管理 ━━━${NC}\n"

    print_info "Linear 是一个现代化的项目管理工具"
    print_info "官网: https://linear.app"
    echo

    local api_key=$(get_input "Linear API Key" "" "true")
    if [[ -z "$api_key" ]]; then
        print_error "API Key 不能为空"
        return 1
    fi

    # 更新 MCP 配置
    local mcp_config="\"linear\": {
      \"command\": \"npx\",
      \"args\": [\"-y\", \"mcp-server-linear\"],
      \"env\": {
        \"LINEAR_API_KEY\": \"${api_key}\"
      }
    }"

    update_mcp_config "linear" "$mcp_config"

    # 更新 settings.json 启用 Linear 插件
    if [[ -f "$SETTINGS_FILE" ]]; then
        # 使用 Python 添加插件（如果已安装 jq 则使用 jq）
        if command_exists python3; then
            python3 -c "
import json
with open('$SETTINGS_FILE', 'r') as f:
    config = json.load(f)
if 'enabledPlugins' not in config:
    config['enabledPlugins'] = {}
config['enabledPlugins']['linear@claude-plugins-official'] = True
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(config, f, indent=2)
" 2>/dev/null || print_warning "请手动启用 Linear 插件"
        fi
    fi

    print_success "Linear 配置完成"
    print_info "获取 API Key: https://linear.app/settings/api"
}

configure_local_tasks() {
    echo -e "\n${WHITE}━━━ 本地任务管理 ━━━${NC}\n"

    local tasks_dir="$HOME/.claude/tasks"

    mkdir -p "$tasks_dir"

    # 创建任务管理配置
    cat > "$CLAUDE_DIR/task-config.json" << EOF
{
  "provider": "local",
  "tasks_dir": "${tasks_dir}",
  "reminder_enabled": true,
  "default_priority": "medium",
  "categories": ["work", "personal", "study", "other"]
}
EOF

    # 创建示例任务文件
    cat > "$tasks_dir/tasks.json" << EOF
{
  "tasks": [],
  "created_at": "$(date -Iseconds)"
}
EOF

    print_success "本地任务管理配置完成"
    print_info "任务文件位置: $tasks_dir"
}

configure_notion() {
    echo -e "\n${WHITE}━━━ Notion 集成 ━━━${NC}\n"

    print_info "Notion 是一个强大的知识管理和协作工具"
    print_info "官网: https://notion.so"
    echo

    local api_key=$(get_input "Notion Integration Token" "" "true")
    if [[ -z "$api_key" ]]; then
        print_error "Token 不能为空"
        return 1
    fi

    local database_id=$(get_input "Database ID (可选)" "")

    # 更新 MCP 配置
    local mcp_config
    if [[ -n "$database_id" ]]; then
        mcp_config="\"notion\": {
      \"command\": \"npx\",
      \"args\": [\"-y\", \"@anthropic/mcp-server-notion\"],
      \"env\": {
        \"NOTION_API_KEY\": \"${api_key}\",
        \"NOTION_DATABASE_ID\": \"${database_id}\"
      }
    }"
    else
        mcp_config="\"notion\": {
      \"command\": \"npx\",
      \"args\": [\"-y\", \"@anthropic/mcp-server-notion\"],
      \"env\": {
        \"NOTION_API_KEY\": \"${api_key}\"
      }
    }"
    fi

    update_mcp_config "notion" "$mcp_config"
    print_success "Notion 配置完成"
    print_info "获取 Token: https://www.notion.so/my-integrations"
}

# ------------------------------------------------------------------------------
# 办公能力综合配置入口
# ------------------------------------------------------------------------------
configure_office_tools() {
    echo -e "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}                    办公能力配置${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    echo -e "${WHITE}请选择要配置的办公能力:${NC}"
    echo
    echo -e "  ${GREEN}[1]${NC} 文档处理增强 - 多格式解析、智能摘要、格式转换"
    echo -e "  ${GREEN}[2]${NC} 数据分析增强 - 数据清洗、可视化报表、对比分析"
    echo -e "  ${GREEN}[3]${NC} 翻译服务 - 多语言翻译、文档翻译"
    echo -e "  ${CYAN}[4]${NC} 语音转文字 - 会议录音、实时转写"
    echo -e "  ${CYAN}[5]${NC} 任务管理 - 待办清单、进度跟踪"
    echo -e "  ${CYAN}[6]${NC} 全部配置 (推荐)"
    echo -e "  ${CYAN}[7]${NC} 跳过配置"
    echo

    local choice
    echo -en "${BLUE}请选择 [1-7]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            configure_document_processor_enhanced
            ;;
        2)
            configure_data_analysis_enhanced
            ;;
        3)
            configure_translation_service
            ;;
        4)
            configure_speech_to_text
            ;;
        5)
            configure_task_management
            ;;
        6)
            print_info "配置所有办公能力..."
            configure_document_processor_enhanced
            echo
            configure_data_analysis_enhanced
            echo
            configure_translation_service
            echo
            configure_speech_to_text
            echo
            configure_task_management
            print_success "办公能力配置完成"
            ;;
        7)
            print_info "跳过办公能力配置"
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 根据角色自动配置
# ------------------------------------------------------------------------------
apply_role_config() {
    if [[ -z "$SELECTED_ROLES" ]]; then
        print_info "未选择角色，跳过自动配置"
        return 0
    fi

    print_step "根据角色自动配置技能"

    # 收集所有角色的配置
    local all_rules="common"
    local all_plugins=""
    local all_skills=""
    local all_mcp=""

    for role in $SELECTED_ROLES; do
        local config=$(get_role_config "$role")

        if [[ -n "$config" ]]; then
            # 解析配置: 规则|插件|技能|MCP
            IFS='|' read -r rules plugins skills mcp <<< "$config"

            # 合并规则（去重）
            for rule in ${rules//,/ }; do
                if [[ ! " $all_rules " =~ " $rule " ]]; then
                    all_rules="$all_rules $rule"
                fi
            done

            # 合并插件
            for plugin in ${plugins//,/ }; do
                if [[ -n "$plugin" ]] && [[ ! " $all_plugins " =~ " $plugin " ]]; then
                    all_plugins="$all_plugins $plugin"
                fi
            done

            # 合并技能
            for skill in ${skills//,/ }; do
                if [[ -n "$skill" ]] && [[ ! " $all_skills " =~ " $skill " ]]; then
                    all_skills="$all_skills $skill"
                fi
            done

            # 合并 MCP
            for m in ${mcp//,/ }; do
                if [[ -n "$m" ]] && [[ ! " $all_mcp " =~ " $m " ]]; then
                    all_mcp="$all_mcp $m"
                fi
            done
        fi
    done

    # 显示配置预览
    echo -e "${WHITE}━━━ 配置预览 ━━━${NC}\n"

    echo -e "${CYAN}📁 Rules 规则集:${NC}"
    for rule in $all_rules; do
        echo -e "   ${GREEN}✓${NC} $rule"
    done

    if [[ -n "$all_plugins" ]]; then
        echo -e "\n${CYAN}🔌 Plugins 插件:${NC}"
        for plugin in $all_plugins; do
            echo -e "   ${GREEN}✓${NC} $plugin"
        done
    fi

    if [[ -n "$all_skills" ]]; then
        echo -e "\n${CYAN}🎯 Skills 技能:${NC}"
        for skill in $all_skills; do
            echo -e "   ${GREEN}✓${NC} $skill"
        done
    fi

    if [[ -n "$all_mcp" ]]; then
        echo -e "\n${CYAN}🔗 MCP Servers:${NC}"
        for m in $all_mcp; do
            echo -e "   ${GREEN}✓${NC} $m"
        done
    fi

    echo

    if ! confirm "是否应用以上配置?" "y"; then
        print_info "跳过自动配置"
        return 0
    fi

    # 安装规则
    if [[ -n "$all_rules" ]]; then
        print_info "安装规则集..."
        mkdir -p "$RULES_DIR"

        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local rules_source="$script_dir/rules"

        for rule in $all_rules; do
            if [[ -d "$rules_source/$rule" ]]; then
                mkdir -p "$RULES_DIR/$rule"
                cp -r "$rules_source/$rule/"* "$RULES_DIR/$rule/" 2>/dev/null || true
                print_success "$rule 规则集安装完成"
            fi
        done
    fi

    # 安装插件
    if [[ -n "$all_plugins" ]] && command_exists claude; then
        print_info "安装插件..."
        for plugin in $all_plugins; do
            print_info "安装 $plugin..."
            if claude plugins install "$plugin" 2>/dev/null; then
                print_success "$plugin 安装成功"
            else
                print_warning "$plugin 安装失败或已安装"
            fi
        done
    fi

    print_success "角色配置应用完成"
    echo
}

# ------------------------------------------------------------------------------
# 系统检测
# ------------------------------------------------------------------------------
check_system() {
    print_step "系统环境检测"

    # 检测操作系统
    local os_name=""
    case "$(uname -s)" in
        Darwin*)    os_name="macOS" ;;
        Linux*)     os_name="Linux" ;;
        *)          os_name="未知" ;;
    esac

    print_info "操作系统: $os_name ($(uname -m))"

    # 检测包管理器
    local pkg_manager=""
    if command_exists brew; then
        pkg_manager="brew"
    elif command_exists apt; then
        pkg_manager="apt"
    elif command_exists yum; then
        pkg_manager="yum"
    elif command_exists dnf; then
        pkg_manager="dnf"
    fi

    if [[ -n "$pkg_manager" ]]; then
        print_success "包管理器: $pkg_manager"
    else
        print_warning "未检测到包管理器"
    fi

    # 检测 Node.js
    if command_exists node; then
        local node_version=$(node -v 2>/dev/null)
        print_success "Node.js: $node_version"

        # 检查版本 >= 18
        local major_version=$(echo "$node_version" | sed 's/v\([0-9]*\).*/\1/')
        if [[ "$major_version" -lt 18 ]]; then
            print_warning "Node.js 版本过低，建议升级到 18 或更高版本"
        fi
    else
        print_warning "Node.js 未安装"
    fi

    # 检测 npm
    if command_exists npm; then
        local npm_version=$(npm -v 2>/dev/null)
        print_success "npm: $npm_version"
    else
        print_warning "npm 未安装"
    fi

    # 检测 Claude Code
    if command_exists claude; then
        local claude_version=$(claude --version 2>/dev/null || echo "已安装")
        print_success "Claude Code: $claude_version"
    else
        print_info "Claude Code 未安装"
    fi

    echo
}

# ------------------------------------------------------------------------------
# 依赖安装
# ------------------------------------------------------------------------------
install_dependencies() {
    print_step "依赖安装"

    local need_install=false

    # 检查 Node.js
    if ! command_exists node; then
        print_warning "需要安装 Node.js"
        need_install=true
    else
        local major_version=$(node -v 2>/dev/null | sed 's/v\([0-9]*\).*/\1/')
        if [[ "$major_version" -lt 18 ]]; then
            print_warning "Node.js 版本过低，需要升级"
            need_install=true
        fi
    fi

    if [[ "$need_install" == "true" ]]; then
        if confirm "是否安装/升级 Node.js?" "y"; then
            case "$(uname -s)" in
                Darwin*)
                    if command_exists brew; then
                        print_info "使用 Homebrew 安装 Node.js..."
                        brew install node
                    else
                        print_error "请先安装 Homebrew: https://brew.sh"
                        exit 1
                    fi
                    ;;
                Linux*)
                    if command_exists apt; then
                        print_info "使用 apt 安装 Node.js..."
                        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
                        sudo apt install -y nodejs
                    elif command_exists yum; then
                        print_info "使用 yum 安装 Node.js..."
                        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
                        sudo yum install -y nodejs
                    else
                        print_error "请手动安装 Node.js"
                        exit 1
                    fi
                    ;;
            esac
            print_success "Node.js 安装完成"
        else
            print_error "无法继续，请先安装 Node.js >= 18"
            exit 1
        fi
    else
        print_success "依赖已满足"
    fi

    echo
}

# ------------------------------------------------------------------------------
# 跳过 Claude Code Onboarding（跳过官方登录）
# ------------------------------------------------------------------------------
skip_onboarding() {
    print_info "配置跳过 Claude Code 官方登录..."

    # 检查 ~/.claude.json 是否存在
    if [[ -f "$CLAUDE_JSON_FILE" ]]; then
        # 读取现有配置
        local existing_config=$(cat "$CLAUDE_JSON_FILE" 2>/dev/null)

        # 检查是否已有 hasCompletedOnboarding 字段
        if echo "$existing_config" | grep -q "hasCompletedOnboarding"; then
            # 更新字段值为 true
            if command_exists jq; then
                jq '.hasCompletedOnboarding = true' "$CLAUDE_JSON_FILE" > /tmp/claude_json_temp.json
                mv /tmp/claude_json_temp.json "$CLAUDE_JSON_FILE"
            else
                # 使用 sed 替换
                if [[ "$(uname)" == "Darwin" ]]; then
                    sed -i '' 's/"hasCompletedOnboarding": [^,}]*/"hasCompletedOnboarding": true/' "$CLAUDE_JSON_FILE" 2>/dev/null || {
                        # 如果 sed 失败，直接覆盖
                        echo '{"hasCompletedOnboarding": true}' > "$CLAUDE_JSON_FILE"
                    }
                else
                    sed -i 's/"hasCompletedOnboarding": [^,}]*/"hasCompletedOnboarding": true/' "$CLAUDE_JSON_FILE" 2>/dev/null || {
                        echo '{"hasCompletedOnboarding": true}' > "$CLAUDE_JSON_FILE"
                    }
                fi
            fi
        else
            # 添加 hasCompletedOnboarding 字段
            if command_exists jq; then
                jq '. + {"hasCompletedOnboarding": true}' "$CLAUDE_JSON_FILE" > /tmp/claude_json_temp.json
                mv /tmp/claude_json_temp.json "$CLAUDE_JSON_FILE"
            else
                # 手动合并 JSON
                local temp_file=$(mktemp)
                echo "$existing_config" | sed 's/}$/,"hasCompletedOnboarding": true}/' > "$temp_file"
                mv "$temp_file" "$CLAUDE_JSON_FILE"
            fi
        fi
    else
        # 创建新的 ~/.claude.json 文件
        cat > "$CLAUDE_JSON_FILE" << EOF
{
  "hasCompletedOnboarding": true
}
EOF
    fi

    print_success "已配置跳过官方登录 (hasCompletedOnboarding: true)"
    print_info "配置文件: $CLAUDE_JSON_FILE"
    print_info "此配置可避免启动时报错: Unable to connect to Anthropic services"
}

# ------------------------------------------------------------------------------
# Claude Code 安装
# ------------------------------------------------------------------------------
install_claude_code() {
    print_step "Claude Code 安装"

    # dry-run 模式
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${PURPLE}[DRY-RUN] 检查 Claude Code 是否已安装...${NC}"
        if command_exists claude; then
            echo -e "${PURPLE}[DRY-RUN] Claude Code 已安装，将询问是否重装${NC}"
        else
            echo -e "${PURPLE}[DRY-RUN] 将执行: npm install -g @anthropic-ai/claude-code${NC}"
            echo -e "${PURPLE}[DRY-RUN] 将创建配置目录: $CLAUDE_DIR${NC}"
        fi
        return 0
    fi

    if command_exists claude; then
        print_info "Claude Code 已安装"
        if confirm "是否重新安装?" "n"; then
            print_info "卸载现有版本..."
            npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
        else
            return 0
        fi
    fi

    print_info "正在安装 Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code

    if command_exists claude; then
        print_success "Claude Code 安装成功 ($(claude --version 2>/dev/null || echo '安装完成'))"
    else
        print_error "Claude Code 安装失败"
        exit 1
    fi

    # 创建配置目录
    print_info "创建配置目录..."
    mkdir -p "$CLAUDE_DIR"
    mkdir -p "$RULES_DIR"
    mkdir -p "$CLAUDE_DIR/plugins"
    mkdir -p "$CLAUDE_DIR/projects"

    print_success "配置目录创建完成"

    # 跳过官方登录流程（阿里云百炼用户必须）
    skip_onboarding

    echo
}

# ------------------------------------------------------------------------------
# API Key 安全存储功能
# ------------------------------------------------------------------------------

# API Key 存储方式选择
configure_api_key_storage() {
    local api_key="$1"
    local api_name="${2:-ANTHROPIC_AUTH_TOKEN}"

    echo -e "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           API Key 存储方式选择${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    echo -e "${YELLOW}⚠️  安全提示: API Key 是敏感信息，请选择安全的存储方式${NC}"
    echo

    echo -e "${WHITE}请选择存储方式:${NC}"
    echo
    echo -e "  ${CYAN}[1]${NC} 配置文件存储 (简单)"
    echo -e "      ${YELLOW}⚠️  存储在 ~/.claude/settings.json${NC}"
    echo -e "      ${YELLOW}⚠️  文件泄露风险${NC}"
    echo
    echo -e "  ${GREEN}[2]${NC} 环境变量存储 (推荐)${NC}"
    echo -e "      ${GREEN}✅ 存储在 shell 配置文件${NC}"
    echo -e "      ${GREEN}✅ 配置文件不含敏感信息${NC}"
    echo
    echo -e "  ${GREEN}[3]${NC} 系统密钥环存储 (最安全)${NC}"
    echo -e "      ${GREEN}✅ macOS Keychain / Linux secret${NC}"
    echo -e "      ${GREEN}✅ 系统级加密保护${NC}"
    echo

    local choice
    echo -en "${BLUE}请选择 [1-3]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            store_api_in_config "$api_key" "$api_name"
            echo "config"
            ;;
        2)
            store_api_in_env "$api_key" "$api_name"
            echo "env"
            ;;
        3)
            store_api_in_keyring "$api_key" "$api_name"
            echo "keyring"
            ;;
        *)
            print_warning "无效选择，使用配置文件存储"
            store_api_in_config "$api_key" "$api_name"
            echo "config"
            ;;
    esac
}

# 配置文件存储（传统方式）
store_api_in_config() {
    local api_key="$1"
    local api_name="${2:-ANTHROPIC_AUTH_TOKEN}"

    print_info "API Key 将存储在配置文件中"
    print_warning "请注意保护配置文件安全"

    # 返回实际值，调用者会写入配置文件
    echo "$api_key"
}

# 环境变量存储
store_api_in_env() {
    local api_key="$1"
    local api_name="${2:-ANTHROPIC_AUTH_TOKEN}"

    print_info "将 API Key 存储到环境变量..."

    # 确定 shell 配置文件
    local shell_rc=""
    if [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]]; then
        if [[ -f "$HOME/.bashrc" ]]; then
            shell_rc="$HOME/.bashrc"
        else
            shell_rc="$HOME/.bash_profile"
        fi
    else
        shell_rc="$HOME/.profile"
    fi

    # 检查是否已存在
    if grep -q "export ${api_name}=" "$shell_rc" 2>/dev/null; then
        # 更新已存在的环境变量
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "s|export ${api_name}=.*|export ${api_name}=\"${api_key}\"|" "$shell_rc"
        else
            sed -i "s|export ${api_name}=.*|export ${api_name}=\"${api_key}\"|" "$shell_rc"
        fi
    else
        # 添加新的环境变量
        echo "" >> "$shell_rc"
        echo "# Claude Code API Key (added by install script)" >> "$shell_rc"
        echo "export ${api_name}=\"${api_key}\"" >> "$shell_rc"
    fi

    # 导出到当前会话
    export "${api_name}=${api_key}"

    print_success "API Key 已存储到: $shell_rc"
    print_info "请运行 'source $shell_rc' 或重新打开终端使环境变量生效"

    # 返回环境变量引用
    echo "\${${api_name}}"
}

# 系统密钥环存储
store_api_in_keyring() {
    local api_key="$1"
    local api_name="${2:-ANTHROPIC_AUTH_TOKEN}"

    local os_type="$(uname)"

    if [[ "$os_type" == "Darwin" ]]; then
        # macOS Keychain
        print_info "将 API Key 存储到 macOS Keychain..."

        # 检查 security 命令
        if ! command_exists security; then
            print_error "security 命令不可用"
            print_info "回退到环境变量存储"
            store_api_in_env "$api_key" "$api_name"
            return
        fi

        # 删除已存在的条目（如果有）
        security delete-generic-password -a "claude-code" -s "${api_name}" 2>/dev/null || true

        # 存储到 Keychain
        security add-generic-password -a "claude-code" -s "${api_name}" -w "${api_key}" -U

        print_success "API Key 已存储到 macOS Keychain"
        print_info "服务名称: ${api_name}"

        # 创建读取脚本
        create_keyring_reader_script "$api_name"

        # 返回命令引用
        echo "\$(security find-generic-password -a 'claude-code' -s '${api_name}' -w 2>/dev/null)"

    else
        # Linux - 使用 secret-tool (libsecret)
        print_info "将 API Key 存储到系统密钥环..."

        if ! command_exists secret-tool; then
            print_warning "secret-tool 未安装"
            echo -e "${CYAN}安装方法:${NC}"
            echo -e "  Debian/Ubuntu: sudo apt install libsecret-tools"
            echo -e "  Fedora: sudo dnf install libsecret"
            echo -e "  Arch: sudo pacman -S libsecret"
            echo
            print_info "回退到环境变量存储"
            store_api_in_env "$api_key" "$api_name"
            return
        fi

        # 存储到密钥环
        echo -n "${api_key}" | secret-tool store --label="Claude Code ${api_name}" service "${api_name}" user "claude-code"

        print_success "API Key 已存储到系统密钥环"

        # 返回命令引用
        echo "\$(secret-tool lookup service '${api_name}' user 'claude-code' 2>/dev/null)"
    fi
}

# 创建密钥环读取辅助脚本
create_keyring_reader_script() {
    local api_name="$1"
    local script_dir="$HOME/.claude/bin"
    local script_path="${script_dir}/get-${api_name}.sh"

    mkdir -p "$script_dir"

    cat > "$script_path" << 'SCRIPT_EOF'
#!/bin/bash
# 从系统密钥环读取 API Key
if [[ "$(uname)" == "Darwin" ]]; then
    security find-generic-password -a "claude-code" -s "API_NAME" -w 2>/dev/null
else
    secret-tool lookup service "API_NAME" user "claude-code" 2>/dev/null
fi
SCRIPT_EOF

    # 替换占位符
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/API_NAME/${api_name}/g" "$script_path"
    else
        sed -i "s/API_NAME/${api_name}/g" "$script_path"
    fi

    chmod +x "$script_path"
}

# 检测当前 API Key 存储方式
detect_api_key_storage() {
    local api_name="${1:-ANTHROPIC_AUTH_TOKEN}"

    # 检查环境变量
    if [[ -n "${!api_name}" ]]; then
        echo "env"
        return 0
    fi

    # 检查 shell 配置文件
    local shell_rc=""
    if [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]]; then
        shell_rc="$HOME/.bashrc"
    fi

    if [[ -n "$shell_rc" ]] && grep -q "export ${api_name}=" "$shell_rc" 2>/dev/null; then
        echo "env"
        return 0
    fi

    # 检查密钥环 (macOS)
    if [[ "$(uname)" == "Darwin" ]]; then
        if security find-generic-password -a "claude-code" -s "${api_name}" 2>/dev/null; then
            echo "keyring"
            return 0
        fi
    fi

    # 检查密钥环 (Linux)
    if command_exists secret-tool; then
        if secret-tool lookup service "${api_name}" user "claude-code" 2>/dev/null; then
            echo "keyring"
            return 0
        fi
    fi

    # 默认为配置文件
    echo "config"
}

# ------------------------------------------------------------------------------
# AI Provider 配置
# ------------------------------------------------------------------------------
configure_ai_provider() {
    print_step "AI Provider 配置"

    # 配置模式选择
    echo -e "${WHITE}请选择配置模式:${NC}"
    echo -e "  ${GREEN}[1]${NC} 快捷配置 - 阿里云百炼月套餐 (推荐)"
    echo -e "  ${CYAN}[2]${NC} 自定义配置"
    echo -e "  ${CYAN}[3]${NC} 导入配置文件"
    echo -e "  ${CYAN}[4]${NC} 恢复备份配置"
    echo

    local mode_choice
    echo -en "${BLUE}请选择 [1-4]: ${NC}"
    read -r mode_choice

    case "$mode_choice" in
        1)
            quick_setup_bailian
            return $?
            ;;
        3)
            import_config
            return $?
            ;;
        4)
            rollback_config
            return $?
            ;;
    esac

    # 自定义配置流程
    echo -e "\n${CYAN}配置说明:${NC}"
    echo -e "  - base_url: API 端点 URL（如阿里云百炼、DeepSeek 等）"
    echo -e "  - api_key: API 密钥"
    echo -e "  - model_name: 默认模型名称"
    echo

    # 重要警告
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}⚠️  重要警告：Base URL 和模型设置错误可能导致按量计费！${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}• 请确认您使用的是正确的 API 端点和模型名称${NC}"
    echo -e "${YELLOW}• 阿里云百炼月套餐用户建议使用快捷配置${NC}"
    echo -e "${YELLOW}• 错误配置可能导致调用非套餐模型，产生额外费用${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    # 交互式输入
    USER_BASE_URL=$(get_input "API Base URL" "https://coding.dashscope.aliyuncs.com/apps/anthropic")
    USER_API_KEY=$(get_input "API Key" "" "true")

    if [[ -z "$USER_API_KEY" ]]; then
        print_error "API Key 不能为空"
        return 1
    fi

    USER_MODEL=$(get_input "默认模型名称" "glm-5")

    # 选择语言
    echo
    print_info "选择界面语言"
    local languages=("简体中文" "English" "日本語" "한국어")
    local lang=$(select_option "选择语言" "${languages[@]}")
    if [[ -n "$lang" ]]; then
        USER_LANGUAGE="$lang"
    fi

    # API Key 存储方式选择
    echo
    print_info "选择 API Key 存储方式"
    local stored_key
    stored_key=$(configure_api_key_storage "$USER_API_KEY" "ANTHROPIC_AUTH_TOKEN")
    # 如果返回的是环境变量引用或密钥环引用，存储方式已处理
    # 如果返回的是原始 key，说明用户选择了配置文件存储

    # 配置预览
    if ! preview_config; then
        print_info "配置已取消"
        return 1
    fi

    # 备份旧配置
    backup_config

    # 生成 settings.json
    print_info "生成配置文件..."

    mkdir -p "$CLAUDE_DIR"

    # 检测存储方式并生成对应配置
    local storage_method
    storage_method=$(detect_api_key_storage "ANTHROPIC_AUTH_TOKEN")

    case "$storage_method" in
        "environment")
            # 环境变量存储 - 配置文件使用环境变量引用
            cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "\${ANTHROPIC_AUTH_TOKEN}",
    "ANTHROPIC_BASE_URL": "${USER_BASE_URL}",
    "ANTHROPIC_MODEL": "${USER_MODEL}"
  },
  "model": "${USER_MODEL}",
  "language": "${USER_LANGUAGE}"
}
EOF
            print_success "API Key 已安全存储在环境变量中"
            ;;
        "keyring")
            # 密钥环存储 - 使用 wrapper 脚本获取
            cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "\$(~/.claude/scripts/get-api-key.sh anthropic-api-key 2>/dev/null || echo '')",
    "ANTHROPIC_BASE_URL": "${USER_BASE_URL}",
    "ANTHROPIC_MODEL": "${USER_MODEL}"
  },
  "model": "${USER_MODEL}",
  "language": "${USER_LANGUAGE}"
}
EOF
            print_success "API Key 已安全存储在系统密钥环中"
            ;;
        *)
            # 配置文件存储（传统方式）
            cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "${USER_API_KEY}",
    "ANTHROPIC_BASE_URL": "${USER_BASE_URL}",
    "ANTHROPIC_MODEL": "${USER_MODEL}"
  },
  "model": "${USER_MODEL}",
  "language": "${USER_LANGUAGE}"
}
EOF
            print_warning "API Key 以明文存储在配置文件中，建议使用更安全的存储方式"
            ;;
    esac

    # 设置文件权限
    chmod 600 "$SETTINGS_FILE"

    # 跳过官方登录流程
    skip_onboarding

    print_success "AI Provider 配置完成"
    print_info "配置文件: $SETTINGS_FILE"
    echo
}

# ------------------------------------------------------------------------------
# 安装测试
# ------------------------------------------------------------------------------
test_installation() {
    print_step "安装验证"

    # 验证 CLI
    print_info "验证 Claude Code CLI..."
    if claude --version >/dev/null 2>&1; then
        print_success "CLI 安装正常 ($(claude --version 2>/dev/null | head -n 1))"
    else
        print_error "CLI 安装异常"
        return 1
    fi

    # 验证配置文件
    print_info "验证配置文件..."
    if [[ -f "$SETTINGS_FILE" ]]; then
        print_success "settings.json 存在"
    else
        print_warning "settings.json 不存在"
    fi

    echo
}

# ------------------------------------------------------------------------------
# 插件安装
# ------------------------------------------------------------------------------
install_plugins() {
    print_step "官方插件安装"

    if ! command_exists claude; then
        print_error "Claude Code 未安装，无法安装插件"
        return 1
    fi

    # 获取已安装插件
    print_info "检查已安装插件..."
    local installed_plugins=$(claude plugins list 2>/dev/null || echo "")

    if [[ -n "$installed_plugins" ]]; then
        print_info "已安装插件:"
        echo "$installed_plugins"
    fi

    # 显示可选插件
    echo
    print_info "可用插件列表:"
    echo

    local plugin_names=()

    # 基础插件
    echo -e "${WHITE}  📦 基础插件${NC}"
    for name in "${BASIC_PLUGIN_NAMES[@]}"; do
        plugin_names+=("$name")
        printf "    ${CYAN}%-20s${NC} %s\n" "$name" "$(get_plugin_desc "$name")"
    done

    echo

    # 开发支持插件
    echo -e "${WHITE}  🛠️  开发支持插件${NC}"
    for name in "${DEV_PLUGIN_NAMES[@]}"; do
        plugin_names+=("$name")
        printf "    ${CYAN}%-20s${NC} %s\n" "$name" "$(get_plugin_desc "$name")"
    done

    echo

    # 选择要安装的插件
    local selected=$(select_multiple "选择要安装的插件" "${plugin_names[@]}")

    if [[ -n "$selected" ]]; then
        print_info "开始安装插件..."

        local enabled_plugins=""
        local plugin_json=""

        for plugin in $selected; do
            print_info "安装 $plugin..."
            if claude plugins install "$plugin" 2>/dev/null; then
                print_success "$plugin 安装成功"
                enabled_plugins+="    \"${plugin}@claude-plugins-official\": true,\n"
            else
                print_warning "$plugin 安装失败或已安装"
                enabled_plugins+="    \"${plugin}@claude-plugins-official\": true,\n"
            fi
        done

        # 更新 settings.json 添加 enabledPlugins
        if [[ -n "$enabled_plugins" ]]; then
            # 移除最后的逗号
            enabled_plugins="${enabled_plugins%,*}"

            # 读取当前配置
            local current_settings=$(cat "$SETTINGS_FILE" 2>/dev/null || echo "{}")

            # 使用 jq 如果可用，否则使用简单方法
            if command_exists jq; then
                # 创建 enabledPlugins 对象
                local plugins_json="{"
                for plugin in $selected; do
                    plugins_json+="\"${plugin}@claude-plugins-official\": true, "
                done
                plugins_json="${plugins_json%, *}}"

                jq ". + {\"enabledPlugins\": $plugins_json}" "$SETTINGS_FILE" > /tmp/settings_temp.json
                mv /tmp/settings_temp.json "$SETTINGS_FILE"
            else
                # 简单追加方式
                local temp_file=$(mktemp)
                awk -v plugins="$enabled_plugins" '
                /^}$/ {
                    print ","
                    print "  \"enabledPlugins\": {"
                    printf "%s\n", plugins
                    print "  }"
                }
                { print }
                ' "$SETTINGS_FILE" > "$temp_file"
                mv "$temp_file" "$SETTINGS_FILE"
            fi
        fi

        print_success "插件安装完成"
    else
        print_info "跳过插件安装"
    fi

    echo
}

# ------------------------------------------------------------------------------
# Rules 配置
# ------------------------------------------------------------------------------
configure_rules() {
    print_step "Rules 规则集配置"

    # 显示可选规则
    print_info "可用规则集:"
    echo

    local rule_names=()

    for name in "${AVAILABLE_RULE_NAMES[@]}"; do
        rule_names+=("$name")
        printf "  %-15s %s\n" "$name" "$(get_rule_desc "$name")"
    done

    echo

    # 选择规则集
    local selected=$(select_multiple "选择要安装的规则集 (common 为必选)" "${rule_names[@]}")

    # 确保 common 被选中
    if [[ ! " $selected " =~ " common " ]]; then
        print_warning "common 规则集为必选，已自动添加"
        selected="common $selected"
    fi

    # 创建规则目录
    mkdir -p "$RULES_DIR"

    # 获取脚本所在目录
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local rules_source="$script_dir/rules"

    # 如果本地没有 rules 目录，尝试从网上获取
    if [[ ! -d "$rules_source" ]]; then
        print_info "本地规则集不存在，正在从远程获取..."

        # 临时目录
        local temp_dir=$(mktemp -d)

        # 克隆或下载
        if command_exists git; then
            print_info "从 GitHub 克隆规则集..."
            git clone --depth 1 https://github.com/affaan-m/everything-claude-code.git "$temp_dir/ecc" 2>/dev/null || {
                print_warning "克隆失败，使用默认规则"
            }

            # 检查是否有规则
            if [[ -d "$temp_dir/ecc/rules" ]]; then
                rules_source="$temp_dir/ecc/rules"
            fi
        fi
    fi

    # 复制规则文件
    print_info "安装规则集..."

    for rule in $selected; do
        if [[ -d "$rules_source/$rule" ]]; then
            mkdir -p "$RULES_DIR/$rule"
            cp -r "$rules_source/$rule/"* "$RULES_DIR/$rule/" 2>/dev/null || true
            print_success "$rule 规则集安装完成"
        else
            print_warning "$rule 规则集源文件不存在，跳过"
        fi
    done

    # 复制 README
    if [[ -f "$rules_source/README.md" ]]; then
        cp "$rules_source/README.md" "$RULES_DIR/"
    fi

    print_success "规则集配置完成"
    print_info "规则目录: $RULES_DIR"
    echo
}

# ------------------------------------------------------------------------------
# Claude Team 配置
# ------------------------------------------------------------------------------
configure_claude_team() {
    print_step "Claude Team 配置"

    echo -e "${CYAN}Claude Team 说明:${NC}"
    echo -e "  Claude Team 是一个多模型 MCP 服务器，支持多个 AI 模型协同工作"
    echo -e "  配置后可以在 Claude Code 中使用 /team 命令调用不同模型"
    echo

    if ! confirm "是否配置 Claude Team?" "n"; then
        print_info "跳过 Claude Team 配置"
        return 0
    fi

    # 阿里云百炼默认配置
    local BAILIAN_URL="https://coding.dashscope.aliyuncs.com/apps/anthropic"
    local DEFAULT_MAIN_MODEL="glm-5"
    local DEFAULT_MODEL1="kimi-k2.5"              # 文本专家：长文本解析
    local DEFAULT_MODEL2="Qwen3-Max-2026-01-23"   # 推理专家：表格分析、深度推理
    local DEFAULT_MODEL3="qwen3.5-plus"           # 多模态专家：图片理解、OCR
    local DEFAULT_MODEL4="qwen3-coder-plus"       # 代码专家：代码生成、数据处理
    local DEFAULT_MODEL5="MiniMax-M2.5"           # 通用专家：辅助任务
    local DEFAULT_MODEL6="qwen3-coder-next"       # 整合专家：结果汇总

    echo -e "\n${WHITE}━━━ 配置方式 ━━━${NC}"
    echo -e "  ${CYAN}[1]${NC} 使用阿里云百炼默认配置 (推荐)"
    echo -e "  ${CYAN}[2]${NC} 自定义配置"
    echo

    local config_choice
    echo -en "${BLUE}请选择 [1-2]: ${NC}"
    read -r config_choice

    local team_url team_key team_model members_json

    if [[ "$config_choice" == "1" ]]; then
        # 使用阿里云百炼默认配置
        echo -e "\n${WHITE}━━━ 阿里云百炼默认配置 ━━━${NC}"
        echo
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│  角色            │  模型名称              │  用途          │${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│  Tech Lead       │  glm-5                 │  任务规划、分发    │${NC}"
        echo -e "${CYAN}│  文本专家        │  kimi-k2.5             │  长文本解析、理解  │${NC}"
        echo -e "${CYAN}│  推理专家        │  Qwen3-Max-2026-01-23  │  表格分析、推理    │${NC}"
        echo -e "${CYAN}│  多模态专家      │  qwen3.5-plus          │  图片理解、OCR    │${NC}"
        echo -e "${CYAN}│  代码专家        │  qwen3-coder-plus      │  代码生成、数据处理│${NC}"
        echo -e "${CYAN}│  通用专家        │  MiniMax-M2.5          │  辅助任务        │${NC}"
        echo -e "${CYAN}│  整合专家        │  qwen3-coder-next      │  结果汇总、报告生成│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
        echo

        # 输入 API Key
        team_url="$BAILIAN_URL"
        team_key=$(get_input "API Key" "" "true")

        if [[ -z "$team_key" ]]; then
            print_error "API Key 不能为空"
            return 1
        fi

        team_model="$DEFAULT_MAIN_MODEL"

        # 使用默认成员配置
        members_json="\\n        \"CLAUDE_TEAM_MODEL1_NAME\": \"${DEFAULT_MODEL1}\",
        \"CLAUDE_TEAM_MODEL1_PROVIDER\": \"openai\",
        \"CLAUDE_TEAM_MODEL2_NAME\": \"${DEFAULT_MODEL2}\",
        \"CLAUDE_TEAM_MODEL2_PROVIDER\": \"openai\",
        \"CLAUDE_TEAM_MODEL3_NAME\": \"${DEFAULT_MODEL3}\",
        \"CLAUDE_TEAM_MODEL3_PROVIDER\": \"openai\",
        \"CLAUDE_TEAM_MODEL4_NAME\": \"${DEFAULT_MODEL4}\",
        \"CLAUDE_TEAM_MODEL4_PROVIDER\": \"openai\",
        \"CLAUDE_TEAM_MODEL5_NAME\": \"${DEFAULT_MODEL5}\",
        \"CLAUDE_TEAM_MODEL5_PROVIDER\": \"openai\",
        \"CLAUDE_TEAM_MODEL6_NAME\": \"${DEFAULT_MODEL6}\",
        \"CLAUDE_TEAM_MODEL6_PROVIDER\": \"openai\""

        print_success "将使用阿里云百炼默认模型配置"

    else
        # 自定义配置
        echo -e "\n${WHITE}━━━ 自定义配置 ━━━${NC}"

        # 主模型配置
        echo -e "\n${CYAN}主模型配置 (Tech Lead):${NC}"
        team_url=$(get_input "API Base URL" "$USER_BASE_URL")
        team_key=$(get_input "API Key" "$USER_API_KEY" "true")

        if [[ -z "$team_key" ]]; then
            print_error "API Key 不能为空"
            return 1
        fi

        team_model=$(get_input "主模型名称" "$USER_MODEL")

        # 专家成员配置
        echo -e "\n${WHITE}━━━ 专家成员配置 ━━━${NC}"
        echo -e "${BLUE}可以配置多个专家成员，每个成员使用不同的模型${NC}"

        members_json=""
        local member_count=0
        local continue_add=true

        while $continue_add; do
            member_count=$((member_count + 1))

            echo -e "\n${CYAN}专家成员 $member_count:${NC}"

            local member_model=$(get_input "模型名称" "")

            if [[ -z "$member_model" ]]; then
                print_info "跳过此成员"
                member_count=$((member_count - 1))
            else
                local member_provider=$(get_input "Provider" "openai")

                members_json+="\\n        \"CLAUDE_TEAM_MODEL${member_count}_NAME\": \"${member_model}\","
                members_json+="\\n        \"CLAUDE_TEAM_MODEL${member_count}_PROVIDER\": \"${member_provider}\","
            fi

            if [[ $member_count -ge 10 ]]; then
                print_info "已达到最大成员数 (10)"
                break
            fi

            if ! confirm "是否添加更多成员?" "n"; then
                continue_add=false
            fi
        done

        # 移除最后的逗号
        members_json="${members_json%,*}"
    fi

    # 生成 config.json
    print_info "生成 Claude Team 配置..."

    cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "claude-team": {
      "command": "npx",
      "args": ["-y", "claude-team"],
      "env": {
        "CLAUDE_TEAM_MAIN_KEY": "${team_key}",
        "CLAUDE_TEAM_MAIN_URL": "${team_url}",
        "CLAUDE_TEAM_MAIN_MODEL": "${team_model}",
        "CLAUDE_TEAM_MAIN_PROVIDER": "openai",${members_json}
      }
    }
  }
}
EOF

    chmod 600 "$CONFIG_FILE"

    print_success "Claude Team 配置完成"
    print_info "配置文件: $CONFIG_FILE"
    echo
}

# ------------------------------------------------------------------------------
# 测试环境安装
# ------------------------------------------------------------------------------
install_test_env() {
    print_step "测试环境安装"

    print_info "可用测试环境:"
    echo

    local env_names=()

    for name in "${AVAILABLE_TEST_ENV_NAMES[@]}"; do
        env_names+=("$name")
        printf "  %-15s %s\n" "$name" "$(get_test_env_desc "$name")"
    done

    echo

    local selected=$(select_multiple "选择要安装的测试环境" "${env_names[@]}")

    if [[ -n "$selected" ]]; then
        for env in $selected; do
            case "$env" in
                playwright)
                    print_info "安装 Playwright..."
                    npm install -g playwright
                    playwright install
                    print_success "Playwright 安装完成"
                    ;;
                jest)
                    print_info "安装 Jest..."
                    npm install -g jest
                    print_success "Jest 安装完成"
                    ;;
                pytest)
                    print_info "安装 Pytest..."
                    if command_exists pip; then
                        pip install pytest pytest-cov
                        print_success "Pytest 安装完成"
                    elif command_exists pip3; then
                        pip3 install pytest pytest-cov
                        print_success "Pytest 安装完成"
                    else
                        print_warning "pip 未安装，跳过 Pytest"
                    fi
                    ;;
            esac
        done
    else
        print_info "跳过测试环境安装"
    fi

    echo
}

# ------------------------------------------------------------------------------
# 配置摘要
# ------------------------------------------------------------------------------
print_summary() {
    print_step "安装完成摘要"

    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  🎉 Claude Code 安装配置完成！${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo -e "\n${CYAN}📋 配置信息:${NC}"
    echo -e "  ${WHITE}配置目录:${NC}    $CLAUDE_DIR"
    echo -e "  ${WHITE}API URL:${NC}     $USER_BASE_URL"
    echo -e "  ${WHITE}默认模型:${NC}    $USER_MODEL"
    echo -e "  ${WHITE}语言:${NC}        $USER_LANGUAGE"

    # 显示选择的角色
    if [[ -n "$SELECTED_ROLES" ]]; then
        echo -e "\n${CYAN}👤 职业角色:${NC}"
        for role in $SELECTED_ROLES; do
            local role_name=""
            case "$role" in
                backend_engineer) role_name="后端开发工程师" ;;
                frontend_engineer) role_name="前端开发工程师" ;;
                mobile_engineer) role_name="移动端开发工程师" ;;
                fullstack_engineer) role_name="全栈工程师" ;;
                ai_engineer) role_name="AI/ML 工程师" ;;
                data_engineer) role_name="数据工程师" ;;
                devops_engineer) role_name="DevOps/SRE 工程师" ;;
                security_engineer) role_name="安全工程师" ;;
                test_engineer) role_name="测试工程师" ;;
                architect) role_name="系统架构师" ;;
                business_manager) role_name="业务经理" ;;
                project_manager) role_name="项目经理" ;;
                product_manager) role_name="产品经理" ;;
                ui_ux_designer) role_name="UI/UX 设计师" ;;
                content_creator) role_name="自媒体从业者" ;;
                tech_writer) role_name="技术文档撰写者" ;;
                teacher) role_name="教师" ;;
                student) role_name="学生" ;;
                general_user) role_name="普通用户" ;;
                *) role_name="$role" ;;
            esac
            echo -e "  ${GREEN}✓${NC} $role_name"
        done
    fi

    echo -e "\n${CYAN}📁 配置文件:${NC}"
    [[ -f "$SETTINGS_FILE" ]] && echo -e "  ${GREEN}✓${NC} settings.json"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "  ${GREEN}✓${NC} config.json"
        # 检查是否配置了 Notebook LM
        if grep -q "notebook-lm" "$CONFIG_FILE" 2>/dev/null; then
            echo -e "    ${CYAN}├─${NC} Claude Team"
            echo -e "    ${CYAN}└─${NC} Notebook LM"
        else
            echo -e "    ${CYAN}└─${NC} Claude Team"
        fi
    fi

    echo -e "\n${CYAN}📚 规则集:${NC}"
    if [[ -d "$RULES_DIR" ]]; then
        local rule_count=0
        for dir in "$RULES_DIR"/*/; do
            if [[ -d "$dir" ]]; then
                echo -e "  ${GREEN}✓${NC} $(basename "$dir")"
                ((rule_count++))
            fi
        done
        [[ "$rule_count" -eq 0 ]] && echo -e "  ${YELLOW}-${NC} 未安装"
    fi

    echo -e "\n${CYAN}🔧 快速开始:${NC}"
    echo -e "  ${WHITE}启动 Claude Code:${NC}  claude"
    echo -e "  ${WHITE}查看帮助:${NC}        claude --help"
    echo -e "  ${WHITE}查看版本:${NC}        claude --version"

    echo -e "\n${CYAN}📖 文档链接:${NC}"
    echo -e "  ${WHITE}官方文档:${NC}        https://docs.anthropic.com/claude-code"
    echo -e "  ${WHITE}GitHub:${NC}          https://github.com/anthropics/claude-code"

    # Notebook LM 使用提示
    if [[ -f "$CONFIG_FILE" ]] && grep -q "notebook-lm" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "\n${CYAN}📓 Notebook LM:${NC}"
        echo -e "  ${WHITE}获取 API Key:${NC}    https://aistudio.google.com/apikey"
        echo -e "  ${WHITE}支持格式:${NC}        PDF、Google Docs、网页、YouTube"
    fi

    echo -e "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ------------------------------------------------------------------------------
# API Key 安全管理
# ------------------------------------------------------------------------------
manage_api_key_security() {
    echo -e "\n${WHITE}━━━ API Key 安全管理 ━━━${NC}"
    echo

    # 检查当前配置
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        print_error "未找到配置文件，请先配置 AI Provider"
        return 1
    fi

    # 显示当前存储方式
    local current_storage
    current_storage=$(detect_api_key_storage "ANTHROPIC_AUTH_TOKEN")

    echo -e "${CYAN}当前 API Key 存储方式:${NC}"
    case "$current_storage" in
        "environment")
            echo -e "  ${GREEN}✓ 环境变量存储${NC} - 安全等级: 高"
            echo -e "  ${WHITE}存储位置: ~/.zshrc 或 ~/.bashrc${NC}"
            ;;
        "keyring")
            echo -e "  ${GREEN}✓ 系统密钥环存储${NC} - 安全等级: 最高"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo -e "  ${WHITE}存储位置: macOS Keychain${NC}"
            else
                echo -e "  ${WHITE}存储位置: Linux secret service${NC}"
            fi
            ;;
        *)
            echo -e "  ${YELLOW}⚠ 配置文件存储${NC} - 安全等级: 低"
            echo -e "  ${WHITE}存储位置: ~/.claude/settings.json${NC}"
            echo -e "  ${RED}警告: API Key 以明文存储，建议更换更安全的存储方式${NC}"
            ;;
    esac

    echo
    echo -e "${CYAN}可用操作:${NC}"
    echo -e "  ${GREEN}[1]${NC} 更改存储方式"
    echo -e "  ${GREEN}[2]${NC} 查看当前 API Key (脱敏显示)"
    echo -e "  ${GREEN}[3]${NC} 重新输入 API Key"
    echo -e "  ${GREEN}[0]${NC} 返回主菜单"
    echo

    local action
    echo -en "${BLUE}请选择 [0-3]: ${NC}"
    read -r action

    case "$action" in
        1)
            # 更改存储方式
            echo -e "\n${CYAN}选择新的存储方式:${NC}"

            local api_key_value=""

            # 尝试从当前存储获取 API Key
            case "$current_storage" in
                "environment")
                    api_key_value=$(grep -o 'export ANTHROPIC_AUTH_TOKEN="[^"]*"' ~/.zshrc 2>/dev/null | cut -d'"' -f2)
                    ;;
                "keyring")
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        api_key_value=$(security find-generic-password -a "claude-code" -s "anthropic-api-key" -w 2>/dev/null)
                    else
                        api_key_value=$(secret-tool lookup service anthropic-api-key 2>/dev/null)
                    fi
                    ;;
                *)
                    # 从配置文件获取
                    api_key_value=$(grep -o '"ANTHROPIC_AUTH_TOKEN": "[^"]*"' "$SETTINGS_FILE" 2>/dev/null | cut -d'"' -f4)
                    ;;
            esac

            if [[ -z "$api_key_value" ]] || [[ "$api_key_value" == "\${ANTHROPIC_AUTH_TOKEN}" ]] || [[ "$api_key_value" == *'$('* ]]; then
                # 无法自动获取，要求用户重新输入
                print_warning "无法从当前存储自动获取 API Key，请重新输入"
                api_key_value=$(get_input "请输入 API Key" "" "true")
            fi

            if [[ -n "$api_key_value" ]]; then
                configure_api_key_storage "$api_key_value" "ANTHROPIC_AUTH_TOKEN"

                # 更新配置文件
                local new_storage
                new_storage=$(detect_api_key_storage "ANTHROPIC_AUTH_TOKEN")

                # 获取当前配置的其他值
                local base_url model lang
                base_url=$(grep -o '"ANTHROPIC_BASE_URL": "[^"]*"' "$SETTINGS_FILE" | cut -d'"' -f4)
                model=$(grep -o '"model": "[^"]*"' "$SETTINGS_FILE" | cut -d'"' -f4)
                lang=$(grep -o '"language": "[^"]*"' "$SETTINGS_FILE" | cut -d'"' -f4)

                # 生成新配置
                case "$new_storage" in
                    "environment")
                        cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "\${ANTHROPIC_AUTH_TOKEN}",
    "ANTHROPIC_BASE_URL": "${base_url}",
    "ANTHROPIC_MODEL": "${model}"
  },
  "model": "${model}",
  "language": "${lang}"
}
EOF
                        ;;
                    "keyring")
                        cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "\$(~/.claude/scripts/get-api-key.sh anthropic-api-key 2>/dev/null || echo '')",
    "ANTHROPIC_BASE_URL": "${base_url}",
    "ANTHROPIC_MODEL": "${model}"
  },
  "model": "${model}",
  "language": "${lang}"
}
EOF
                        ;;
                    *)
                        cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "${api_key_value}",
    "ANTHROPIC_BASE_URL": "${base_url}",
    "ANTHROPIC_MODEL": "${model}"
  },
  "model": "${model}",
  "language": "${lang}"
}
EOF
                        ;;
                esac

                print_success "API Key 存储方式已更新"
            else
                print_error "API Key 不能为空"
            fi
            ;;
        2)
            # 脱敏显示当前 API Key
            local masked_key=""
            case "$current_storage" in
                "environment")
                    masked_key=$(grep -o 'export ANTHROPIC_AUTH_TOKEN="[^"]*"' ~/.zshrc 2>/dev/null | cut -d'"' -f2)
                    ;;
                "keyring")
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        masked_key=$(security find-generic-password -a "claude-code" -s "anthropic-api-key" -w 2>/dev/null)
                    else
                        masked_key=$(secret-tool lookup service anthropic-api-key 2>/dev/null)
                    fi
                    ;;
                *)
                    masked_key=$(grep -o '"ANTHROPIC_AUTH_TOKEN": "[^"]*"' "$SETTINGS_FILE" 2>/dev/null | cut -d'"' -f4)
                    ;;
            esac

            if [[ -n "$masked_key" ]] && [[ "$masked_key" != "\${ANTHROPIC_AUTH_TOKEN}" ]] && [[ "$masked_key" != *'$('* ]]; then
                # 脱敏显示：只显示前4位和后4位
                local key_len=${#masked_key}
                if [[ $key_len -gt 12 ]]; then
                    echo -e "\n${CYAN}当前 API Key:${NC}"
                    echo -e "  ${WHITE}${masked_key:0:4}****${masked_key: -4}${NC}"
                    echo -e "  ${YELLOW}长度: $key_len 字符${NC}"
                else
                    echo -e "\n${CYAN}当前 API Key:${NC}"
                    echo -e "  ${WHITE}${masked_key:0:2}****${NC}"
                fi
            else
                print_warning "无法显示 API Key（可能使用环境变量引用）"
            fi
            ;;
        3)
            # 重新输入 API Key
            local new_key
            new_key=$(get_input "请输入新的 API Key" "" "true")

            if [[ -n "$new_key" ]]; then
                configure_api_key_storage "$new_key" "ANTHROPIC_AUTH_TOKEN" >/dev/null

                local new_storage
                new_storage=$(detect_api_key_storage "ANTHROPIC_AUTH_TOKEN")

                local base_url model lang
                base_url=$(grep -o '"ANTHROPIC_BASE_URL": "[^"]*"' "$SETTINGS_FILE" | cut -d'"' -f4)
                model=$(grep -o '"model": "[^"]*"' "$SETTINGS_FILE" | cut -d'"' -f4)
                lang=$(grep -o '"language": "[^"]*"' "$SETTINGS_FILE" | cut -d'"' -f4)

                case "$new_storage" in
                    "environment")
                        cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "\${ANTHROPIC_AUTH_TOKEN}",
    "ANTHROPIC_BASE_URL": "${base_url}",
    "ANTHROPIC_MODEL": "${model}"
  },
  "model": "${model}",
  "language": "${lang}"
}
EOF
                        ;;
                    "keyring")
                        cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "\$(~/.claude/scripts/get-api-key.sh anthropic-api-key 2>/dev/null || echo '')",
    "ANTHROPIC_BASE_URL": "${base_url}",
    "ANTHROPIC_MODEL": "${model}"
  },
  "model": "${model}",
  "language": "${lang}"
}
EOF
                        ;;
                    *)
                        cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "${new_key}",
    "ANTHROPIC_BASE_URL": "${base_url}",
    "ANTHROPIC_MODEL": "${model}"
  },
  "model": "${model}",
  "language": "${lang}"
}
EOF
                        ;;
                esac

                print_success "API Key 已更新"
            else
                print_error "API Key 不能为空"
            fi
            ;;
        0)
            return 0
            ;;
        *)
            print_error "无效选择"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 第三方图形界面客户端安装
# ------------------------------------------------------------------------------

# 客户端配置路径
CHATBOX_CONFIG_DIR_MAC="$HOME/Library/Application Support/chatbox"
CHATBOX_CONFIG_DIR_LINUX="$HOME/.config/chatbox"
CHERRY_CONFIG_DIR_MAC="$HOME/Library/Application Support/CherryStudio"
CHERRY_CONFIG_DIR_LINUX="$HOME/.config/CherryStudio"

# 图形界面客户端安装入口
install_gui_client() {
    print_step "图形界面客户端安装"

    echo -e "${CYAN}中国大陆用户无法直接访问 Claude 官方图形界面 (claude.ai)${NC}"
    echo -e "${CYAN}通过安装支持自定义 API 端点的第三方客户端，可以获得图形界面体验${NC}"
    echo

    echo -e "${WHITE}可用客户端:${NC}"
    echo
    echo -e "  ${GREEN}[1]${NC} Chatbox"
    echo -e "      ${CYAN}•${NC} 跨平台: Win/Mac/Linux/iOS/Android"
    echo -e "      ${CYAN}•${NC} 轻量、开源、支持多种 API"
    echo -e "      ${CYAN}•${NC} GitHub: github.com/Bin-Huang/chatbox"
    echo
    echo -e "  ${GREEN}[2]${NC} Cherry Studio (推荐)"
    echo -e "      ${CYAN}•${NC} 平台: Win/Mac"
    echo -e "      ${CYAN}•${NC} 原生体验、美观、支持 MCP"
    echo -e "      ${CYAN}•${NC} GitHub: github.com/kangfenmao/cherry-studio"
    echo
    echo -e "  ${GREEN}[3]${NC} 两者都安装"
    echo -e "  ${CYAN}[4]${NC} 仅配置 API (客户端已安装)"
    echo -e "  ${CYAN}[0]${NC} 跳过"
    echo

    local choice
    echo -en "${BLUE}请选择 [0-4]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            install_chatbox
            ;;
        2)
            install_cherry_studio
            ;;
        3)
            install_chatbox
            echo
            install_cherry_studio
            ;;
        4)
            configure_gui_client_api
            ;;
        0)
            print_info "跳过图形界面客户端安装"
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac
}

# 安装 Chatbox
install_chatbox() {
    echo -e "\n${WHITE}━━━ 安装 Chatbox ━━━${NC}"
    echo

    local os_type="$(uname)"
    local install_success=false

    # 检查是否已安装
    if [[ "$os_type" == "Darwin" ]]; then
        if [[ -d "/Applications/Chatbox.app" ]]; then
            print_info "Chatbox 已安装"
            if ! confirm "是否重新安装?" "n"; then
                configure_chatbox_api
                return 0
            fi
        fi
    fi

    print_info "正在安装 Chatbox..."

    if [[ "$os_type" == "Darwin" ]]; then
        # macOS - 使用 Homebrew
        if command_exists brew; then
            print_info "使用 Homebrew 安装..."
            if brew install --cask chatbox 2>/dev/null; then
                install_success=true
            else
                print_warning "Homebrew 安装失败，尝试手动下载"
            fi
        fi

        # 如果 brew 安装失败，提供手动下载链接
        if [[ "$install_success" != "true" ]]; then
            echo
            print_info "请手动下载安装:"
            echo -e "  ${CYAN}https://github.com/Bin-Huang/chatbox/releases${NC}"
            echo -e "  ${WHITE}选择 macOS 版本 (.dmg 或 .zip)${NC}"
            echo

            if confirm "安装完成后是否继续配置 API?" "y"; then
                configure_chatbox_api
            fi
            return 0
        fi

    elif [[ "$os_type" == "Linux" ]]; then
        # Linux - 下载 AppImage
        print_info "下载 Chatbox AppImage..."

        local chatbox_url="https://github.com/Bin-Huang/chatbox/releases/latest/download/Chatbox-x86_64.AppImage"
        local download_path="$HOME/Downloads/Chatbox.AppImage"

        if command_exists curl; then
            curl -L -o "$download_path" "$chatbox_url" 2>/dev/null && {
                chmod +x "$download_path"
                print_success "下载完成: $download_path"
                install_success=true
            }
        elif command_exists wget; then
            wget -O "$download_path" "$chatbox_url" 2>/dev/null && {
                chmod +x "$download_path"
                print_success "下载完成: $download_path"
                install_success=true
            }
        fi

        if [[ "$install_success" != "true" ]]; then
            print_warning "自动下载失败，请手动下载:"
            echo -e "  ${CYAN}https://github.com/Bin-Huang/chatbox/releases${NC}"
            echo -e "  ${WHITE}选择 Linux AppImage 版本${NC}"
        fi
    else
        print_warning "不支持的操作系统，请手动下载:"
        echo -e "  ${CYAN}https://github.com/Bin-Huang/chatbox/releases${NC}"
    fi

    if [[ "$install_success" == "true" ]]; then
        print_success "Chatbox 安装完成"

        # 配置 API
        if confirm "是否配置 Chatbox API?" "y"; then
            configure_chatbox_api
        fi
    fi
}

# 安装 Cherry Studio
install_cherry_studio() {
    echo -e "\n${WHITE}━━━ 安装 Cherry Studio ━━━${NC}"
    echo

    local os_type="$(uname)"
    local install_success=false

    # 检查是否已安装
    if [[ "$os_type" == "Darwin" ]]; then
        if [[ -d "/Applications/Cherry Studio.app" ]]; then
            print_info "Cherry Studio 已安装"
            if ! confirm "是否重新安装?" "n"; then
                configure_cherry_api
                return 0
            fi
        fi
    fi

    print_info "正在安装 Cherry Studio..."

    if [[ "$os_type" == "Darwin" ]]; then
        # macOS - 使用 Homebrew
        if command_exists brew; then
            print_info "使用 Homebrew 安装..."
            if brew install --cask cherry-studio 2>/dev/null; then
                install_success=true
            else
                print_warning "Homebrew 安装失败，尝试手动下载"
            fi
        fi

        # 如果 brew 安装失败，提供手动下载链接
        if [[ "$install_success" != "true" ]]; then
            echo
            print_info "请手动下载安装:"
            echo -e "  ${CYAN}https://github.com/kangfenmao/cherry-studio/releases${NC}"
            echo -e "  ${WHITE}选择 macOS 版本 (.dmg)${NC}"
            echo

            if confirm "安装完成后是否继续配置 API?" "y"; then
                configure_cherry_api
            fi
            return 0
        fi

    elif [[ "$os_type" == "Linux" ]]; then
        # Linux - 下载 AppImage/Deb
        print_info "下载 Cherry Studio..."

        local cherry_url="https://github.com/kangfenmao/cherry-studio/releases/latest/download/Cherry-Studio-x86_64.AppImage"
        local download_path="$HOME/Downloads/Cherry-Studio.AppImage"

        if command_exists curl; then
            curl -L -o "$download_path" "$cherry_url" 2>/dev/null && {
                chmod +x "$download_path"
                print_success "下载完成: $download_path"
                install_success=true
            }
        elif command_exists wget; then
            wget -O "$download_path" "$cherry_url" 2>/dev/null && {
                chmod +x "$download_path"
                print_success "下载完成: $download_path"
                install_success=true
            }
        fi

        if [[ "$install_success" != "true" ]]; then
            print_warning "自动下载失败，请手动下载:"
            echo -e "  ${CYAN}https://github.com/kangfenmao/cherry-studio/releases${NC}"
        fi
    else
        print_warning "不支持的操作系统，请手动下载:"
        echo -e "  ${CYAN}https://github.com/kangfenmao/cherry-studio/releases${NC}"
    fi

    if [[ "$install_success" == "true" ]]; then
        print_success "Cherry Studio 安装完成"

        # 配置 API
        if confirm "是否配置 Cherry Studio API?" "y"; then
            configure_cherry_api
        fi
    fi
}

# 配置 Chatbox API
configure_chatbox_api() {
    echo -e "\n${WHITE}━━━ 配置 Chatbox API ━━━${NC}"
    echo

    # 获取 API 配置
    local api_url api_key model

    # 尝试从现有配置获取
    if [[ -f "$SETTINGS_FILE" ]]; then
        api_url=$(grep -o '"ANTHROPIC_BASE_URL": "[^"]*"' "$SETTINGS_FILE" 2>/dev/null | cut -d'"' -f4)
        api_key=$(grep -o '"ANTHROPIC_AUTH_TOKEN": "[^"]*"' "$SETTINGS_FILE" 2>/dev/null | cut -d'"' -f4)
        model=$(grep -o '"model": "[^"]*"' "$SETTINGS_FILE" 2>/dev/null | cut -d'"' -f4)
    fi

    # 如果配置文件中没有，提示用户输入
    if [[ -z "$api_key" ]] || [[ "$api_key" == "\${ANTHROPIC_AUTH_TOKEN}" ]] || [[ "$api_key" == *'$('* ]]; then
        print_info "请输入 API 配置:"
        api_url=$(get_input "API Base URL" "https://coding.dashscope.aliyuncs.com/apps/anthropic")
        api_key=$(get_input "API Key" "" "true")
        model=$(get_input "模型名称" "glm-5")
    else
        print_info "使用 Claude Code 配置:"
        echo -e "  ${WHITE}API URL:${NC} $api_url"
        echo -e "  ${WHITE}模型:${NC}     $model"
        echo -e "  ${WHITE}API Key:${NC}  $(echo "$api_key" | sed 's/.\{4\}$/****/')"

        if ! confirm "使用以上配置?" "y"; then
            api_url=$(get_input "API Base URL" "$api_url")
            api_key=$(get_input "API Key" "" "true")
            model=$(get_input "模型名称" "$model")
        fi
    fi

    if [[ -z "$api_key" ]]; then
        print_error "API Key 不能为空"
        return 1
    fi

    # 确定配置文件路径
    local config_dir
    if [[ "$(uname)" == "Darwin" ]]; then
        config_dir="$CHATBOX_CONFIG_DIR_MAC"
    else
        config_dir="$CHATBOX_CONFIG_DIR_LINUX"
    fi

    # 创建配置目录
    mkdir -p "$config_dir"

    # 生成 Chatbox 配置文件
    # Chatbox 使用特定的配置格式
    cat > "$config_dir/config.json" << EOF
{
  "provider": "openai",
  "models": [
    {
      "name": "${model}",
      "model": "${model}"
    }
  ],
  "settings": {
    "openai": {
      "apiKey": "${api_key}",
      "baseUrl": "${api_url}"
    }
  },
  "selectedModel": "${model}",
  "theme": "system",
  "language": "zh-CN"
}
EOF

    chmod 600 "$config_dir/config.json"

    print_success "Chatbox API 配置完成"
    print_info "配置文件: $config_dir/config.json"
    echo
    print_info "启动 Chatbox 即可使用"
}

# 配置 Cherry Studio API
configure_cherry_api() {
    echo -e "\n${WHITE}━━━ 配置 Cherry Studio API ━━━${NC}"
    echo

    # 获取 API 配置
    local api_url api_key model

    # 尝试从现有配置获取
    if [[ -f "$SETTINGS_FILE" ]]; then
        api_url=$(grep -o '"ANTHROPIC_BASE_URL": "[^"]*"' "$SETTINGS_FILE" 2>/dev/null | cut -d'"' -f4)
        api_key=$(grep -o '"ANTHROPIC_AUTH_TOKEN": "[^"]*"' "$SETTINGS_FILE" 2>/dev/null | cut -d'"' -f4)
        model=$(grep -o '"model": "[^"]*"' "$SETTINGS_FILE" 2>/dev/null | cut -d'"' -f4)
    fi

    # 如果配置文件中没有，提示用户输入
    if [[ -z "$api_key" ]] || [[ "$api_key" == "\${ANTHROPIC_AUTH_TOKEN}" ]] || [[ "$api_key" == *'$('* ]]; then
        print_info "请输入 API 配置:"
        api_url=$(get_input "API Base URL" "https://coding.dashscope.aliyuncs.com/apps/anthropic")
        api_key=$(get_input "API Key" "" "true")
        model=$(get_input "模型名称" "glm-5")
    else
        print_info "使用 Claude Code 配置:"
        echo -e "  ${WHITE}API URL:${NC} $api_url"
        echo -e "  ${WHITE}模型:${NC}     $model"
        echo -e "  ${WHITE}API Key:${NC}  $(echo "$api_key" | sed 's/.\{4\}$/****/')"

        if ! confirm "使用以上配置?" "y"; then
            api_url=$(get_input "API Base URL" "$api_url")
            api_key=$(get_input "API Key" "" "true")
            model=$(get_input "模型名称" "$model")
        fi
    fi

    if [[ -z "$api_key" ]]; then
        print_error "API Key 不能为空"
        return 1
    fi

    # 确定配置文件路径
    local config_dir
    if [[ "$(uname)" == "Darwin" ]]; then
        config_dir="$CHERRY_CONFIG_DIR_MAC"
    else
        config_dir="$CHERRY_CONFIG_DIR_LINUX"
    fi

    # 创建配置目录
    mkdir -p "$config_dir"

    # 生成 Cherry Studio 配置文件
    # Cherry Studio 使用 providers 配置格式
    cat > "$config_dir/config.json" << EOF
{
  "providers": [
    {
      "id": "custom-provider",
      "name": "自定义 API",
      "type": "openai-compatible",
      "apiKey": "${api_key}",
      "baseUrl": "${api_url}",
      "models": [
        {
          "id": "${model}",
          "name": "${model}"
        }
      ]
    }
  ],
  "defaultProvider": "custom-provider",
  "defaultModel": "${model}",
  "theme": "system",
  "language": "zh-CN"
}
EOF

    chmod 600 "$config_dir/config.json"

    print_success "Cherry Studio API 配置完成"
    print_info "配置文件: $config_dir/config.json"
    echo
    print_info "启动 Cherry Studio 即可使用"
}

# 统一配置 API (为所有已安装的客户端配置)
configure_gui_client_api() {
    echo -e "\n${WHITE}━━━ 配置图形界面客户端 API ━━━${NC}"
    echo

    local configured=false

    # 检测 Chatbox 是否已安装
    if [[ "$(uname)" == "Darwin" ]] && [[ -d "/Applications/Chatbox.app" ]]; then
        if confirm "是否配置 Chatbox API?" "y"; then
            configure_chatbox_api
            configured=true
        fi
    elif [[ "$(uname)" == "Linux" ]] && [[ -f "$HOME/Downloads/Chatbox.AppImage" ]]; then
        if confirm "是否配置 Chatbox API?" "y"; then
            configure_chatbox_api
            configured=true
        fi
    fi

    # 检测 Cherry Studio 是否已安装
    if [[ "$(uname)" == "Darwin" ]] && [[ -d "/Applications/Cherry Studio.app" ]]; then
        echo
        if confirm "是否配置 Cherry Studio API?" "y"; then
            configure_cherry_api
            configured=true
        fi
    elif [[ "$(uname)" == "Linux" ]] && [[ -f "$HOME/Downloads/Cherry-Studio.AppImage" ]]; then
        echo
        if confirm "是否配置 Cherry Studio API?" "y"; then
            configure_cherry_api
            configured=true
        fi
    fi

    if [[ "$configured" != "true" ]]; then
        print_warning "未检测到已安装的图形界面客户端"
        print_info "请先安装 Chatbox 或 Cherry Studio"
    fi
}

# ------------------------------------------------------------------------------
# 主函数
# ------------------------------------------------------------------------------
main() {
    print_banner

    # 系统检测
    check_system

    # 询问要执行的步骤
    echo -e "${CYAN}请选择要执行的步骤:${NC}\n"
    print_option "1" "安装 Claude Code"
    print_option "2" "配置 AI Provider"
    print_option "3" "安装插件"
    print_option "4" "配置 Rules"
    print_option "5" "配置 Claude Team"
    print_option "6" "配置文档分析"
    print_option "7" "配置办公能力 (P1)"
    print_option "G" "安装图形界面客户端 (Chatbox/Cherry Studio)"
    print_option "S" "API Key 安全管理"
    print_option "0" "退出"
    echo

    local choice
    echo -en "${BLUE}请选择 [0-7,G,S]: ${NC}"
    read -r choice

    case "$choice" in
        1)
            install_dependencies
            install_claude_code
            ;;
        2)
            configure_ai_provider
            ;;
        3)
            install_plugins
            ;;
        4)
            configure_rules
            ;;
        5)
            configure_claude_team
            ;;
        6)
            configure_notebook_lm
            ;;
        7)
            configure_office_tools
            ;;
        G|g)
            install_gui_client
            ;;
        S|s)
            manage_api_key_security
            ;;
        0)
            print_info "退出安装"
            exit 0
            ;;
        *)
            print_error "无效选择"
            exit 1
            ;;
    esac

    print_summary
}

# 运行主函数
main "$@"