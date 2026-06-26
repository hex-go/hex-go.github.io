---
title: 'Linux基础-POSIX标准说明'
categories:
  - Linux
tags:
  - Linux
subtitle: ""
description:
date: 2024-04-22 00:00:00
toc: true
pinned: false
---

| 核心结论 | 说明 |
|---------|------|
| **POSIX 是接口标准，不是操作系统** | 它定义程序和操作系统之间的 API / Shell / 工具行为 |
| **Linux 基本遵循 POSIX，但不是所有 GNU 扩展都属于 POSIX** | 脚本写法是否可移植，关键看是否依赖 Bash/GNU 特性 |
| **`sh` 不等于 `bash`** | `/bin/sh` 在不同发行版可能指向 `dash`、`bash`、`busybox ash` |
| **正则、线程、文件接口都能看到 POSIX 影子** | BRE/ERE、pthread、open/read/write、signal 都属于典型场景 |

---

## 1.简介

POSIX（Portable Operating System Interface，可移植操作系统接口）是 IEEE 制定的一组操作系统接口标准。

它的目标是：让程序在 UNIX 和类 UNIX 系统之间尽量保持可移植。

需要注意：

- POSIX 不是 Linux；
- POSIX 不是某个命令；
- POSIX 定义的是一组接口和行为约定；
- Linux、macOS、BSD、AIX 等系统可以不同程度支持 POSIX。

{{< keypoint >}}
判断一段脚本或程序是否“可移植”，本质上是在判断它是否只依赖 POSIX 标准，而不是依赖某个发行版、某个 Shell、某个 GNU 扩展。
{{< /keypoint >}}

## 2.说明

### 2.1 POSIX 主要覆盖什么

POSIX 不是只定义系统调用，它覆盖范围比较广：

| 类型 | 说明 | 例子 |
|------|------|------|
| C API | 应用调用操作系统的接口 | `open()`、`read()`、`write()`、`fork()`、`exec()` |
| Shell | Shell 语法和执行行为 | 变量展开、管道、重定向、退出码 |
| 工具命令 | 常见命令的参数和输出行为 | `ls`、`cp`、`grep`、`sed`、`awk` |
| 正则表达式 | 标准正则规则 | BRE、ERE |
| 线程 | 线程 API | `pthread_create()`、`pthread_mutex_lock()` |
| 信号 | 进程间异步通知 | `SIGTERM`、`SIGKILL`、`SIGCHLD` |

### 2.2 POSIX Shell 与 Bash 的区别

很多线上脚本写的是：

```bash
#!/bin/sh
```

但内容却使用了 Bash 特性，例如：

```bash
#!/bin/sh
arr=(a b c)
[[ -f /etc/passwd ]] && echo ok
```

这类脚本在某些机器上可以运行，在 Ubuntu、Alpine、BusyBox 环境中可能直接失败。

原因：`/bin/sh` 不一定是 Bash。

| 系统 | `/bin/sh` 常见指向 |
|------|-------------------|
| Debian / Ubuntu | `dash` |
| CentOS / RHEL | `bash` 的 POSIX 兼容模式 |
| Alpine | BusyBox `ash` |
| BusyBox 镜像 | `ash` |

常见 Bash 特性与 POSIX Shell 对比：

| 写法 | Bash | POSIX sh | 建议 |
|------|------|----------|------|
| `[[ ... ]]` | 支持 | 不支持 | POSIX 用 `[ ... ]` |
| 数组 `arr=(a b)` | 支持 | 不支持 | POSIX 避免数组 |
| `{1..5}` | 支持 | 不支持 | 用 `seq` 或 `while` |
| `source file` | 支持 | 不标准 | POSIX 用 `. file` |
| `==` 字符串比较 | 支持 | 不标准 | POSIX 用 `=` |

示例：

```bash
# Bash 写法
if [[ "$name" == "root" ]]; then
  echo "root user"
fi
```

POSIX 兼容写法：

```sh
if [ "$name" = "root" ]; then
  echo "root user"
fi
```

### 2.3 正则表达式：BRE 与 ERE

POSIX 定义了两类正则表达式：

| 类型 | 名称 | 常见工具 | 特点 |
|------|------|----------|------|
| BRE | Basic Regular Expression | `grep`、`sed` 默认模式 | `+`、`?`、`|`、`()` 通常需要转义 |
| ERE | Extended Regular Expression | `grep -E`、`egrep`、`awk` | `+`、`?`、`|`、`()` 可直接使用 |

示例：匹配 `go` 或 `java`：

```bash
# BRE
grep 'go\|java' file.txt

# ERE
grep -E 'go|java' file.txt
```

示例：匹配一个或多个数字：

```bash
# BRE
grep '[0-9]\+' file.txt

# ERE
grep -E '[0-9]+' file.txt
```

需要注意：不同工具对正则的默认模式不同，写脚本时建议显式指定：

```bash
grep -E 'pattern' file.txt
sed -E 's/foo|bar/baz/g' file.txt
```

### 2.4 POSIX 线程：pthread

Linux C 程序中常见的 `pthread` 来自 POSIX Threads 标准。

典型 API：

| API | 作用 |
|-----|------|
| `pthread_create` | 创建线程 |
| `pthread_join` | 等待线程结束 |
| `pthread_mutex_init` | 初始化互斥锁 |
| `pthread_mutex_lock` | 加锁 |
| `pthread_mutex_unlock` | 解锁 |
| `pthread_cond_wait` | 条件变量等待 |

编译时通常需要链接 pthread：

```bash
gcc main.c -pthread -o main
```

`-pthread` 不只是链接库，还会影响编译和链接阶段的线程相关宏与参数，因此比单独写 `-lpthread` 更推荐。

### 2.5 POSIX 文件接口

很多 Linux 文件操作都可以追溯到 POSIX 接口。

常见接口：

| API | 作用 |
|-----|------|
| `open()` | 打开文件，返回文件描述符 |
| `read()` | 从文件描述符读取 |
| `write()` | 向文件描述符写入 |
| `close()` | 关闭文件描述符 |
| `stat()` | 获取文件元信息 |
| `chmod()` | 修改权限 |
| `chown()` | 修改属主属组 |

这也是为什么 Linux 中“文件描述符”是一个核心概念：

- 普通文件是文件描述符；
- 管道是文件描述符；
- Socket 也是文件描述符；
- 终端设备也是文件描述符。

### 2.6 什么时候需要关注 POSIX

| 场景 | 是否需要关注 | 原因 |
|------|--------------|------|
| 写一次性本机脚本 | 低 | 明确运行环境即可 |
| 写 Docker 镜像 entrypoint | 高 | 镜像可能只有 `/bin/sh`，没有 Bash |
| 写 CI/CD 脚本 | 高 | Runner 环境可能不同 |
| 写跨发行版安装脚本 | 高 | Debian / RHEL / Alpine 行为差异明显 |
| 写 C/C++ 系统程序 | 高 | API 可移植性依赖 POSIX |
| 使用 GNU 工具高级参数 | 中 | macOS / BusyBox 上可能不支持 |

建议：

1. 如果脚本使用 Bash 特性，第一行明确写 `#!/usr/bin/env bash`；
2. 如果脚本写 `#!/bin/sh`，就按 POSIX Shell 语法写；
3. Docker entrypoint 脚本尽量避免 Bash 数组、`[[ ]]`、`source` 等 Bash 专有语法；
4. 跨平台脚本不要默认依赖 GNU `sed -r`、`grep -P`、`xargs -r` 等扩展。

### 2.7 常见排查

#### 2.7.1 查看 `/bin/sh` 指向

```bash
ls -l /bin/sh
readlink -f /bin/sh
```

#### 2.7.2 检查脚本是否使用 Bash 特性

```bash
shellcheck script.sh
```

如果目标是 POSIX sh，可以指定：

```bash
shellcheck -s sh script.sh
```

#### 2.7.3 强制 Bash 按 POSIX 模式执行

```bash
bash --posix script.sh
```

或：

```bash
set -o posix
```

## 3.总结

1. POSIX 是操作系统接口标准，核心价值是提高 UNIX / 类 UNIX 系统之间的软件可移植性；
2. Linux 支持大量 POSIX 接口，但 GNU/Linux 中也存在很多非 POSIX 扩展；
3. `sh` 不等于 `bash`，脚本是否可移植首先看 shebang 和语法；
4. BRE / ERE、pthread、文件描述符、信号、Shell 工具行为都能看到 POSIX 标准的影响；
5. 需要跨发行版、跨容器镜像、跨 CI 环境运行的脚本，应优先按 POSIX 规则编写，或者明确要求 Bash。

## 4.参考

- [The Open Group Base Specifications Issue 7](https://pubs.opengroup.org/onlinepubs/9699919799/)
- [GNU Bash Manual - Bash POSIX Mode](https://www.gnu.org/software/bash/manual/html_node/Bash-POSIX-Mode.html)
- [ShellCheck](https://www.shellcheck.net/)
