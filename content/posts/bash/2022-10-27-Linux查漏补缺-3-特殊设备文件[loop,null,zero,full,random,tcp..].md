---
title: 'Linux查漏补缺-3-特殊设备文件[loop,null,zero,full,random,tcp..]'
categories:
  - Linux
tags:
  - Bash
  - Linux
  - 特殊/dev
date: '2022-10-27 01:46:34'
pinned: true
top: false
comments: true
series:
- Linux操作系统-查漏补缺
---

## 1.简介

Linux 把硬件设备抽象为文件，存放在 `/dev` 目录下。除此之外，内核还提供了一组**虚拟设备文件**——它们不对应任何物理硬件，但对日常运维和脚本编写极其有用。本文记录这些"特殊文件"的用途和区别。

经常困扰我的几个问题：
- `dd if=/dev/zero` 和 `dd if=/dev/null` 有什么区别？
- `/dev/random` 为什么会阻塞？什么时候该用 `/dev/urandom`？
- `/dev/tcp` 不是真实文件，为什么 bash 里能用？

## 2.说明

### 2.0 设备文件基础

设备文件分为三类：

| 类型 | 标识 | 特点 | 例子 |
|------|------|------|------|
| **字符设备** | `c` | 按字节流读写，不可随机访问 | 终端(`/dev/tty`)、串口(`/dev/ttyS0`) |
| **块设备** | `b` | 按块读写，可随机访问 | 硬盘(`/dev/sda`)、loop设备(`/dev/loop0`) |
| **网络设备** | 无设备文件 | 通过 socket 收发数据包 | 网卡(`eth0`)、回环(`lo`) |

通过 `ls -l` 第一列区分：

```bash
ls -l /dev/sda /dev/tty /dev/null
# brw-rw----  1 root disk      8, 0  sda    ← b = 块设备
# crw-rw-rw-  1 root tty       5, 0  tty    ← c = 字符设备
# crw-rw-rw-  1 root root      1, 3  null   ← c = 字符设备（虚拟）
```

> 逗号前后的数字是**主设备号**和**次设备号**。主设备号决定驱动，次设备号区分同一驱动下的不同实例。`mknod` 命令可以手动创建设备文件。

### 2.1 /dev/null —— 数据黑洞

任何写进去的数据直接丢弃，读取时立即返回 EOF（空）。

```bash
# 丢弃命令输出
verbose_command > /dev/null 2>&1

# 清空文件而不删除（保留 inode 和权限）
cat /dev/null > large.log

# 测试读取——立即返回空
cat /dev/null
# (无输出)
```

> 对比 `truncate -s 0 file` 和 `> file`：前者**重置大小**，后者通过重定向**截断**。`cat /dev/null > file` 与 `> file` 效果相同，都是截断。

### 2.2 /dev/zero —— 无限零流

读取时无限输出 `\0`（空字节），写入时同 `/dev/null`（丢弃）。

```bash
# 创建指定大小的空文件
dd if=/dev/zero of=test.bin bs=1M count=100

# 擦除磁盘（写零）
dd if=/dev/zero of=/dev/sdb bs=4M status=progress

# 初始化 swap 文件
dd if=/dev/zero of=/swapfile bs=1M count=4096
mkswap /swapfile
```

**与 `/dev/null` 的区别：**
- `/dev/null`：读 → 立刻 EOF；写 → 丢弃
- `/dev/zero`：读 → 无限输出 `\0`；写 → 丢弃
- `dd if=/dev/null` 不会产生任何数据，`dd if=/dev/zero` 会一直输出直到 `count` 或磁盘满

### 2.3 /dev/full —— 模拟磁盘满

读取时输出 `\0`（同 `/dev/zero`），写入时**始终返回 ENOSPC（No space left on device）**。

```bash
echo "test" > /dev/full
# bash: echo: write error: No space left on device
```

用途：测试程序在磁盘满时的行为。不需要真的写满一块磁盘来验证错误处理。

### 2.4 /dev/random 与 /dev/urandom —— 随机数

两者都提供随机字节流，区别在于**熵池耗尽时的行为**：

| | `/dev/random` | `/dev/urandom` |
|---|-------------|----------------|
| 熵耗尽时 | **阻塞**，等待新熵 | **不阻塞**，用算法续出 |
| 随机性 | 真随机（硬件噪声源） | 伪随机（熵池耗尽后降级为 CSPRNG） |
| 适用场景 | 长期密钥（GPG/SSL 私钥生成） | 日常使用（session ID、临时密钥、擦除磁盘） |

```bash
# 生成随机密码（不阻塞）
head -c 16 /dev/urandom | base64

# 擦除磁盘用随机数据（比 /dev/zero 更安全，防止数据恢复）
dd if=/dev/urandom of=/dev/sdb bs=4M status=progress

# /dev/random 可能阻塞——尤其在虚拟机中熵源不足
dd if=/dev/random of=/tmp/rand bs=32 count=1 2>&1
# 可能 hang 住几秒到几分钟
```

> **实际建议：除非生成需要长期安全的密钥对，永远用 `/dev/urandom`。** 现代 Linux 内核（5.4+）在 `/dev/random` 初始化后也不再阻塞，行为趋同 `/dev/urandom`。

### 2.5 /dev/loop —— 文件当磁盘

Loop 设备让一个普通文件被当作块设备来挂载：

```bash
# 创建 100MB 的磁盘镜像文件
dd if=/dev/zero of=disk.img bs=1M count=100

# 格式化为 ext4
mkfs.ext4 disk.img

# 挂载
mount -o loop disk.img /mnt/loop-test
```

loop 设备的典型用途：Docker 镜像层（overlay2 驱动）、Snap 包、ISO 挂载。

```bash
# 查看当前 loop 设备使用情况
losetup -a
```

### 2.6 /dev/tcp —— bash 内建的网络连接（非真实文件）

`/dev/tcp` 不是一个真实的设备文件——它在文件系统中不存在，但被 **bash** 作为特殊路径识别。

```bash
# 测试 TCP 端口是否通（替代 telnet/nc）
echo > /dev/tcp/github.com/443 && echo "443 open" || echo "443 closed"

# 简单的 HTTP 请求
exec 3<>/dev/tcp/example.com/80
echo -e "GET / HTTP/1.0\r\nHost: example.com\r\n\r\n" >&3
cat <&3
```

> 只在 bash 下有效。`sh`、`zsh`、`python`、`nc` 等工具看不到它。如果在脚本中使用，确保 `#!/bin/bash`。

### 2.7 速查表

| 设备 | 读行为 | 写行为 | 典型用途 |
|------|--------|--------|---------|
| `/dev/null` | 立即返回 EOF | 丢弃 | 丢弃输出、清空文件 |
| `/dev/zero` | 无限 `\0` | 丢弃 | 创建空文件、擦除磁盘 |
| `/dev/full` | 无限 `\0` | 返回 ENOSPC | 测试磁盘满的错误处理 |
| `/dev/random` | 真随机字节，可能阻塞 | — | 长期密钥生成 |
| `/dev/urandom` | 伪随机字节，不阻塞 | — | 日常随机数 |
| `/dev/loopN` | 读取文件映射的块 | 写入文件映射块 | 文件当磁盘挂载 |
| `/dev/tcp/HOST/PORT` | 网络数据 | 网络数据 | bash 内建 TCP 测试 |

## 3.参考

- [Linux Kernel - Allocated Devices](https://www.kernel.org/doc/html/v4.20/admin-guide/devices.html)
- [`/dev/tcp` — bash 手册](https://www.gnu.org/software/bash/manual/html_node/Redirections.html)
- [关于 `/dev/tcp/${HOST}/${PORT}` 的说明](https://www.jianshu.com/p/f10736931b93)
- [Myths about /dev/urandom](https://www.2uo.de/myths-about-urandom/)
