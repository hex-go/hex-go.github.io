---
title: Docker-Dockerfile的最佳实践
categories:
  - Devops
tags:
  - Devops
  - Docker
  - Dockerfile
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

| 操作                                     | 镜像大小 | 安全 | 构建性能 | 可读性 |
|----------------------------------------|------|----|------|-----|
| `RUN、COPY、ADD`命令会创建layer，其他指令不会增加layer | 是    | 否  | 否    | 否   |
| 采取多阶段构建, 以减少最终运行镜像大小，环境clean。          | 是    | 是  | 否    | 是   |
| 使用`.dockerignore`排除构建不需要的文件。           | 否    | 是  | 是    | 否   |
| 将长或复杂的RUN语句拆分到多行上，用反斜杠分隔。              | 否    | 否  | 否    | 是   |
|                                        |      |    |      |     |
|                                        |      |    |      |     |
|                                        |      |    |      |     |

# 2. 最佳实践

- [尽可能使用官方Docker镜像](#21-尽可能使用官方docker镜像)
- [使用固定的镜像标签，而非latest]()
- [Alpine并不一定是最佳选择](#22-alpine并不一定是最佳选择)
- [限制镜像layers数量](#23-限制镜像layers数量)
- [以非root用户运行](#24-以非root用户运行)
- [请勿使用低于`10000`的`UID`](#25-uid10000)
- [使用静态 UID 和 GID](#26-使用静态uid和gid)
- [只在`CMD`中存储参数]()
- 始终使用 COPY 而不是 ADD（只有一个例外）
- 始终在同一运行语句中结合运行 apt-get update 和 apt-get install

## 2.1 尽可能使用官方Docker镜像
相比自己构建镜像安装sdk来说，使用适合的官方镜像是首选。因为官方镜像经过了数百万用户的优化和测试。**找不到合适的官方镜像**或者**官方基础镜像包含漏洞**时，再考虑自己从头创建镜像。

例如，相较于手动安装SDK，如下
```Dockerfile
FROM ubuntu
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
| gpg --dearmor > microsoft.asc.gpg \
&& sudo mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/ \
&& wget -q https://packages.microsoft.com/config/ubuntu/18.04/prod.list \
&& sudo mv prod.list /etc/apt/sources.list.d/microsoft-prod.list \
&& sudo chown root:root /etc/apt/trusted.gpg.d/microsoft.asc.gpg \
&& sudo chown root:root /etc/apt/sources.list.d/microsoft-prod.list
RUN sudo apt-get install dotnet-sdk-3.1
```
更推荐使用官方镜像
```Dockerfile
FROM mcr.microsoft.com/dotnet/core/sdk:3.1-buster
```

## 2.2 Alpine并不一定是最佳选择

Alpine镜像由于受到严格控制，具备镜像小，安全性高的特点，在绝大多少情况下被推荐使用（Docker官方推荐）。

但无脑使用Alpine也并不可取，也要意识到以下两个问题：

- 像python使用Alpine会带来构建慢、镜像体积过大且有时会引入运行时错误，不推荐使用[详情可参考：禁止使用Alpine作为Python的基础镜像构建]({{<ref "/posts/devops/2020-05-29-Docker-禁止使用Alpine作为Python的基础镜像构建">}})
- Alpine镜像的第二点--安全性。大多数漏扫工具都找不到Alpine镜像的任何漏洞。但这并不意味着Alpine百分百安全。

## 使用明确的镜像标签，而非latest

基于`lastest`镜像构建的缺点如下：

- Docker 镜像编译不一致。`latest` 标签，那么每次构建都会拉取一个最新构建的Docker镜像。引入这种非确定性的行为会影响编译的可重复性。
- node Docker 映像基于成熟的操作系统，其中包含运行 Node.js 网络应用时可能需要也可能不需要的各种库和工具。这有两个缺点。首先，更大的映像意味着更大的下载量，除了增加存储需求外，还意味着需要更多时间下载和重新构建映像。其次，这意味着您有可能将所有这些库和工具中可能存在的安全漏洞引入到映像中。

使用 major.minor，而不是 major.minor.patch，以确保您始终使用特定的图像版本：

保持你的构建正常工作（最新版本意味着你的构建在未来可能会任意损坏，而 major.minor 版本则意味着这种情况不会发生）
在您构建的新镜像中包含最新的安全更新。

### 始终在同一RUN语句中运行apt-get update 和 apt-get install

在 RUN 中单独使用 apt-get update 会导致缓存问题和后续的 apt-get install指令失败。

这与 Docker 使用的缓存机制有关。在构建镜像时，Docker 会将初始指令和修改后的指令对比，指令未修改的会使用之前构建的缓存。例如：

将`apt-get update`单独放到一个RUN语句中：

```dockerfile
FROM ubuntu:22.04
RUN apt-get update
RUN apt-get install -y curl
```

之后修改dockerfile，增加`nginx`

```dockerfile
FROM ubuntu:22.04
RUN apt-get update
RUN apt-get install -y curl nginx
```

因为`RUN apt-get update`未发生变化，apt-get update 就不会被执行，而是使用之前构建的缓存。由于没有运行`apt-get update`，构建可能无法获得最新版本的 curl 和 nginx 软件包。

下面是推荐的`Dockerfile`写法：

```dockerfile
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential  \
    && rm -rf /var/lib/apt/lists/*
# Debian和Ubuntu的官方镜像会自动执apt-get clean，因此无需明确调用。
```



## 2.3 限制镜像layers数量

Dockerfile中的每一条`RUN`指令最终都会在最终镜像中创建一个额外的`layer`。限制`layer`的数量，以保持镜像的轻量级。



## 2.4 以非root用户运行

以非 root 用户身份运行容器可大大降低从容器到主机提权的风险。详情参考[Docker文档](https://docs.docker.com/engine/security/#linux-kernel-capabilities)。

对于基于 Debian 的映像，可以通过下面命令从容器中移除 root 用户：

```dockerfile
RUN groupadd -g 10001 paas && \
   useradd -u 10000 -g paas paas \
   && chown -R paas:paas /app

USER 10001
```

> 从容器中移除root后，会存在权限问题，比如安装软件没有权限，可以将USER 10001命令放到这些命令之后；再比如，如果没有 root 权限，应用程序无法在 80 端口上运行，因此必须更改端口>1024。
>

## 2.5 UID>=10000

低于 10000 的 UID 在多个系统上都存在安全风险，因为如果有人设法在 Docker 容器外提升权限，他们的 Docker 容器 UID 可能会与权限更高的系统用户的 UID 重叠，从获取更高的权限。为了避免这种安全隐患，建议以高于 10000 的 UID 运行进程。

## 2.6 使用静态UID和GID

运行容器时，需要为容器所拥有的文件设置文件权限。如果镜像没有设置静态`UID/GID`，就必须从运行的容器中提取该信息，然后才能在主机上分配正确的文件权限。最好为所有镜像设置一个固定的静态`UID/GID`。建议使用 `10000:10001`，这样可以减少不必要的运维复杂度。



## 只在`CMD`中存储参数

> 如果 CMD 包含命令名称，在运行容器时就必须猜出命令名称，以便传递参数等。

将`ENTRYPOINT`作为命令名称：

```dockerfile
ENTRYPOINT ["/sbin/tini", "--", "myapp"]
```

而`CMD`只是命令的参数：

```dockerfile
CMD ["--foo", "5", "--bar=10"]
```

运行容器时参数传递的方式更人性化，而无需猜测其名称，例如
```bash
docker run IMAGE --some-argument
```


### 使用COPY代替ADD

> 使用 ADD 的唯一例外是 tar 自动提取功能
> `ADD local-file.tar.xz /usr/share/files`

禁止`ADD`指定URL，这样可能会导致`MITM`攻击或恶意数据源。此外，ADD会隐式解压本地压缩包，这可能会导致路径遍历和 [Zip Slip漏洞](https://snyk.io/research/zip-slip-vulnerability/)。

应避免这样做：

``````dockerfile
ADD https://example-url.com/file.tar.xz /usr/share/files
``````



### 使用多阶段构建

在使用 Dockerfile 构建应用程序时，会创建许多仅在构建时需要的工件。这些工件可以是编译所需的开发工具和库等软件包，也可以是运行单元测试所需的依赖项、临时文件、密钥等。

在基础镜像中保留这些人工制品（可能用于生产）会导致 Docker 镜像大小增大，这不仅会严重影响下载时间，还会因为安装了更多软件包而增加攻击面。您使用的 Docker 镜像也是如此--您可能需要特定的 Docker 镜像来构建，但不需要它来运行应用程序的代码。

Golang 就是一个很好的例子。要构建 Golang 应用程序，你需要 Go 编译器。编译器生成的可执行文件可以在任何操作系统上运行，无需依赖，包括从头镜像。

这也是 Docker 具有多阶段构建功能的一个很好的原因。该功能允许你在构建过程中使用多个临时镜像，只保留最新的镜像和你复制到其中的信息。这样，你就有了两个镜像：

第一个镜像--非常大的镜像，捆绑了许多依赖项，用于构建应用程序和运行测试。

第二个镜像--在大小和库数量方面都非常小的镜像，只有在生产中运行应用程序所需的工件副本。



## 3. 常见配置备忘

## 3.1 安装包

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


## 2.2 多阶段构建

# 3. Dockerfile示例
## 3.1 Alpine镜像
### 3.1.1 golang镜像

## 3.2 Ubuntu镜像
### 3.2.1 golang镜像

### 3.2.1 apt安装包和清理




# Reference

**[Docker官方文档-Dockerfile最佳实践](https://docs.docker.com/develop/develop-images/instructions/#run)**

**[10 Docker Image Security Best Practices](https://snyk.io/blog/10-docker-image-security-best-practices/)**

[10 best practices to build a Java container with Docker](https://snyk.io/blog/best-practices-to-build-java-containers-with-docker/)
[10 best practices to containerize Node.js web applications with Docker](https://snyk.io/blog/10-best-practices-to-containerize-nodejs-web-applications-with-docker/)



