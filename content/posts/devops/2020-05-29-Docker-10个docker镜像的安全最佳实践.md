---
title: Docker-10个docker镜像的安全最佳实践
categories:
  - Devops
tags:
  - Devops
  - Docker
  - Dockerfile
  - Draft
date: '2020-05-29 09:36:32'
top: false
draft: true
comments: true
---

# 重要

# 1. 概念说明

- 构建`Context`说明
  执行`docker build`命令时，当前工作目录称为构建上下文。默认情况下，`dockerfile`也在当前目录，但可以使用文件标志（-f）指定不同的位置。 无论`dockerfile`实际在哪里，执行构建命令的当前目录中的文件和目录的所有递归内容都将作为`Context`发送到`Docker Daemon`程序。

- 

| 操作                                                   | 镜像大小 | 安全 | 构建性能 | 可读性 |
| ------------------------------------------------------ | -------- | ---- | -------- | ------ |
| `RUN、COPY、ADD`命令会创建layer，其他指令不会增加layer | 是       | 否   | 否       | 否     |
| 采取多阶段构建, 以减少最终运行镜像大小，环境clean。    | 是       | 是   | 否       | 是     |
| 使用`.dockerignore`排除构建不需要的文件。              | 否       | 是   | 是       | 否     |
| 将长或复杂的RUN语句拆分到多行上，用反斜杠分隔。        | 否       | 否   | 否       | 是     |
|                                                        |          |      |          |        |
|                                                        |          |      |          |        |
|                                                        |          |      |          |        |

# 2. 常见操作



## 2.1 安装包

> 1. 使用`RUN apt-get update && apt-get install -y `确保`dockerfile`安装最新的软件包版本。(如果将命令分成两行RUN, 会导致缺少缓存，`apt-get install`失败)。
> 2. `apt-get clean`命令清理`/var/cache/apt/archives`目录下的内容，且在官方`Ubuntu/Debian`镜像会在安装后自动清理，所以不需要显示使用。

- apt包安装

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    package-bar \
    package-baz \
    package-foo  \
    && rm -rf /var/lib/apt/lists/*
```

- apk安装

```Dockerfile
## 国内加速
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
RUN apk upgrade --update \
    && apk add -U tzdata \
    && rm -rf /var/cache/apk/*
```
- 


## 2.2 设置时区
> 时区原理以及具体说明，参考

```dockerfile
FROM alpine:3.19.1
ENV TZ=Asia/Shanghai

RUN apk add --no-cache tzdata
```





##　2.3 多阶段构建





# 2. 10个安全最佳实践

# 3. Dockerfile示例
## 3.1 Alpine镜像
### 3.1.1 golang镜像

## 3.2 Ubuntu镜像
### 3.2.1 golang镜像

### 3.2.1 apt安装包和清理




# Reference

**[Docker官方文档-Dockerfile最佳实践](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)**

**[10 Docker Image Security Best Practices](https://snyk.io/blog/10-docker-image-security-best-practices/)**

[使用Alpine基础镜像-add user](https://stackoverflow.com/questions/49955097/how-do-i-add-a-user-when-im-using-alpine-as-a-base-image)

[使用Alpine基础镜像-set Timezone]()

