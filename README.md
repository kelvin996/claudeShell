# Claude Code 安装配置脚本使用说明书

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Claude Code 安装配置脚本 v1.0.0                          │
│                        使用说明书                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 一、概述

### 1.1 脚本简介

本脚本为 Claude Code CLI 的自动化安装配置工具，支持：

- **一键安装** Claude Code CLI
- **灵活配置** 多种 AI Provider（阿里云百炼、DeepSeek 等）
- **职业角色** 基于角色的智能配置推荐
- **文档分析** 多种文档分析服务配置
- **配置管理** 备份、恢复、导出、导入

### 1.2 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS / Linux |
| Node.js | >= 18.0 |
| 包管理器 | npm / yarn |
| 网络环境 | 能访问 npm 仓库 |

### 1.3 文件结构

```
~/.claude/
├── settings.json          # 主配置文件（API、模型、插件）
├── config.json            # MCP 服务器配置
├── rules/                 # Rules 规则集
│   ├── common/           # 通用规则
│   ├── typescript/       # TypeScript 规则
│   ├── python/           # Python 规则
│   ├── golang/           # Go 规则
│   └── swift/            # Swift 规则
├── plugins/              # 插件目录
├── backups/              # 配置备份目录
└── projects/             # 项目配置
```

---

## 二、快速开始

### 2.1 运行脚本

```bash
# 添加执行权限
chmod +x install-claude-code.sh

# 运行脚本
./install-claude-code.sh
```

### 2.2 主菜单选项

```
请选择要执行的步骤:

  [1] 完整安装（推荐）- 包含角色选择
  [2] 智能安装 - 根据职业角色自动配置
  [3] 仅安装 Claude Code
  [4] 仅配置 AI Provider
  [5] 仅安装插件
  [6] 仅配置 Rules
  [7] 仅配置 Claude Team
  [8] 仅配置 Notebook LM
  [9] 自定义步骤
  [0] 退出
```

### 2.3 推荐流程

**首次安装用户：**
```
选择 [1] 完整安装 → 跟随向导完成所有配置
```

**阿里云百炼月套餐用户：**
```
选择 [4] → 选择 [1] 快捷配置 → 输入 API Key → 完成
```

**已有配置用户：**
```
选择 [4] → 选择 [3] 导入配置文件 → 输入配置文件路径
```

---

## 三、功能详解

### 3.1 AI Provider 配置

#### 配置模式选择

```
请选择配置模式:
  [1] 快捷配置 - 阿里云百炼月套餐 (推荐)
  [2] 自定义配置
  [3] 导入配置文件
  [4] 恢复备份配置
```

#### 快捷配置（推荐）

适用于阿里云百炼月套餐用户，自动填充默认值：

| 配置项 | 默认值 |
|--------|--------|
| API URL | `https://coding.dashscope.aliyuncs.com/apps/anthropic` |
| 模型 | `glm-5` |
| 语言 | 简体中文 |

只需输入 API Key 即可完成配置。

#### 自定义配置

适用于其他 AI Provider 用户：

| Provider | API URL | 推荐模型 |
|----------|---------|----------|
| 阿里云百炼 | `https://coding.dashscope.aliyuncs.com/apps/anthropic` | glm-5, qwen3.5-plus |
| DeepSeek | `https://api.deepseek.com` | deepseek-chat |
| 智谱 AI | `https://open.bigmodel.cn/api/paas/v4` | glm-4 |

### 3.2 Claude Team 配置

多模型协作 MCP 服务器，支持配置多个专家模型成员。

#### 默认配置（阿里云百炼月套餐）

| 成员 | 模型 | 用途 |
|------|------|------|
| Tech Lead | glm-5 | 任务分配、深度思考 |
| 专家 1 | qwen3.5-plus | 通用对话、推理 |
| 专家 2 | qwen3-coder-plus | 代码生成、重构 |
| 专家 3 | kimi-k2.5 | 长文本、工具调用 |
| 专家 4 | MiniMax-M2.5 | 通用任务 |
| 专家 5 | qwen3-max-2026-01-23 | 高级推理 |
| 专家 6 | qwen3-coder-next | 最新代码模型 |

### 3.3 职业角色配置

支持 19 种职业角色，自动推荐插件和规则：

#### 技术开发类
| 角色 | 推荐插件 | 推荐规则 |
|------|----------|----------|
| 后端开发工程师 | superpowers, code-review | typescript, python, golang |
| 前端开发工程师 | frontend-design, figma | typescript |
| 全栈工程师 | superpowers, feature-dev | typescript, python |
| AI 工程师 | feature-dev, claude-md-management | python |
| 架构师 | superpowers, skill-creator | typescript, python, golang |

#### 运维安全类
| 角色 | 推荐插件 | 推荐规则 |
|------|----------|----------|
| DevOps 工程师 | superpowers, code-review | golang, python |
| 安全工程师 | security-guidance, code-review | python |

#### 质量保障类
| 角色 | 推荐插件 | 推荐规则 |
|------|----------|----------|
| QA 工程师 | code-review, pr-review-toolkit | typescript, python |
| 测试工程师 | code-review, playground | typescript, python |

#### 设计类
| 角色 | 推荐插件 | 推荐规则 |
|------|----------|----------|
| UI/UX 设计师 | figma, frontend-design | typescript |

#### 内容创作类
| 角色 | 推荐插件 | 推荐规则 |
|------|----------|----------|
| 技术作家 | claude-md-management, skill-creator | common |
| 自媒体从业者 | playground, figma | common |

#### 管理类
| 角色 | 推荐插件 | 推荐规则 |
|------|----------|----------|
| 产品经理 | figma, linear, playground | common |
| 项目经理 | linear, claude-md-management | common |
| 业务经理 | linear, playground | common |

#### 教育学习类
| 角色 | 推荐插件 | 推荐规则 |
|------|----------|----------|
| 教师 | playground, figma | common |
| 学生 | playground, learning-output-style | common |

#### 普通用户
| 角色 | 推荐插件 | 推荐规则 |
|------|----------|----------|
| 普通用户 | playground, claude-md-management | common |

### 3.4 文档分析服务配置

支持 7 种文档分析服务：

| 序号 | 服务 | 特点 | 推荐场景 |
|------|------|------|----------|
| 1 | Open NotebookLM | 完全离线，支持阿里云百炼 API | 隐私要求高 |
| 2 | 阿里云百炼文档理解 | 开箱即用，国内稳定 | 国内用户首选 |
| 3 | Kimi 长文档分析 | 支持 200 万字 | 超长文档 |
| 4 | DeepSeek 文档分析 | 成本低 | 预算敏感 |
| 5 | 智谱 AI 文档分析 | 中文优化 | 中文文档 |
| 6 | Google NotebookLM | 官方，支持音频概述 | 可访问 Google |
| 7 | 跳过 | - | 暂不需要 |

### 3.5 插件配置

#### 可用插件列表

| 插件 | 用途 |
|------|------|
| superpowers | 增强 Power skills |
| code-review | 代码审查 |
| frontend-design | 前端设计 |
| pr-review-toolkit | PR 审查工具 |
| feature-dev | 功能开发 |
| claude-md-management | CLAUDE.md 管理 |
| figma | Figma 集成 |
| security-guidance | 安全指导 |
| typescript-lsp | TypeScript LSP |
| kotlin-lsp | Kotlin LSP |
| swift-lsp | Swift LSP |
| linear | Linear 集成 |
| playground | Playground |
| skill-creator | Skill Creator |
| code-simplifier | 代码简化器 |

### 3.6 Rules 规则集配置

| 规则集 | 说明 | 适用项目 |
|--------|------|----------|
| common | 通用规则（必选） | 所有项目 |
| typescript | TypeScript/JavaScript | 前端/Node.js |
| python | Python | 后端/AI |
| golang | Go | 后端/云原生 |
| swift | Swift | iOS/macOS |

---

## 四、配置管理

### 4.1 配置备份

脚本会在以下情况自动备份：
- 保存新配置前
- 导入配置前

备份位置：`~/.claude/backups/YYYYMMDD_HHMMSS/`

### 4.2 配置恢复

```
选择 [4] → 选择 [4] 恢复备份配置 → 选择备份时间点
```

### 4.3 配置导出

```bash
# 在脚本中选择导出功能
# 或手动执行
export_config ~/claude-config-export.json
```

导出文件会自动脱敏 API Key，可安全分享。

### 4.4 配置导入

```
选择 [4] → 选择 [3] 导入配置文件 → 输入文件路径
```

导入时需要重新输入 API Key。

---

## 五、配置验证

### 5.1 自动验证

脚本在保存配置前会自动验证：
1. API URL 格式检查
2. API Key 有效性验证
3. 模型可用性测试

### 5.2 验证结果

| 状态 | 说明 |
|------|------|
| ✅ 通过 | 配置正确，可以保存 |
| ❌ 失败 | 配置有误，建议检查 |
| ⚠️ 警告 | 无法验证，手动确认 |

### 5.3 配置预览

保存前会显示配置预览：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                      配置预览
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  API URL:      https://coding.dashscope.aliyuncs.com/apps/anthropic
  API Key:      sk-sp-********************
  模型:         glm-5
  语言:         简体中文

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  重要提示:
  • 错误的 API URL 或模型名称可能导致按量计费
  • 请确认以上配置正确后再保存
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

确认保存以上配置? [Y/n]:
```

---

## 六、重要提示

### 6.1 计费安全

```
⚠️  重要警告：Base URL 和模型设置错误可能导致按量计费！

• 请确认您使用的是正确的 API 端点和模型名称
• 阿里云百炼月套餐用户建议使用快捷配置
• 错误配置可能导致调用非套餐模型，产生额外费用
```

### 6.2 阿里云百炼月套餐模型

月套餐支持的模型（仅限以下模型）：

| 模型 | 用途 |
|------|------|
| glm-5 | 逻辑推理（推荐主模型） |
| qwen3.5-plus | 通用对话 |
| qwen3-coder-plus | 代码生成 |
| qwen3-coder-next | 最新代码模型 |
| qwen3-max-2026-01-23 | 高级推理 |
| kimi-k2.5 | 长文本处理 |
| MiniMax-M2.5 | 通用任务 |

### 6.3 API 端点说明

| 端点 | URL | 计费方式 |
|------|-----|----------|
| Anthropic 兼容 | `/apps/anthropic` | 月套餐 |
| OpenAI 兼容 | `/compatible-mode/v1` | 按量计费 |

---

## 七、常见问题

### Q1: 如何查看当前配置？

```bash
cat ~/.claude/settings.json
```

### Q2: 如何重置配置？

```bash
# 方法1: 恢复备份
./install-claude-code.sh → 选择 [4] → 选择 [4]

# 方法2: 删除配置文件重新配置
rm ~/.claude/settings.json
./install-claude-code.sh
```

### Q3: 验证失败怎么办？

1. 检查 API Key 是否正确
2. 检查 API URL 是否正确
3. 检查模型名称是否正确
4. 检查网络连接

### Q4: 如何查看 Claude Code 版本？

```bash
claude --version
```

### Q5: 如何启动 Claude Code？

```bash
claude
```

### Q6: 如何更新 Claude Code？

```bash
npm update -g @anthropic-ai/claude-code
```

---

## 八、命令参考

| 命令 | 说明 |
|------|------|
| `claude` | 启动 Claude Code |
| `claude --version` | 查看版本 |
| `claude --help` | 查看帮助 |
| `claude -p "prompt"` | 单次提问模式 |
| `claude plugins list` | 查看已安装插件 |
| `claude plugins install <name>` | 安装插件 |

---

## 九、相关链接

| 资源 | 链接 |
|------|------|
| Claude Code 官方文档 | https://docs.anthropic.com/claude-code |
| Claude Code GitHub | https://github.com/anthropics/claude-code |
| 阿里云百炼 | https://bailian.console.aliyun.com |
| Open NotebookLM | https://github.com/gabrielchua/open-notebooklm |

---

## 十、版本历史

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| 1.0.0 | 2026-03-11 | 初始版本，支持完整安装配置流程 |

---

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    Claude Code 安装配置脚本
                        使用说明书 v1.0.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```