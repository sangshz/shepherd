---
name: 基础命令指南
description: 文件查看 搜索, 查找, 统计, 文本处理, 管道组合
---

## 文件查看
- `ls -la` : 列出所有文件（含隐藏）
- `cat file` : 查看完整文件
- `head -n 20 file` : 查看前20行
- `tail -n 20 file` : 查看后20行

## 搜索查找
- `grep "pattern" file` : 在文件中搜索
- `grep -r "pattern" .` : 递归搜索所有文件
- `find . -name "*.txt"` : 按名称查找
- `find . -size +1M` : 查找大于1MB的文件

## 统计计数
- `wc -l file` : 统计行数
- `wc -w file` : 统计单词数
- `sort file | uniq -c` : 统计重复次数

## 文本处理
- `sed 's/old/new/g' file` : 替换文本
- `cut -d',' -f1 file` : 提取CSV第一列
- `awk '{print $1}' file` : 提取第一列

## 管道组合示例
```bash
# 请执行以下命令，统计错误次数
grep "ERROR" app.log | wc -l

# 请执行以下命令，找出最常用的10个单词
cat file.txt | tr ' ' '\n' | sort | uniq -c | sort -rn | head -10

# 请执行以下命令，批量重命名
for f in *.txt; do mv "$f" "${f%.txt}.md"; done
```

## 引用自身
```bash
# 请用 shepherd 执行，统计文件数
- shepherd.sh --run "统计文件数"

# 请调用你自己，统计文件数
- shepherd.sh --run "统计文件数"
```
