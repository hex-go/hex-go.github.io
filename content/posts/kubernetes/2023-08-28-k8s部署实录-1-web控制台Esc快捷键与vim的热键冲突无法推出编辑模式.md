---
title: k8s部署实录-1-web控制台Esc快捷键与vim的热键冲突无法推出编辑模式
categories:
  - Kubernetes
tags:
  - Vim
date: '2023-08-28 19:58:28'
top: false
comments: true
series:
  - k8s部署实录
---

# 重要
- 前因： 
客户现场只提供JumpServer的web-client方式连接，root密码甚至是普通用户的密码也不提供。导致只能通过web-client进行环境部署操作。

- 现状：
使用JumpServer的WebClient方式进行vim编辑文件时，发现Vim的编辑模式无法Esc退出

- 原因分析：
  Esc会触发浏览器的Esc热键，导致Vim无法推出编辑模式

- 处理方案
> 将 jj 替代 Esc, 通过jj退出编辑模式
在~/.vimrc下添加映射 "inoremap jj <Esc>"

```bash
# $vimrc_path文件存在时，向文件中追加"inoremap jj <Esc>",否则新建文件并增加以上内容
vimrc_path="$HOME/.vimrc"
content_to_append="inoremap jj <Esc>"; if [ -f "$vimrc_path" ]; then echo "$content_to_append" >> "$vimrc_path"; else echo "$content_to_append" > "$vimrc_path"; fi
```

# Reference

在 Vim 编辑器中，`.vimrc` 文件是用于配置 Vim 的设置和行为的配置文件。
其中，`inoremap` 是 Vim 配置文件中的一个命令，用于定义插入模式（Insert Mode）下键盘映射。
键盘映射允许您将按键序列映射为其他按键、命令或字符串，以改变编辑器的行为。

具体来说，`inoremap` 是 "Insert Normal Mode Mapping" 的缩写，它会在插入模式下将一个按键序列映射为另一个按键序列。
常见的用例是将短按键序列映射为更长或更方便的按键序列，以提高编辑效率。

`inoremap jj <Esc>` 将按下`两个连续的 j 键`映射为按下`<Esc>键`，而 <Esc> 键用于从插入模式返回到普通模式。

解释一下具体含义：

`inoremap`: 表示在插入模式下进行键盘映射。
`jj`: 指定按键序列，即按两次 j 键。
`<Esc>`: 是特殊字符表示 <Esc> 键，它在 Vim 中表示退出插入模式，返回到普通模式。
这样，每当在插入模式中按下两次 j 键，Vim 将会识别为按下了一个 <Esc> 键，从而退出插入模式。
