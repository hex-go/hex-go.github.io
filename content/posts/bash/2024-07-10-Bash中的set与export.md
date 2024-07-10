---
title: 'Bash中的set与export'
categories:
  - Bash
tags:
  - Bash
  - Linux
subtitle: "近期由于window的bat脚本与Linux下的bash脚本混写，对bash中set命令发生了混淆"
description:
date: 2024-07-10T10:18:41+08:00
toc: true

---

## 易混淆点
- windows系统bat脚本中，通过SET关键字设置环境变量
- Bash中的容易由unset，误联想set也可设置变量


## 正解：
- bash中通过`TEST="123"`的形式设置变量，只在当前进程生效；
- bash中通过`export TEST="123"`的形式设置环境变量，对当前进程及子进程都生效；
- bash中，将`export TEST="123"`写入`.bashrc`等文件中，实现持久化的效果；
- bash中的`set`关键字，只能用来设置`shell属性(set -x)`和`位置参数($1 $2)`。

## 示例
1. 临时变量，当前会话(进程)中生效
```bash
TEST=123 && echo $TEST
```

2. 设置临时变量，无法在当前进程的子进程中生效
> 注意命令中的引号，等同于执行脚本中，echo变量
```bash
TEST=123 && bash -c 'echo "$TEST"'
```

3. export环境变量，在子进程中生效
```bash
export TEST=123 && bash -c 'echo "$TEST"'
```

4. set设置位置参数
> 下面命令输出为：foo=baz 22 33
```bash
set foo=baz 22 33 ;echo $1 $2 $3
```

5. set设置shell属性
> 详细信息请执行`help set`
```bash


```

## 总结
Bash中 `set` 用于设置`shell属性`和`位置参数`; `export`关键字用来标记要导出的变量，未导出的变量不会被子进程继承。如果需要持久化，需要将`export`命令写到`.bashrc`这类文件中。