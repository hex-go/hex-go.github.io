---
title: 'Docker易错集锦-1: Dockerfile的ENTRYPOINT中的环境变量无法替换'
categories:
  - Devops
tags:
  - Devops
subtitle: ""
description:
date: 2023-11-02T14:11:15+08:00
toc: true
---
# 1.问题描述
开发同事编写Dockerfile时遇到问题，`ENTRYPOINT ["java", "$JAVA_OPTS", "-jar", "/app.jar"]`无法实现变量替换。自己工作中涉及变量替换等操作时，都是将shell命令放到可执行文件中，虽然对同事的这种写法奇怪，但当时也确实没发现错误的原因，深入了解过EXEC格式后，吃透了这个问题。

# 2.说明
Dockerfile中的`ENTRYPOINT\RUN\CMD`具备两种格式：`EXEC格式`和`SHELL格式`。

## 2.1 exec格式：
示例：
`ENTRYPOINT ["sh", "-c", "/start.sh"]`，

实现： 
直接使用命令本身来执行，不需要通过Shell解释器。实际程序PID=1，可以接收、处理信号，实现优雅启停。

优点：
- 高效
- 安全

缺点：
- 不能使用Shell语法，灵活性差

## 2.2 shell格式: 
写法示例：
```Dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    package-A \
    package-B \
    package-C  \
    && rm -rf /var/lib/apt/lists/*
```

实现：
此格式是使用Shell解释器来执行命令，最终程序被执行时，类似于`/bin/sh -c`的方式运行了我们的程序，这样会导致`/bin/sh`以**PID为1**的进程运行，
而实际程序是它`fork/execs`出来的子进程。

优点：
可以使用Shell语法，例如管道、重定向等，这增加了Dockerfile的灵活性；

缺点：
- sh父进程带来额外开销；
- 存在安全隐患，如shell注入攻击；
- 无法实现优雅启停，`docker stop`的`SIGTERM`信号只是发送给容器中`PID为1`的进程，无法传递给子进程，实际进程实际程序无法接收、处理信号；


# 3.解决

想要在`EXEC格式`的`ENTRYPOINT`中引用环境变量，需要编写`shell`脚本。在脚本中，变量替换与反斜线转义都是生效的。然后`ENTRYPOINT`使用`exec`格式执行。

即脚本`/start.sh`内容为
```bash
java $JAVA_OPTS -jar /app.jar
```
Dockerfile中的内容为
```Dockerfile
ENTRYPOINT ["/bin/sh", "-c", "/start.sh"]
```
> 也可以通过 `ENTRYPOINT ["/bin/sh", "-c", "java $JAVA_OPTS -jar /app.jar"]`实现变量替换，但java进程无法接收、处理信号，不推荐

# 3.总结

一般来说，除非需要 shell 功能，否则应使用`exec`格式；如果需要`ENTRYPOINT`或`CMD`中的 shell 功能，则应考虑编写`shell`脚本，然后使用`exec`格式执行。


shell格式：使用Shell解释器来执行命令，更灵活但也更复杂、更容易受到攻击。
exec格式：直接使用命令本身来执行，更简单、更高效、更安全，推荐使用。

| 名称      | 最佳使用场景         | shell功能         | 是否能处理信号               | 程序ID    |
|---------|----------------|-----------------|-----------------------|---------|
| shell格式 | RUN            | 支持(可引用变量、反斜线转义) | 否                     | 1进程的子进程 |
| exec格式  | ENTRYPOINT\CMD | 不支持             | 是(可将信号传递给程序处理，实现优雅启停) | 1       |


# 4.参考

[exec-form 变量替换](https://docs.docker.com/reference/dockerfile/#variable-substitution)
[优雅的终止docker容器](https://xiaozhou.net/stop-docker-container-gracefully-2016-09-08.html)