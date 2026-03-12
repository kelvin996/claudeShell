# Claude Code 安装配置脚本

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/your-username/claudeShell)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)]()

> 🚀 一键安装配置 Claude Code CLI，支持阿里云百炼、DeepSeek 等自定义 API Provider，专为国内用户优化

## ✨ 功能特性

- 🔧 **一键安装** - 自动安装 Claude Code CLI 和依赖
- 🌐 **跳过登录** - 自动配置 `hasCompletedOnboarding`，避免官方登录报错
- 🔑 **API Key 安全存储** - 支持配置文件/环境变量/系统密钥环三种方式
- 🤖 **多 Provider 支持** - 阿里云百炼、DeepSeek、智谱 AI 等
- 👔 **职业角色配置** - 19 种职业角色，自动推荐插件和规则
- 📝 **文档分析服务** - Open NotebookLM、阿里云百炼文档理解等
- 🖥️ **图形界面客户端** - Chatbox、Cherry Studio 安装配置
- 💾 **配置管理** - 备份、恢复、导出、导入

## 🚀 快速开始

```bash
# 克隆仓库
git clone https://github.com/your-username/claudeShell.git
cd claudeShell

# 添加执行权限
chmod +x install-claude-code.sh

# 运行脚本
./install-claude-code.sh
```

## 📋 主菜单选项

| 选项 | 功能 | 说明 |
|------|------|------|
| 1 | 完整安装 | 包含角色选择，推荐首次安装 |
| 2 | 智能安装 | 根据职业角色自动配置 |
| 3 | 仅安装 Claude Code | 安装 CLI |
| 4 | 仅配置 AI Provider | 配置 API 端点 |
| 5 | 仅安装插件 | 安装官方插件 |
| 6 | 仅配置 Rules | 配置规则集 |
| 7 | 仅配置 Claude Team | 多模型协作 |
| 8 | 仅配置文档分析 | 文档处理服务 |
| 9 | 仅配置办公能力 | P1 功能配置 |
| G | 安装图形界面客户端 | Chatbox/Cherry Studio |
| S | API Key 安全管理 | 更改存储方式 |

## 🌍 国内用户推荐配置

### 阿里云百炼月套餐

```bash
./install-claude-code.sh
# 选择 [4] → 选择 [1] 快捷配置 → 输入 API Key
```

自动配置：
- API URL: `https://coding.dashscope.aliyuncs.com/apps/anthropic`
- 主模型: `glm-5`
- 语言: `简体中文`

### 支持的月套餐模型

| 模型 | 用途 |
|------|------|
| glm-5 | 逻辑推理（推荐主模型） |
| qwen3.5-plus | 通用对话 |
| qwen3-coder-plus | 代码生成 |
| kimi-k2.5 | 长文本处理 |
| MiniMax-M2.5 | 通用任务 |

## 📁 文件结构

```
~/.claude/
├── settings.json          # 主配置文件
├── config.json            # MCP 服务器配置
├── rules/                 # Rules 规则集
│   ├── common/           # 通用规则
│   ├── typescript/       # TypeScript 规则
│   ├── python/           # Python 规则
│   ├── golang/           # Go 规则
│   └── swift/            # Swift 规则
├── plugins/              # 插件目录
├── backups/              # 配置备份
└── projects/             # 项目配置

~/.claude.json            # 跳过登录配置
```

## 🔐 API Key 安全存储

| 方式 | 安全等级 | 说明 |
|------|----------|------|
| 配置文件 | ⚠️ 低 | 明文存储在 settings.json |
| 环境变量 | ✅ 高 | 存储在 ~/.zshrc |
| 系统密钥环 | ✅ 最高 | macOS Keychain / Linux secret |

## 👔 职业角色配置

| 类别 | 角色 |
|------|------|
| 技术开发 | 后端/前端/移动端/全栈/AI/数据工程师 |
| 运维安全 | DevOps/安全工程师 |
| 质量保障 | 测试/QA 工程师 |
| 架构管理 | 架构师/产品/项目经理 |
| 设计 | UI/UX 设计师 |
| 内容创作 | 技术作家/自媒体 |
| 教育学习 | 教师/学生 |

## 🔗 相关链接

- [Claude Code 官方文档](https://docs.anthropic.com/claude-code)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)
- [阿里云百炼](https://bailian.console.aliyun.com)
- [Open NotebookLM](https://github.com/gabrielchua/open-notebooklm)
- [Chatbox](https://github.com/Bin-Huang/chatbox)
- [Cherry Studio](https://github.com/kangfenmao/cherry-studio)

## 📄 License

MIT License

---

**GitHub Description (仓库描述):**

```
🚀 Claude Code 安装配置脚本 - 一键安装配置 CLI，支持阿里云百炼/DeepSeek 等自定义 API，跳过官方登录，专为国内用户优化
```

**Topics (标签):**

`claude-code` `anthropic` `ai-assistant` `cli-tool` `alibaba-cloud` `bailian` `deepseek` `developer-tools` `chinese` `installer`