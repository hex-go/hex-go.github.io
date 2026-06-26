---
title: k8s部署实录-1-web控制台Esc快捷键与vim的热键冲突
categories:
  - Kubernetes
tags:
  - Vim
  - JumpServer
date: 2023-08-28 00:00:00
top: false
comments: true
series:
  - k8s部署实录
---

# 重要

通过 JumpServer WebClient 编辑文件时，Esc 被浏览器拦截，Vim 无法退出插入模式。将 `jj` 映射为 `<Esc>` 即可绕过。

## 1.简介

客户现场只提供 JumpServer WebClient 连接，不提供 root 密码。通过浏览器操作 Vim 时，按下 Esc 触发浏览器的全屏退出等快捷键，Vim 收不到 `<Esc>` 键。

## 2.说明

### 2.1 报错链路

```text
JumpServer WebClient
   ↓
浏览器拦截 Esc（全屏退出等快捷键）
   ↓
Vim 插入模式下收不到 <Esc>
   ↓
无法退出插入模式
```

### 2.2 处理

将 `jj` 映射为 `<Esc>`：

```bash
vimrc_path="$HOME/.vimrc"
if [ -f "$vimrc_path" ]; then
    echo 'inoremap jj <Esc>' >> "$vimrc_path"
else
    echo 'inoremap jj <Esc>' > "$vimrc_path"
fi
```

效果：插入模式下连续按两次 `j`，等效于按 `<Esc>` 退出插入模式。

### 2.3 `inoremap` 说明

| 字段 | 含义 |
|------|------|
| `i` | 仅在 **插入模式**（Insert Mode）生效 |
| `nore` | 禁止递归映射（映射不再触发其他映射） |
| `map` | 按键映射 |
| `jj` | 按键序列：连续按两次 j |
| `<Esc>` | 映射目标：退出插入模式 |
