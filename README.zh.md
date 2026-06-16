---
name: shepherd
description: 个人 AI 助手 - 基于 Bash 的 AI CLI Agent，可将自然语言转换为安全的 Bash 脚本，实现人与计算机的自然交互。代码极简、依赖极少、完全可控，加载不同 skills 可同时运行多个 Agent 专家。
---

> [English](README.md) | [中文版](README.zh.md)

# Shepherd：极简可控的 AI 助手

## 核心理念

Shepherd 是一个完全用 Bash 编写的 AI 助手，核心能力是将自然语言指令转换为可执行的 Bash 脚本。它基于一个简单而强大的事实：在 Linux/macOS 等 Unix-like 系统中，几乎所有操作都可以通过 Bash 命令完成，而现代 AI 模型恰好具备优秀的代码生成能力。

这个项目的愿景是实现从「人用繁琐命令控制计算机」到「人与计算机自然对话完成任务」的范式转变。配合可扩展的技能体系，复杂工作流和自动化任务都可以轻松驾驭。

## 设计哲学

### 极简主义
- **代码极少**：单个脚本文件，易于理解和修改
- **依赖极少**：仅需 `jq` 和 `curl`（`sudo apt install jq curl`）
- **完全可控**：没有黑盒逻辑，每一行代码都透明可见

### 安全性优先
与当前流行的 Agent 框架不同，Shepherd 采用「单次请求」模式：

- **一次对话 = 一次 AI 请求**：不会在后台自动发起多轮模型调用
- **无隐形操作**：每次执行都需要用户确认（非 YOLO 模式下）
- **白名单/黑名单**：内置命令安全策略
- **工作目录隔离**：默认限制在当前目录范围内

主流 Agent 框架为了追求「智能化」，会在用户看不见的地方进行十几次甚至几十次模型调用，其间可能执行读取个人文件、下载未知软件、安装不明库等操作，安全风险难以防范。Shepherd 的方案虽然相对「原始」，但配合 YOLO 模式的谨慎启用，可以在日常使用的电脑上放心运行。

## 适用人群

Shepherd 最适合：
- 熟悉 Bash 脚本的开发者
- 愿意将工作流程封装为 Skill 的自动化爱好者
- 追求安全可控的 AI 自动化方案
- 希望在手机端通过 SSH 远程管理服务器的用户（配合语音输入法体验更佳）

## 快速开始

### 最小化运行
```bash
# 下载 shepherd.sh 后，进入目录
export shepherd_LLM_API_KEY="your-api-key"  # 设置 API Key

# 可选：配置技能目录（多个目录用冒号分隔）
export shepherd_SKILLS_DIR="skill_dir1:skill_dir2:skill_dir3"

chmod +x ./shepherd.sh
./shepherd.sh

# 强烈推荐使用 rlwrap 增强交互体验! ( rlwrap 加选项 -c -r 实现补全)
sudo apt install rlwrap  # 安装 rlwrap
rlwrap -s 2000 -H ~/.shepherd_history ./shepherd.sh

### 全局安装与别名配置
```bash
# 复制到 PATH 目录, 如
sudo cp shepherd.sh /usr/local/bin/

# 在 ~/.bashrc 中添加别名
alias shepherd='export shepherd_LLM_API_KEY="your-api-key"; export shepherd_SKILLS_DIR="$HOME/.shepherd/skills"; rlwrap -s 2000 -H ~/.shepherd_history shepherd.sh'
```

## 使用方式

### 交互模式
```bash
# 普通模式（需确认每个命令）
./shepherd.sh

# YOLO 模式（自动执行，谨慎使用）
./shepherd.sh -y

# 查看帮助
./shepherd.sh -h
```

### 单任务模式
```bash
# 直接执行单个任务
./shepherd.sh -r "统计当前目录下所有 log 文件中的 ERROR 数量"
```

### 多 Agent 并发
通过不同的技能组合和配置，可以同时运行多个专家 Agent：
```bash
export shepherd_SKILLS_DIR="./skills/math"
export shepherd_WORK_DIR="./math_data"
./shepherd.sh &  # 数学助手

export shepherd_SKILLS_DIR="./skills/news"
export shepherd_WORK_DIR="./news_cache"
./shepherd.sh &  # 新闻助手
```

## 高级配置

### 工作目录
```bash
# 默认限制在当前目录，可自定义
export shepherd_WORK_DIR="/path/to/workspace"
```

### 对话历史管理
```bash
# 交互模式下清空对话历史（不清除技能）
clear
```

### 超时控制
```bash
# 命令执行超时时间，默认 30 秒
# 修改脚本开头的 COMMAND_TIMEOUT 变量 或用心跳机制配置
```

### 模型适配
```bash
# 默认使用 DeepSeek，支持其他模型（如千问）
export shepherd_LLM_BASE_URL="https://your-model-endpoint"
export shepherd_LLM_NAME="your-model-name"
```

### 命令白名单/黑名单
直接编辑脚本中的安全策略配置区，可自定义允许或禁止的命令。

## 心跳机制

Shepherd 支持心跳机制，用于执行监控和定时等任务或动态调整配置：

```bash
# 普通心跳命令（如监控、定时任务）启动前指定命令：
export shepherd_HEARTBEAT_CMD="${HOME}/.shepherd/heartbeat"

# 特殊心跳命令（命令前会加 source，适合配置内部参数）启动前指定命令：
export shepherd_HEARTBEAT_S_CMD="${HOME}/.shepherd/heartbeat_s"

# 心跳间隔在脚本中配置
```

通过心跳可以(配合制作心跳skills)：
- 动态加载新技能
- 自动整理历史记录
- 实时调整运行参数
- 实现定时任务调度

**注意**：确保心跳命令不会长时间阻塞。

## Skill 开发

### 技能格式
格式自由，但建议包含：
- YAML frontmatter（定义技能元数据）
- 详细的使用说明和示例

### 动态加载技能
```bash
# 临时添加技能（本质是加到对话历史记录，记忆被清理前可用）
cat your-skill.md

# 通过心跳命令动态重载（不是加载，是重载，如需要完全清除不用的技能在历史记录里干扰，执行 clear ），在shepherd_HEARTBEAT_S_CMD 对应的文件里，添加：
SKILLS_DIR="newskill1:newskill2:newskill3"

# 例子: 根据当前目录自动切换技能集, 心跳文件 heartbeat_s.sh
#!/bin/bash

if [[ "$PWD" == /project/ai/* ]]; then
    SKILLS_DIR="/path/to/ai-skills:$BASE_SKILLS"
elif [[ "$PWD" == /project/web/* ]]; then
    SKILLS_DIR="/path/to/web-skills:$BASE_SKILLS"
fi
```

## 实战场景

### 手机 SSH 管理
1. 手机安装 Termux 或 SSH 客户端
2. SSH 连接到服务器
3. 使用语音输入法输入自然语言指令
4. Shepherd 自动转换为 Bash 命令执行

### 其他场景可以探索吗？
是否容易适配 QQ 机器人、AI 小智等交互系统？

## 项目信息

- **协议**：MIT License
- **作者注**：感谢 deepseek AI 的大力辅助。

## 安全提示

1. 首次使用建议在普通模式下运行，确认每个命令的执行
2. YOLO 模式仅在固定场景下，长期使用后充分理解风险再启用

---

*Shepherd：让命令行交互，回归简单与可控。*
