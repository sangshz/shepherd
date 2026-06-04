---
name: 文件操作技能
description: 批量重命名, 批量复制, 批量删除, 压缩, 解压, 整理文件
---

```bash
# 批量重命名
for f in *.jpg; do mv "$f" "img_$f"; done

# 批量复制到备份目录
mkdir -p backup && cp *.log backup/

# 批量删除空文件
find . -type f -empty -delete

# 压缩单个文件
gzip file.log

# 压缩目录
tar -czf archive.tar.gz directory/

# 解压
tar -xzf archive.tar.gz


# 创建多级目录
mkdir -p project/{src,test,docs}

# 按日期整理文件
mkdir -p archive/$(date +%Y%m)
mv *.log archive/$(date +%Y%m)/


# 查找并删除7天前的日志
find . -name "*.log" -mtime +7 -delete

# 查找并压缩大文件
find . -size +10M -exec gzip {} \;

# 查找并修改权限
find . -type f -name "*.sh" -exec chmod +x {} \;

```
