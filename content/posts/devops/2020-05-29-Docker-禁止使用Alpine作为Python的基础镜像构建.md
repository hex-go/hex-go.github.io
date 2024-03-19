---
title: 禁止使用Alpine作为Python的基础镜像构建
categories:
  - Devops
tags:
  - Devops
  - Docker
  - Dockerfile
date: '2020-05-29 09:36:32'
top: false

comments: true
description : "Alpine 会使 Python Docker 构建速度降低50倍,还可能会触发不可预料的运行时错误。禁止使用Alpine作为Python的基础镜像构建"
---

## 重要

在为 Docker 镜像选择基础镜像时，通常会推荐使用 Alpine Linux。使用 Alpine 会让镜像体积更小，并加快构建速度。如果编程语言是Go，这个是合理的。

但如果编程语言是Python，Alpine Linux会带来以下问题：

- 构建速度变的特别慢。
- 让docker镜像变大。
- 偶尔会引入一些不起眼的运行时错误。

## Alpine的优点
> 大多数情况下Alpine具备构建时间短，镜像小的优点，被广泛推荐使用。

下面测试Alpine作为基础镜像的优点。假设需要安装 gcc 作为镜像构建的一部分，对比`Alpine Linux`与`Ubuntu 18.04`在构建时间和镜像大小方面的区别。

首先，拉取两个镜像，并检查它们的大小：
```bash
$ docker pull --quiet ubuntu:18.04
docker.io/library/ubuntu:18.04
$ docker pull --quiet alpine
docker.io/library/alpine:latest
$ docker image ls ubuntu:18.04
REPOSITORY          TAG        IMAGE ID         SIZE
ubuntu              18.04      ccc6e87d482b     64.2MB
$ docker image ls alpine
REPOSITORY          TAG        IMAGE ID         SIZE
alpine              latest     e7d92cdc71fe     5.59MB
```
可以看出来，`Alpine Linux`基础镜像小得多。

接下来，在Ubuntu系统中安装gcc：
```dockerfile
FROM ubuntu:18.04
RUN apt-get update && \
    apt-get install --no-install-recommends -y gcc && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
```
构建命令（使用time计时）
```bash
$ time docker build -t ubuntu-gcc -f Dockerfile.ubuntu --quiet .
sha256:b6a3ee33acb83148cd273b0098f4c7eed01a82f47eeb8f5bec775c26d4fe4aae

real    0m29.251s
user    0m0.032s
sys     0m0.026s
$ docker image ls ubuntu-gcc
REPOSITORY   TAG      IMAGE ID      CREATED         SIZE
ubuntu-gcc   latest   b6a3ee33acb8  9 seconds ago   150MB
```

然后，在Alpine系统中安装gcc：
```dockerfile
FROM alpine
RUN apk add --update gcc
```
构建命令（使用time计时）
```bash
$ time docker build -t alpine-gcc -f Dockerfile.alpine --quiet .
sha256:efd626923c1478ccde67db28911ef90799710e5b8125cf4ebb2b2ca200ae1ac3

real    0m15.461s
user    0m0.026s
sys     0m0.024s
$ docker image ls alpine-gcc
REPOSITORY   TAG      IMAGE ID       CREATED         SIZE
alpine-gcc   latest   efd626923c14   7 seconds ago   105MB
```

|        | 构建时间 | 镜像大小  |
|--------|------|-------|
| Alpine | 15s  | 105MB |
| Ubuntu | 30s  | 150MB |


总结，Alpine镜像的生成速度更快，体积更小。

## Alpine不适合Python
以使用`pandas`和`matplotlib`的Python应用程序举例。

基于`Debian`的Python官方镜像（python:3.8-slim），并使用以下 Dockerfile：
```dockerfile
FROM python:3.8-slim
RUN pip install --no-cache-dir matplotlib pandas
```
构建命令与输出为
```bash
$ docker build -f Dockerfile.slim -t python-matpan.
Sending build context to Docker daemon  3.072kB
Step 1/2 : FROM python:3.8-slim
 ---> 036ea1506a85
Step 2/2 : RUN pip install --no-cache-dir matplotlib pandas
 ---> Running in 13739b2a0917
Collecting matplotlib
  Downloading matplotlib-3.1.2-cp38-cp38-manylinux1_x86_64.whl (13.1 MB)
Collecting pandas
  Downloading pandas-0.25.3-cp38-cp38-manylinux1_x86_64.whl (10.4 MB)
...
Successfully built b98b5dc06690
Successfully tagged python-matpan:latest

real    0m30.297s
user    0m0.043s
sys     0m0.020s
```

基于Alpine镜像，使用以下Dockerfile:
```dockerfile
FROM python:3.8-alpine
RUN pip install --no-cache-dir matplotlib pandas
```
构建命令与输出
```bash
$ docker build -t python-matpan-alpine -f Dockerfile.alpine .                                 
Sending build context to Docker daemon  3.072kB                                               
Step 1/2 : FROM python:3.8-alpine                                                             
 ---> a0ee0c90a0db                                                                            
Step 2/2 : RUN pip install --no-cache-dir matplotlib pandas                                                  
 ---> Running in 6740adad3729                                                                 
Collecting matplotlib                                                                         
  Downloading matplotlib-3.1.2.tar.gz (40.9 MB)                                               
    ERROR: Command errored out with exit status 1:                                            
     command: /usr/local/bin/python -c 'import sys, setuptools, tokenize; sys.argv[0] = '"'"'/
tmp/pip-install-a3olrixa/matplotlib/setup.py'"'"'; __file__='"'"'/tmp/pip-install-a3olrixa/matplotlib/setup.py'"'"';f=getattr(tokenize, '"'"'open'"'"', open)(__file__);code=f.read().replace('"'"'\r\n'"'"', '"'"'\n'"'"');f.close();exec(compile(code, __file__, '"'"'exec'"'"'))' egg_info --egg-base /tmp/pip-install-a3olrixa/matplotlib/pip-egg-info                              

...
ERROR: Command errored out with exit status 1: python setup.py egg_info Check the logs for full command output.
The command '/bin/sh -c pip install matplotlib pandas' returned a non-zero code: 1
```

因为 **标准PyPI wheels 无法在 Alpine 上运行**

对比上面两次构建的日志输出，会发现不同： 
  基于 Debian 的构建，下载的是`matplotlib-3.1.2-cp38-cp38-manylinux1_x86_64.whl`。这是一个预编译的二进制文件。相比之下，Alpine 下载的是源代码包`matplotlib-3.1.2.tar.gz`，因为标准的 Linux wheel文件无法在`Alpine Linux`上运行。

大多数 Linux 发行版都使用`GNU 版本`（glibc）的标准C库，几乎所有C程序（包括 Python）都依赖glibc。但`Alpine Linux`使用的是`musl`，而python预编译的`*.whl`文件是针对`glibc`编译的，因此 Alpine 禁用了对 Linux wheel的支持。

然而，大多数Python软件包都在PyPI上包含了`*whl`预编译文件，来大大加快了安装时间。但使用`Alpine Linux`，就需要编译每个 Python 软件包中的所有 C 代码。

这也意味着,需要自己找出每一个系统库的依赖关系。在这种情况下，根据依赖关系跟新`Dockerfile`如下：

```dockerfile
FROM python:3.8-alpine
RUN apk --update add gcc build-base freetype-dev libpng-dev openblas-dev
RUN pip install --no-cache-dir matplotlib pandas
```

### Alpine Linux 可导致难以预料的运行时错误
虽然从理论上讲，Alpine 使用的`musl` C库与其他 Linux 发行版使用的`glibc`基本兼容，但在实践中，两者之间的差异可能会导致问题。而且，一旦出现问题，这些问题会非常奇怪，出乎意料。

举几个例子：

- musl 不支持 DNS over TCP，这意味着[某些DNS配置（如 Kubernetes 中的配置）可能会导致DNS查询失败](https://martinheinz.dev/blog/92)。
- Alpine 的线程默认堆栈大小较小，这[可能导致Python程序崩溃](https://bugs.python.org/issue32307)。
- 由于 musl 分配内存的方式与 glibc 截然不同，[导致Python程序速度慢了很多](https://superuser.com/questions/1219609/why-is-the-alpine-docker-image-over-50-slower-than-the-ubuntu-image)。
- [还有时间格式化和解析方面的问题](https://github.com/iron-io/dockers/issues/42#issuecomment-290763088)。

这些问题的大部分或全部都已得到修复，但无疑还有更多问题有待发现。这种兼容性带来的不确定性太可怕。


Alpine与Ubuntu作为基础镜像的对比如下

| 基础镜像              | 构建时间  | 镜像大小  | 是否存在其他问题 |
|-------------------|-------|-------|----------|
| python:3.8-slim	  | 30s   | 363MB | 否        |
| python:3.8-alpine | 1557s | 851MB | 	是       |

Alpine的构建速度要慢得多，镜像体积也更大，而且必须做大量的研究。

## 是否能解决

### 关于构建速度

Alpine Edge（最终将成为下一个稳定版本）拥有 matplotlib 和 pandas，可以加快构建速度。安装系统包的速度也相当快。不过，截至 2020 年 1 月，当前的稳定版本并不包含这些流行软件包。

不过，即使这些包可用，系统包也几乎总是落后于 PyPI 上的包，而且 Alpine 也不太可能把 PyPI 上的所有包都打包。实际上，所知的大多数 Python 团队都不使用系统包，而是依赖 PyPI 或 Conda Forge。

### 关于镜像大小
可以通过删除最初安装的软件包，或添加不缓存软件包下载的选项，或使用多阶段构建的方法减小镜像大小，但镜像大小也在470MB。与基于`python:3.8-slim`的镜像大小差不多。但 Alpine Linux 的目的是更小的镜像和更快的构建速度。也许可以通过足够的努力获得更小的镜像，但仍然要忍受 1500 秒的构建时间，而使用 python:3.8-slim 镜像只需 30 秒。

### 运行时错误

未知的不确定性，遇到一个解决一个

## 总结

由于Alpine发行版默认c库(musl)与python预编译文件(*.whl)所依赖的c库(glibc)不同，如果python使用Alpine基础镜像，就无法使用PyPI库中已编译的wheel文件，只能下载源码包重新编译。 从而导致构建时间长，镜像体积大，兼容性带来不确定的运行时错误。因此不建议使用Alpine作为Python的基础镜像构建。


# Reference

[Using Alpine can make Python Docker builds 50× slower](https://pythonspeed.com/articles/alpine-docker-python/)
