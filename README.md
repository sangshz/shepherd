---
name: shepherd
description: Intelligent Shell Assistant - A Bash-based AI CLI Agent that converts natural language into safe Bash scripts, enabling natural human-computer interaction. Minimal code, minimal dependencies, fully controllable, and capable of running multiple expert agents concurrently.
---

> [中文版](README.zh.md) | [English](README.md)

# Shepherd: Minimal & Controllable Intelligent Shell Assistant

## Core Philosophy

Shepherd is an intelligent command-line assistant written entirely in Bash. Its core capability is converting natural language instructions into executable Bash scripts. It is built on a simple but powerful fact: on Unix-like systems (Linux/macOS), almost any operation can be accomplished via Bash commands, and modern AI models happen to excel at code generation.

The vision of this project is to shift from "humans using complex commands to control computers" to "humans and computers naturally conversing to complete tasks". With an extensible skill system, complex workflows and automation tasks become easy to handle.

## Design Philosophy

### Minimalism
- **Minimal code**: A single script file, easy to understand and modify
- **Minimal dependencies**: Only `jq` and `curl` required (`sudo apt install jq curl`)
- **Fully controllable**: No black-box logic, every line of code is transparent

### Security First

Unlike popular agent frameworks, Shepherd adopts a "single request" mode:

- **One conversation = one AI request**: No automatic multi‑round model calls in the background
- **No hidden operations**: Every execution requires user confirmation (outside YOLO mode)
- **Whitelist/Blacklist**: Built‑in command security policies
- **Working directory isolation**: Defaults to restricting operations within the current directory

Mainstream agent frameworks, in pursuit of "intelligence", make dozens of model calls invisibly to the user. During that process they might read personal files, download unknown software, install unfamiliar libraries, etc., posing security risks that are hard to prevent. Shepherd's approach is relatively "primitive", but when YOLO mode is used cautiously, it can run safely on everyday computers.

## Target Audience

Shepherd is best suited for:
- Developers familiar with Bash scripting
- Automation enthusiasts willing to package workflows as Skills
- Those who want a secure and controllable AI automation solution
- Users who want to remotely manage servers via SSH from mobile devices (works especially well with voice input)

## Quick Start

### Minimal Run
```bash
# After downloading shepherd.sh, enter its directory
export shepherd_LLM_API_KEY="your-api-key"  # Set API Key

# Optional: configure skill directories (multiple directories separated by colon)
export shepherd_SKILLS_DIR="skill_dir1:skill_dir2:skill_dir3"

chmod +x ./shepherd.sh
./shepherd.sh

# It is strongly recommended to use rlwrap to enhance the interactive experience! (rlwrap with options -c -r enables completion)
sudo apt install rlwrap  # Install rlwrap
rlwrap -s 2000 -H ~/.shepherd_history ./shepherd.sh
```

### Global Installation and Alias Configuration
```bash
# Copy to a PATH directory, e.g.
sudo cp shepherd.sh /usr/local/bin/

# Add alias to ~/.bashrc
alias shepherd='export shepherd_LLM_API_KEY="your-api-key"; export shepherd_SKILLS_DIR="$HOME/.shepherd/skills"; rlwrap -s 2000 -H ~/.shepherd_history shepherd.sh'
```

## Usage

### Interactive Mode
```bash
# Normal mode (requires confirmation for each command)
./shepherd.sh

# YOLO mode (auto‑execution, use with caution)
./shepherd.sh -y

# Show help
./shepherd.sh -h
```

### Single Task Mode
```bash
# Execute a single task directly
./shepherd.sh -r "Count the number of ERRORs in all log files in the current directory"
```

### Multi‑Agent Concurrency
By using different skill combinations and configurations, multiple expert agents can run concurrently:
```bash
export shepherd_SKILLS_DIR="./skills/math"
export shepherd_WORK_DIR="./math_data"
./shepherd.sh &  # Math assistant

export shepherd_SKILLS_DIR="./skills/news"
export shepherd_WORK_DIR="./news_cache"
./shepherd.sh &  # News assistant
```

## Advanced Configuration

### Working Directory
```bash
# Default restricted to current directory; can be customized
export shepherd_WORK_DIR="/path/to/workspace"
```

### Conversation History Management
```bash
# Clear conversation history in interactive mode (skills are not cleared)
clear
```

### Timeout Control
```bash
# Command execution timeout, default 30 seconds
# Modify the COMMAND_TIMEOUT variable at the beginning of the script or configure via the heartbeat mechanism
```

### Model Adaptation
```bash
# Default uses DeepSeek; supports other models (e.g., Qwen)
export shepherd_LLM_BASE_URL="https://your-model-endpoint"
export shepherd_LLM_NAME="your-model-name"
```

### Command Whitelist/Blacklist
Edit the security policy configuration section directly in the script to customize allowed or disallowed commands.

## Heartbeat Mechanism

Shepherd supports a heartbeat mechanism for monitoring, scheduled tasks, or dynamically adjusting configuration:

```bash
# Normal heartbeat command (e.g., monitoring, scheduled tasks) – specify before starting:
export shepherd_HEARTBEAT_CMD="${HOME}/.shepherd/heartbeat"

# Special heartbeat command (prefixed with `source`, suitable for configuring internal parameters) – specify before starting:
export shepherd_HEARTBEAT_S_CMD="${HOME}/.shepherd/heartbeat_s"

# Heartbeat interval is configured inside the script
```

Using heartbeat (combined with crafting heartbeat skills) you can:
- Dynamically load new skills
- Automatically tidy up history
- Adjust runtime parameters in real time
- Implement scheduled task scheduling

**Note**: Ensure that the heartbeat command does not block for a long time.

## Skill Development

### Skill Format
Format is free‑form, but it is recommended to include:
- YAML frontmatter (defining skill metadata)
- Detailed usage instructions and examples

### Dynamically Loading Skills
```bash
# Temporarily add a skill (essentially appends to conversation history; usable until history is cleared)
cat your-skill.md

# Dynamic reload via heartbeat command (not load, but reload; if you need to completely remove unused skills that interfere in history, run `clear`). In the file pointed to by shepherd_HEARTBEAT_S_CMD, add:
SKILLS_DIR="newskill1:newskill2:newskill3"
```

## Practical Scenarios

### Mobile SSH Management
1. Install Termux or an SSH client on your phone
2. SSH into your server
3. Use voice input to speak natural language commands
4. Shepherd automatically converts them into Bash commands for execution

### Explore Other Scenarios?
Is it easy to adapt to QQ bots, AI Xiao Zhi, or other conversational systems?

## Project Information

- **License**: MIT License
- **Author’s note**: Thanks to DeepSeek AI for its great assistance.

## Security Tips

1. First‑time users should run in normal mode and confirm each command before execution.
2. YOLO mode should only be enabled in fixed scenarios, after long‑term use and a full understanding of the risks.

---

*Shepherd: Bringing command‑line interaction back to simplicity and control.*
