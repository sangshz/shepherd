---
name: shepherd
description: 智能 Shell 助手 (AI-powered CLI Agent), 是一个完全用 bash shell 写的专门生成 bash shell 脚本操作计算机的 AI Agent。代码极少, 依赖极少, 完全可控
---

# 介绍

## 原理想法
shepherd 是一个智能 Shell 助手，是一个完全用 bash shell 写的专门生成 bash shell 脚本的 AI Agent。 原理是 linux/mac 之类的操作系统都可以用命令操作，其中 bash 命令最为常见。而目前AI的代码能力都很强，可以比较准确的把自然语言转换为 bash 脚本操作计算机。实现人用严格又繁琐的各种命令控制计算机做事，到人和计算机自然交谈做事的范式转变。在各种 skills 支持之下，复杂工作和自动化流程一样信手拈来。

## 优势
这个有趣做法相对openclaw之类成品的优势: 
- 1, 代码极少，只一个文件，便于修改，完全可控
- 2, 依赖极少，几乎拿来就用(可能需要安装jq curl: sudo apt install jq curl)
- 3, 最关键的一点：一次交谈，只有一次AI模型请求！目前较为火热的agent框架，为了更为智能，一般问一次，后台会多次向AI大模型请求询问，尽可能获得最好的结果。中间看不到的十几轮，几十轮的自动轮询中一般都会做一些操作，可能大多是读操作，但是个人信息以及其他重要文件都可能被上传，多次自主操作有时下载莫名其妙的东西，安装乱七八糟的库，防不胜防。所以大多建议安装到专门的容器或者服务器里，实现安全隔离。而本项目的方案尽管原始，如果不用yolo模式，却绝对不用担心这些，上传什么，删除什么，完全可控。yolo模式可在使用一段时间之后依据具体场景打开，这样在日常自用的电脑上一样放心使用。没那么智能的缺点，可以通过多问几次以及作出skill来缓解。

## 适合人群
本项目最适合懂bash脚本，工作能写成skill的朋友。

## 亲测很爽的用法
其最爽使用方法为手机ssh登陆服务器，用手机语音输入法输入（需手机安装ssh客户端或者termux）。能做qq机器人或者AI小智交互吗？

## 代码
90% 以上的代码为 deepseek 生成, 包括名字 shepherd 都是 deepseek 推荐的




## 使用方法

### 最快跑起来
```bash
# 下载, 进入目录后
export DEEPSEEK_API_KEY="your-deepseek-api-key"  # 设置API Key
# 如果你有技能文件:  export shepherd_SKILLS_DIR="技能1目录:技能2目录:技能3目录"
chmod +x ./shepherd.sh  # 给执行权限
./shepherd.sh

# sudo apt install rlwrap 让输入更便捷，很必要
rlwrap -s 2000 -H ~/.shepherd_history  ./shepherd.sh

```

### 获得帮助
```bash
./shepherd.sh -h
```

### 正常使用
```bash
# 复制shepherd.sh到$PATH里的目录中，便于作为命令执行，如
sudo cp shepherd.sh /usr/local/bin/

# 在 ~/.bashrc 里根据你的需要加上
alias shepherd='export DEEPSEEK_API_KEY="your-deepseek-api-key"; export shepherd_SKILLS_DIR="your-skills-dirs"; rlwrap -s 2000 -H ~/.shepherd_history  shepherd.sh' 

# 请制作或下载技能，格式参考本readme.md， 技能目录直接用冒号":"隔开，如 export shepherd_SKILLS_DIR="$HOME/.shepherd/skills:xxxx/weather:xxxx/SelectStock"

# 技能临时添加可直接 cat xxx.md， 记忆被清理前也很好用

# 根据技能不同，可以分为多个专家: shepherd_math, shepherd_news, shepherd_stock, ... 可同时运行

# 运行交互模式
./shepherd
./shepherd -y  # yolo模式


# 运行单任务模式
./shepherd -r "统计所有log文件中的ERROR数量"

# 工作目录默认限制在当前目录，可在启动前设置工作目录
export shepherd_WORK_DIR="xxxxxx"

# shepherd作为bash 命令， 自然可以调用自己(调用单任务模式)

# 交互模式下，清理记忆(是清理对话历史，不是清理技能)
clear

# 执行超时控制默认30秒, 可改动程序开头配置区的 COMMAND_TIMEOUT

# 默认采用deepseek，如用千问或者其他，请在设置传参环境变量 shepherd_MODEL_ADDR 和 shepherd_MODEL_NAME

# 支持安全命令白名单和黑名单，添加或删除请直接改代码

```

## 项目协议MIT
