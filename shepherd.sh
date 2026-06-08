#!/bin/bash
# shepherd.sh - 智能Shell助手 (AI-powered CLI Agent)
# 用法: ./shepherd.sh -h
# 例子: 
# 		export shepherd_LLM_API_KEY="your-api-key"
# 		export shepherd_SKILLS_DIR="技能1目录:技能2目录"
#       rlwrap -s 2000 -H ~/.shepherd_history ~/ollama-linux/shepherd/shepherd.sh

# H. Z. Sang    sanghz@qq.com    Jun 4, 2026  @treegram

VERSION="1.0.0"

# ==================== 配置 ====================
MAX_HISTORY=20              # 历史记录最大长度
MAX_OUTPUT_LINES=1000       # 执行命令输出最大行数
COMMAND_TIMEOUT=30          # 执行命令超时（秒），长时业务请放后台：&
HEARTBEAT_TIME=5            # 心跳（秒）
TEMPERATURE=0.1             # AI 模型温度参数
MAX_TOKENS=5000             # AI 模型每次输出最大词元
LLM_API_KEY="${shepherd_LLM_API_KEY:-$AI_API_KEY_deepseek}"
LLM_BASE_URL="${shepherd_LLM_BASE_URL:-https://api.deepseek.com/v1/chat/completions}"
LLM_NAME="${shepherd_LLM_NAME:-deepseek-chat}"  # deepseek-v4-flash  deepseek-v4-pro
# LLM_BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
# LLM_NAME="qwen3.7-max"  #"qwen3-coder-plus"
# ------------------------------------------------
WORK_DIR="${shepherd_WORK_DIR:-.}"            # 工作目录默认为当前目录 [ 可通过环境变量 shepherd_WORK_DIR 指定 ]
SKILLS_DIR="${shepherd_SKILLS_DIR}"           # 支持多目录, 写法 xx:yy:zz, 类似$PATH [ 默认为空，需环境变量 shepherd_SKILLS_DIR 指定 ]
HEARTBEAT_CMD="${shepherd_HEARTBEAT_CMD}"     # 心跳执行命令，可用于监控，定时之类任务
HEARTBEAT_S_CMD="${shepherd_HEARTBEAT_S_CMD}" # 心跳执行的 source 命令，建议只用于参数动态配置，如改变SKILLS_DIR的值
HISTORY_FILE="/tmp/shepherd_history_$$"
LOG_FILE="/tmp/shepherd.log"

# ==================== 初始化 ====================
init_agent() {
    # 检查API Key
    if [ -z "$LLM_API_KEY" ]; then
        echo "❌ 请设置 LLM_API_KEY 环境变量"
        echo "   export LLM_API_KEY='your-key'"
        exit 1
    fi
   
   # 检查依赖
    for dep in curl jq; do
        if ! command -v "$dep" &>/dev/null; then
            echo "❌ 缺少依赖: $dep"
            echo "   安装: brew install $dep (macOS) 或 apt install $dep (Linux)"
            exit 1
        fi
    done

	# 检查工作目录和技能目录
	IFS=':' read -ra DIRS <<< "$SKILLS_DIR:$WORK_DIR";
	for sDIR in "${DIRS[@]}"; do
		[ -z "$sDIR" ] && continue
		[ -d "$sDIR" ] || { echo "不存在目录: $sDIR"; exit 1; }
	done

	# 清空对话历史
	echo '[]' > "$HISTORY_FILE"
}

# ==================== 日志功能 ====================
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

# ==================== 清理函数 ====================
cleanup() {
    log "INFO" "Cleaning up..."
    rm -f "$HISTORY_FILE" 2>/dev/null
    exit 0
}

# ==================== 对话历史管理 ====================
add_to_history() {
    local role="$1"
    local content="$2"
    
    # 直接使用 jq 的 --arg 会自动处理转义
    local history=$(cat "$HISTORY_FILE")
    local new_history=$(echo "$history" | jq \
        --arg role "$role" \
        --arg content "$content" \
        '. += [{"role": $role, "content": $content}]')
    
    new_history=$(echo "$new_history" | jq "if length > $MAX_HISTORY then .[-$MAX_HISTORY:] else . end")
    
    echo "$new_history" > "$HISTORY_FILE"
    log "DEBUG" "Added to history: $role - ${content:0:50}..."
}

get_history() {
    cat "$HISTORY_FILE"
}

clear_history() {
    echo '[]' > "$HISTORY_FILE"
    echo "✅ 对话历史已清空"
    log "INFO" "History cleared"
}

# ==================== Skills加载 ====================
load_all_skills() {
	IFS=':' read -ra DIR_ARRAY <<< "$SKILLS_DIR"
	for sDIR in "${DIR_ARRAY[@]}"; do
		[ -z "$sDIR" ] && continue
		if [ -d "$sDIR" ]; then
			for skill_file in "$sDIR"/*.md; do
				if [ -f "$skill_file" ]; then
					echo "\n\n## [$(basename "$sDIR")] $(basename "$skill_file" .md)\n"
					cat "$skill_file"
					echo "\n\n---\n"
				fi
			done
		fi
	done
}

# ==================== 获取工作目录状态 ====================
get_workspace_state() {
    local state=""
    state="${state}\n## 当前工作目录: $WORK_DIR\n"
    state="${state}\n### 目录内容:\n"
    state="${state}\`\`\`\n"
    state="${state}$(cd "$WORK_DIR" 2>/dev/null && ls -la 2>/dev/null | head -30)\n"
    state="${state}\`\`\`\n"
    
    local file_count=$(cd "$WORK_DIR" 2>/dev/null && find . -type f 2>/dev/null | wc -l)
    state="${state}\n### 统计: ${file_count} 个文件\n"
    
    echo "$state"
}

# ==================== 安全检查 ====================
is_safe_command() {
    local cmd="$1"
    
    # 安全命令白名单检查
    local safe_patterns=(
        "^ls " "^find " "^grep " "^cat " "^head " "^tail "
        "^wc " "^sort " "^uniq " "^echo " "^mkdir " "^touch "
        "^cp " "^mv " "^rm [^-]" "^git " "^python " "^python3 "
        "^node " "^npm " "^pip " "^pip3 " "^make " "^gcc "
        "^clang " "^javac " "^java " "^go " "^cargo " "^rustc "
    )
    
    for pattern in "${safe_patterns[@]}"; do
        if echo "$cmd" | grep -qE "$pattern"; then
            log "DEBUG" "Command passed safety check (whitelist): $cmd"
            return 0
        fi
    done
    
    # 危险模式检查
    local dangerous=(
        "rm\s+-rf\s+/"
        "sudo\s+"
        "passwd"
        ":\(\)\s*{\s*:;\s*};\s*:"
        "curl.*\|.*bash"
        "wget.*-O.*\|.*bash"
        "mkfs"
        "dd\s+if=/dev/zero"
        ">/dev/sd"
        "chown\s+root"
        "chmod\s+777\s+/"
        "rm\s+-rf\s+~"
        "rm\s+-rf\s+\$HOME"

		# 危险重定向
        "> */dev/sd" ">/dev/sd" "> /dev/sd"
        "> */dev/hd" ">/dev/hd" "> /dev/hd"
        "> */dev/nvme" ">/dev/nvme"

        # 危险删除
        "rm +-rf +/" "rm +-rf +/.*"
        "rm +-rf +\~" "rm +-rf +\$HOME"
        "rm +-rf +\.\.?\."

        # 提权
        "sudo +" "su +"

        # 危险管道
        "curl.*\|.*bash" "wget.*\|.*bash"
        "curl.*\|.*sh" "wget.*\|.*sh"
        "python -c.*curl" "perl -e.*curl"

        # 文件系统破坏
        "mkfs\." "dd +if=/dev/zero" "dd +if=/dev/random"
        "format " "fdisk "

        # 权限修改
        "chmod +777 +/" "chmod 777 /"
        "chown +root +/"

        # Fork 炸弹
        ":\(\)\s*{\s*:;\s*};\s*:"

        # 加密勒索特征
        "encrypt" "ransom" "crypt"

        # 反弹 shell
        "bash -i >& /dev/tcp/" "nc -e /bin/bash"
        "telnet.*|/bin/bash"
    )
    
    for pattern in "${dangerous[@]}"; do
        if echo "$cmd" | grep -qE "$pattern"; then
            log "WARNING" "Command blocked by safety check: $cmd"
            return 1
        fi
    done
    
    log "DEBUG" "Command passed safety check: $cmd"
    return 0
}

# ==================== 命令执行（带超时） ====================
execute_command() {
    local cmd="$1"
    
    echo ""
    echo "$cmd # 执行目录: $WORK_DIR, 输出如下: "
    echo "----------------------------------------"
    
    # 使用临时文件捕获输出
    local output_file=$(mktemp)
    local exit_code=0
    
    log "INFO" "Executing: $cmd"
    
    # 执行命令并捕获输出
    if command -v timeout &>/dev/null; then
        timeout "$COMMAND_TIMEOUT" bash -c "cd '$WORK_DIR' && $cmd" > "$output_file" 2>&1
        exit_code=$?
    else
        echo "旧版系统没有timeout命令, 请用perl等其他方法实现"
		log "INFO" "旧版系统没有timeout命令"
		exit 1
    fi
    
    # 读取输出
    local output=$(cat "$output_file")
    rm -f "$output_file"
    
    # 限制输出长度
    local line_count=$(echo "$output" | wc -l)
    if [ $line_count -gt $MAX_OUTPUT_LINES ]; then
        output=$(echo "$output" | head -$MAX_OUTPUT_LINES)
        output="${output}\n... (输出截断，共${line_count}行)"
    fi
    
    if [ $exit_code -ne 0 ]; then
        if [ $exit_code -eq 137 ] || [ $exit_code -eq 124 ]; then
            echo "⏰ 命令执行超时 (${COMMAND_TIMEOUT}秒)"
        else
            echo "⚠️  退出码: $exit_code"
        fi
    fi
    
    log "INFO" "Command exit code: $exit_code"
    
    # 返回输出
    printf "%s\n" "$output"
    echo "----------------------------------------"
    return $exit_code
}

# ==================== 调用 AI（带历史） ====================
chat_with_llm() {
    local user_input="$1""  请给出完整的 bash 命令"
    
    # 获取对话历史
    local history=$(get_history)
    
    # 构建系统提示
    local system_prompt="你是运行在工作目录 $WORK_DIR 的自动化助手。你可以记住之前的对话内容。

## 重要能力：
1. **记住上下文** - 用户可以引用之前的结果
2. **多轮协作** - 可以分步完成任务
3. **理解指代** - 知道\"它\"、\"那个文件\"指的是什么

## 可用技能：
$(load_all_skills)

## 所有技能模块所在文件夹：
$(IFS=':' read -ra DIRS <<< "$SKILLS_DIR"; ((${#DIRS[@]}!=0)) && find ${DIRS[@]} -name "*.md" )

## 你的对话历史文件：
$HISTORY_FILE

## 你每 $HEARTBEAT_TIME 秒心跳一次，心跳时可以执行的命令:
$HEARTBEAT_CMD

## 改变内部参数, 如技能目录SKILLS_DIR=技能1目录:技能2目录, 以及MAX_HISTORY，MAX_OUTPUT_LINES，COMMAND_TIMEOUT，TEMPERATURE，MAX_TOKENS ...
   可在心跳时执行带 source 的命令:
$HEARTBEAT_S_CMD

## 当前工作目录状态：
$(get_workspace_state)

## 规则：
1. 理解用户需求，输出完整的bash命令
2. 如果用户说\"继续\"或\"下一步\"，基于之前的输出继续
3. 如果用户引用之前的文件或结果，正确理解
4. 只输出bash命令，不要输出解释
5. 命令必须在工作目录 $WORK_DIR 内执行, 由于已经在工作目录 $WORK_DIR ，不要再执行 cd $WORK_DIR
6. 可以使用变量记住中间结果

## 输出格式（严格遵守）：
- 只输出 bash 命令的部分
- 不要输出任何解释、注释、额外文字
- 不要输出多行命令（如多行管道请写成一行）
- 不要输出 markdown 代码块标记
- 如果需要输出字符，就用 echo

示例正确输出：
find . -name '*.log' -size +1M"
    
    # 使用 jq 构建消息数组
    local messages=$(jq -n \
        --arg system "$system_prompt" \
        --arg user "$user_input" \
        --argjson history "$history" \
        '[
            {"role": "system", "content": $system},
            ($history[]),
            {"role": "user", "content": $user}
        ]')
    
    log "DEBUG" "Calling AI API with user input: ${user_input:0:100}..."
    
    # 调用API
    local response=$(curl -s "$LLM_BASE_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -d "$(echo "$messages" | jq -c --arg temp "$TEMPERATURE" --arg tokens "$MAX_TOKENS" --arg mname "$LLM_NAME" \
            '{model: $mname, messages: ., temperature: ($temp | tonumber), max_tokens: ($tokens | tonumber)}')")
    
    # 提取回复
    local reply=$(echo "$response" | jq -r '.choices[0].message.content // empty')
	local input_tokens=$(echo "$response" | jq -r '.usage.prompt_tokens // 0')
	local output_tokens=$(echo "$response" | jq -r '.usage.completion_tokens // 0')
	#local total_tokens=$(echo "$response" | jq -r '.usage.total_tokens // 0')
    
    # 检查是否有错误
    if [ -z "$reply" ]; then
        local error_msg=$(echo "$response" | jq -r '.error.message // "未知错误"')
        echo "API错误: $error_msg" >&2
        log "ERROR" "API error: $error_msg"
        return 1
    fi
    
    # === 清理markdown代码块 ===
	reply=$(echo "$reply" | sed -E 's/^```(bash|sh)?\s*\n?//; s/\n?\s*```$//')
    
    log "DEBUG" "Generated command: $reply -- Token usage - Input: $input_tokens, Output: $output_tokens"
    echo "$reply"
}

# ==================== 交互模式 ====================
interactive_mode() {
    echo ""
	echo "╔═══════════════════════════════════════════════════════╗"
	echo "║     🐑 Shepherd - 您的智能Shell助手                   ║"
	echo "╠═══════════════════════════════════════════════════════╣"
    echo "║  工作目录: $WORK_DIR"
    echo "║  Skills目录: $SKILLS_DIR"
    echo "║  心跳触发 : $HEARTBEAT_CMD"
    echo "║  心跳触发s: $HEARTBEAT_S_CMD"
    echo "║  特点: 记住对话历史，支持多轮交互                     ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    echo "示例对话："
    echo "  >>> 找出所有c文件"
    echo "  >>> 编译这个文件"
    echo "  >>> 运行编译后的程序"
    echo ""
    echo "命令: q/exit 退出, clear 清空历史, history 显示历史, ls "
    echo "      ws 工作目录和usage，/cmd 执行外部命令             "
    echo "========================================================"

	YOLO=$1
    
    while true; do
		# read -p ">>> " user_input
		printf "\r>>> "
		read -t $HEARTBEAT_TIME user_input

        
        case "$user_input" in
            "" )
				# heartbeat: 后台执行
				if command -v "$HEARTBEAT_CMD" &>/dev/null; then
					"$HEARTBEAT_CMD" &
				fi

				# heartbeat: source 前台执行 用于配置参数
				if command -v "$HEARTBEAT_S_CMD" &>/dev/null; then
					source "$HEARTBEAT_S_CMD"
				fi

                continue
                ;;
            "help" )
                echo "多轮对话示例："
                echo "  1. 列出所有c文件"
                echo "  2. 编译cc.c"
                echo "  3. 运行a.out"
                echo ""
                echo "特殊命令："
                echo "  clear       - 清空对话历史"
                echo "  history     - 显示对话历史"
                echo "  ls          - 列出目录（会录到对话历史）"
                echo "  ws          - 工作目录，Token usage"
                echo "  q/exit/quit - 退出"
                echo "  /cmd        - 执行外部命令（不录到对话历史）"
                continue
                ;;
            "clear" )
                clear_history
                continue
                ;;
            "history" )
                echo "对话历史："
                get_history | jq -r '.[] | "[\(.role)] \(.content | .[0:100])"'
                continue
                ;;
            "q" | "exit" | "quit" )
                echo "👋 再见"
                cleanup
                break
                ;;
            "ls" )
                local output=$(execute_command "ls -la")
                add_to_history "assistant" "执行了ls命令:\n$output"
				printf "%s\n" "$output"
                continue
                ;;
            "ws" )
                echo "$WORK_DIR"
                add_to_history "assistant" "当前目录: $WORK_DIR"
				grep "$(date '+%Y-%m-%d')" $LOG_FILE|grep "Token usage"| awk -F 'Input: |, Output: ' '{i+=$2;o+=$3} END {print "today Input:", i, "Output:", o}'
                continue
                ;;
            "/"* )
				local raw_cmd="${user_input#/}"
                [ -n "$raw_cmd" ] && printf "%s\n" "$(execute_command "${raw_cmd}" )"
                continue
                ;;
        esac
        
        # 记录用户输入
        add_to_history "user" "$user_input"
        
        echo "🤖 思考中..."
        
        # 获取命令
        local cmd
        cmd=$(chat_with_llm "$user_input")
        
        if [ $? -ne 0 ] || [ -z "$cmd" ]; then
            echo "❌ 无法生成命令，请换种方式描述"
            add_to_history "assistant" "无法理解: $user_input"
            continue
        fi
        
        # 安全检查
        if ! is_safe_command "$cmd"; then
            echo "❌ 命令被安全策略拦截"
            echo "   原因: 命令包含危险操作"
            add_to_history "assistant" "命令被拦截: $cmd"
            continue
        fi
        
        # 显示并确认
        echo ""
        echo "📋 生成的命令:"
        echo "   $cmd"
        echo ""
		if $YOLO; then
			confirm=Y
		else
			read -p "执行? [Y/n/e(编辑)] " -n 1 -r confirm
		fi
        echo ""
        
        case "$confirm" in
            n|N)
                echo "已取消"
                add_to_history "assistant" "用户取消执行: $cmd"
                continue
                ;;
            e|E)
                echo "请输入修改后的命令:"
                read -r cmd
                if ! is_safe_command "$cmd"; then
                    echo "❌ 命令被安全策略拦截"
                    add_to_history "assistant" "修改后的命令被拦截: $cmd"
                    continue
                fi
                ;;
            *)
                # 执行命令
                local output=$(execute_command "$cmd")
                # 记录执行结果到历史
                add_to_history "assistant" "$output"
				printf "%s" "$output"
                ;;
        esac
		echo ""
    done
}

# ==================== 单任务模式 ====================
run_once() {
    local task="$1"
    
    if [ -z "$task" ]; then
        echo "用法: $0 --run '任务描述'"
        exit 1
    fi
    
    add_to_history "user" "$task"
    
    local cmd=$(chat_with_llm "$task")
    
    if [ $? -ne 0 ] || [ -z "$cmd" ]; then
        echo "❌ 无法生成命令"
        exit 1
    fi
    
    if ! is_safe_command "$cmd"; then
        echo "❌ 命令被安全策略拦截"
        exit 1
    fi
    
    execute_command "$cmd"
}

# ==================== 主函数 ====================
main() {
    # 设置信号处理
    trap cleanup INT TERM EXIT
    
    log "INFO" "Agent started"
    
    # 解析参数
    case "${1:-}" in
        -r|--run)
			init_agent
            run_once "$2"
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo "  选项为空          正常模式"
            echo "  -r, --run TASK    执行单个任务后退出"
            echo "  -h, --help        显示帮助"
            echo "  -y, --yolo        yolo 模式, 不等待确认, 直接运行生成的命令!"
            echo ""
			echo "环境变量(必需)："
            echo "  shepherd_LLM_API_KEY     如DeepSeek API的密钥（必需）"
			echo "环境变量(用于开头参数初始化，只是传值)："
            echo "  shepherd_WORK_DIR        工作目录（默认：当前目录.）"
			echo "  shepherd_SKILLS_DIR      技能目录（默认：无技能）"
			echo "  shepherd_HEARTBEAT_CMD   心跳执行命令      （默认：无）"
			echo "  shepherd_HEARTBEAT_S_CMD 心跳执行source命令（默认：无）"
            echo "  shepherd_LLM_BASE_URL    默认 https://api.deepseek.com/v1/chat/completions"
            echo "  shepherd_LLM_NAME        默认 deepseek-chat"
            ;;
        -y|--yolo)
			init_agent
            interactive_mode  true
            ;;
        *)
			init_agent
            interactive_mode  false
            ;;
    esac
}

main "$@"
