---
title: Docker 易错集锦 — ENTRYPOINT 中环境变量无法替换
categories:
  - Devops
tags:
  - Devops
  - Docker
date: 2023-11-02T14:11:15+08:00
top: false
comments: true
---

# 重要

`ENTRYPOINT ["java", "$JAVA_OPTS", "-jar", "/app.jar"]` 中 `$JAVA_OPTS` 不会被替换。exec 格式不经过 shell，不支持变量展开。

## 1. 问题

不管 `ENV JAVA_OPTS="-Xmx512m"` 还是 `docker run -e JAVA_OPTS="-Xmx1024m"`，`ENTRYPOINT` 中 `$JAVA_OPTS` 始终是字面量。

## 2. 原因：exec vs shell

Dockerfile 的 `ENTRYPOINT`/`RUN`/`CMD` 有两种格式：

| | exec 格式 | shell 格式 |
|------|----------|-----------|
| 写法 | `CMD ["app", "--port=8080"]` | `CMD app --port=8080` |
| 执行方式 | 直接 exec，不经过 `/bin/sh` | `/bin/sh -c "app --port=8080"` |
| 变量展开 | 不支持 | 支持 |
| PID 1 | 命令自身 | `/bin/sh`，命令为其子进程 |
| 信号处理 | 能收到 SIGTERM，可优雅启停 | SIGTERM 发给 `/bin/sh`，子进程收不到 |
| 适用场景 | ENTRYPOINT / CMD | RUN |

变量展开失败是因为 exec 格式不调用 shell，`$JAVA_OPTS` 永远不会被替换。

## 3. 解决

把 shell 逻辑放到脚本中，ENTRYPOINT 用 exec 格式调用脚本：

```bash
# start.sh
java $JAVA_OPTS -jar /app.jar
```

```dockerfile
ENV JAVA_OPTS="-Xmx512m"
COPY start.sh /start.sh
ENTRYPOINT ["/bin/sh", "-c", "/start.sh"]
```

不推荐直接在 ENTRYPOINT 里内联 shell 命令（如 `ENTRYPOINT ["/bin/sh", "-c", "java $JAVA_OPTS -jar /app.jar"]`），因为 PID 1 变成 `/bin/sh`，容器内的 java 进程收不到 `docker stop` 的 SIGTERM，无法优雅退出。

## 4. 总结

| 场景 | 推荐格式 | 原因 |
|------|----------|------|
| `RUN` | shell 格式 | 需要 `&&`、管道、变量 |
| `ENTRYPOINT`/`CMD` | exec 格式 + 脚本 | PID 1 正确，信号可达 |
| 需要变量展开 | exec 格式 + 脚本 | 变量在脚本内展开 |

## 参考

- [Docker exec form 变量替换](https://docs.docker.com/reference/dockerfile/#variable-substitution)
- [优雅终止 Docker 容器](https://xiaozhou.net/stop-docker-container-gracefully-2016-09-08.html)
