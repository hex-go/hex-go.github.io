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

| 核心结论 | 说明 |
|---------|------|
| **`/dev/null` 是黑洞，`/dev/zero` 是零流** | 前者读到 EOF，后者读出无限 `\0` |
| **`/dev/full` 专门用于模拟磁盘写满** | 写入永远返回 `ENOSPC` |
| **现代 Linux 中 `/dev/random` 和 `/dev/urandom` 差异已经很小** | 随机池初始化后，两者都来自内核 CSPRNG |
| **`/dev/tcp` 不是真实设备文件** | 它是 Bash 重定向语法的特殊路径 |
| **`/dev/tty` 指向当前控制终端** | 脚本中需要强制与终端交互时常用 |

---

## 1.简介

Linux 把硬件设备抽象为文件，存放在 `/dev` 目录下。除此之外，内核还提供了一组**虚拟设备文件**——它们不对应任何物理硬件，但对日常运维和脚本编写极其有用。本文记录这些"特殊文件"的用途和区别。

经常困扰我的几个问题：
- `dd if=/dev/zero` 和 `dd if=/dev/null` 有什么区别？
- `/dev/random` 为什么以前会阻塞？现在还该不该用 `/dev/urandom`？
- `/dev/tcp` 不是真实文件，为什么 bash 里能用？
- `/dev/tty`、`/dev/stdin`、`/dev/fd` 到底指向什么？

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

早期经验中，常说 `/dev/random` 熵池不足时会阻塞，`/dev/urandom` 不阻塞。这个说法在老内核时代有帮助，但现代 Linux 需要更精确地理解。

| 项目 | `/dev/random` | `/dev/urandom` |
|------|---------------|----------------|
| 来源 | 内核 CSPRNG | 内核 CSPRNG |
| 初始化前 | 可能阻塞，等待随机池初始化 | 现代内核已避免返回未初始化随机数 |
| 初始化后 | 通常不再因为熵计数阻塞 | 不阻塞 |
| 日常建议 | 很少需要直接使用 | 通用选择 |

```bash
# 生成随机密码（不阻塞）
head -c 16 /dev/urandom | base64

# 擦除磁盘用随机数据（比 /dev/zero 更安全，防止数据恢复）
dd if=/dev/urandom of=/dev/sdb bs=4M status=progress

# /dev/random 在随机池初始化前可能阻塞
dd if=/dev/random of=/tmp/rand bs=32 count=1 2>&1
```

> **实际建议：日常随机数优先使用 `/dev/urandom`。** 现代 Linux 中，随机池初始化完成后，`/dev/random` 与 `/dev/urandom` 都来自内核 CSPRNG，差异已经很小。

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

loop 设备的典型用途：ISO 挂载、Snap 包、磁盘镜像测试。需要注意，Docker 默认 `overlay2` 驱动不是靠 loop 设备实现镜像层；旧的 devicemapper loop-lvm 才与 loop 设备关系更明显。

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

### 2.7 /dev/tty —— 当前控制终端

`/dev/tty` 表示当前进程的控制终端。

常见用途：脚本的标准输入被管道占用时，仍然需要从终端读取用户输入。

```bash
echo "please input password:" > /dev/tty
read -r password < /dev/tty
```

对比：

```bash
cat file.txt | while read -r line; do
  read -r input
  echo "$input"
done
```

上面 `read` 会从管道读取，而不是从键盘读取。需要强制从键盘读时，使用 `/dev/tty`。

### 2.8 /dev/stdin、/dev/stdout、/dev/stderr

这三个路径通常是符号链接：

```bash
ls -l /dev/stdin /dev/stdout /dev/stderr
# /dev/stdin  -> /proc/self/fd/0
# /dev/stdout -> /proc/self/fd/1
# /dev/stderr -> /proc/self/fd/2
```

| 路径 | 文件描述符 | 说明 |
|------|------------|------|
| `/dev/stdin` | 0 | 标准输入 |
| `/dev/stdout` | 1 | 标准输出 |
| `/dev/stderr` | 2 | 标准错误 |

它们常用于只接受文件路径参数的程序，把标准输入伪装成文件：

```bash
some_command | tool --input /dev/stdin
```

### 2.9 /dev/fd

`/dev/fd` 通常指向当前进程的文件描述符目录：

```bash
ls -l /dev/fd
# /dev/fd -> /proc/self/fd

ls -l /proc/$$/fd
```

典型用途：Bash 进程替换。

```bash
diff <(sort a.txt) <(sort b.txt)
```

Bash 会把 `<(...)` 展开为类似 `/dev/fd/63` 的路径，供 `diff` 当作文件读取。

### 2.10 /dev/shm —— 内存文件系统

`/dev/shm` 通常是 tmpfs，位于内存中。

```bash
df -h /dev/shm
mount | grep /dev/shm
```

常见用途：

- 进程间共享内存；
- 临时高速文件；
- 容器中 Chrome、PostgreSQL 等程序可能依赖 `/dev/shm`。

Docker 默认 `/dev/shm` 较小，运行浏览器或数据库测试时可能需要调整：

```bash
docker run --shm-size=1g ...
```

### 2.11 速查表

| 设备 / 路径 | 读行为 | 写行为 | 典型用途 |
|-------------|--------|--------|----------|
| `/dev/null` | 立即 EOF | 丢弃 | 丢弃输出、截断文件 |
| `/dev/zero` | 无限 `\0` | 丢弃 | 创建空文件、初始化文件 |
| `/dev/full` | 无限 `\0` | 返回 ENOSPC | 测试磁盘满错误处理 |
| `/dev/random` | CSPRNG，初始化前可能阻塞 | — | 少数安全敏感场景 |
| `/dev/urandom` | CSPRNG，不阻塞 | — | 日常随机数 |
| `/dev/loopN` | 读取文件映射块 | 写入文件映射块 | 文件当磁盘挂载 |
| `/dev/tcp/HOST/PORT` | 网络数据 | 网络数据 | Bash 临时测端口 |
| `/dev/tty` | 当前控制终端输入 | 当前控制终端输出 | 脚本强制终端交互 |
| `/dev/stdin` | fd 0 | — | 标准输入路径化 |
| `/dev/stdout` | — | fd 1 | 标准输出路径化 |
| `/dev/stderr` | — | fd 2 | 标准错误路径化 |
| `/dev/fd/N` | 文件描述符 N | 文件描述符 N | 进程替换、fd 调试 |
| `/dev/shm` | tmpfs 文件 | tmpfs 文件 | 共享内存、临时高速文件 |

## 3.总结

1. `/dev/null` 读取为空、写入丢弃；`/dev/zero` 读取无限零字节；
2. `/dev/full` 适合测试磁盘满时的错误处理；
3. 现代 Linux 中 `/dev/random` 与 `/dev/urandom` 都依赖内核 CSPRNG，日常优先使用 `/dev/urandom`；
4. `/dev/tcp` 是 Bash 特性，不是真实设备文件，也不是 POSIX 标准；
5. `/dev/tty`、`/dev/stdin`、`/dev/fd` 这类路径本质上是终端和文件描述符的映射；
6. `/dev/shm` 是 tmpfs，常用于共享内存和容器运行时临时文件。

## 4.参考

- [Linux Kernel - Allocated Devices](https://www.kernel.org/doc/html/v4.20/admin-guide/devices.html)
- [`/dev/tcp` — bash 手册](https://www.gnu.org/software/bash/manual/html_node/Redirections.html)
- [关于 `/dev/tcp/${HOST}/${PORT}` 的说明](https://www.jianshu.com/p/f10736931b93)
- [Myths about /dev/urandom](https://www.2uo.de/myths-about-urandom/)
