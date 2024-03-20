---
title: 2020-06-28-K8S容器进程以root运行带来的安全隐患及解决
categories:
  - Kubernetes
tags:
  - Kubernetes
date: '2020-06-28 09:36:19'
top: false
comments: true

description: 容器中的进程默认以 root 用户权限运行，Docker默认不启用user namespace, 所有的容器共用一个内核，所以内核控制的 uid 和 gid 则仍然只有一套。如果容器内使用root用户，则容器内的进程与宿主机的root具有相同权限。会有很大的安全隐患，一旦容器有权限访问宿主机资源，则将具备宿主机root相同权限。
---

## 问题 
容器中的进程默认以 root 用户权限运行，如果k8s集群中的容器进程也以root用户运行，会存在容器提权获取节点主机权限的风险。一旦容器有权限访问所在节点资源，则带来巨大的安全隐患。[安全漏洞 CVE-2019-11245 ](https://nvd.nist.gov/vuln/detail/CVE-2019-11245)

## 解决办法

+ 1. 为容器中的进程指定一个具有合适权限的用户，而不要使用默认的 root 用户。
+ 2. 应用Linux的user namespace技术，配置 docker 开启 user namespace 隔离用户。

由于docker user-namespace种种限制而让其它的个别功能出现问题，推荐第一种解决方案，本文也重点介绍

## 配置合适的用户
因此，首先需要在镜像中添加一个合适权限的用户；之后需要在k8s-pod中通过security-context中指定通过此用户运行容器。

注意两点：
1. 用户必须指定UID, 因为k8s通过uid非0来确定是否为非root启动，当runAsNonRoot设置为true时，必须指定数字类型UID。
2. 用户ID建议>=10000,以避免避与节点普通用户的常用范围冲突。
   低于10000的UID在多个系统上都存在安全风险，因为如果有人设法在Docker容器外提升权限，Docker容器UID可能会与权限更高的系统用户的UID重叠，从而获取更高的权限。为了避免这种安全隐患，建议以高于10000的UID运行进程。

### 在`Dockerfile` 中指定用户身份

可参考[dockerfile的最佳实践]({{< ref "/posts/devops/2020-05-29-Docker-dockerfile的最佳实践" >}})

```dockerfile
RUN addgroup -S paas && \
    adduser paas -u 10000 -S paas -G paas && \
    su paas -s /bin/sh -c "mkdir -p /home/paas/config" && \
    su paas -s /bin/sh -c "mkdir -p /home/paas/data"
USER 10000
```

### 在 `Pod Security Policies` 中指定用户身份

```yaml
# deployment 举例
spec:
  template:
    spec:
      containers:
        securityContext:
          runAsUser: 10001                
```

> `Pod Security Policies`中的配置优先级更高，可以覆盖`Dockerfile`中的参数。

## 带来的问题以及解决方案

### 1. 权限不足，导致服务无法监听在80端口
> 在大多数操作系统中，监听`<1024`的低端口需要特殊权限。这些端口通常用于一些系统服务或者敏感服务，比如 HTTP（80端口）、HTTPS（443端口）、SSH（22端口）、FTP（21端口）等。

改变容器监听端口（>1024），将服务的监听端口通过Service资源设置。例如容器监听端口设置为8080，服务端口设置为80。

### 2. 构建镜像时，提示权限不足

将`USER 10000`命令放到包安装等特权命令之后， 此命令执行后的构建操作，才会以uid=10000的用户执行。

### 3. 开源中间件镜像如何处理
SecurityContext中指定的uid必须实际存在于容器中。 而很多开源中间件镜像已经被配置为以 root 身份运行。因此必须重新构建镜像，并在镜像中创建非root用户。常见方案有两种：

- 以开源中间件镜像为基础镜像，再在之后运行创建用户的构建命令。
- 选择`Bitnami`等公司已重新打包·构建过的镜像（推荐）。

## 相关概念

### Linux中的UID/GID

uid: 范围为0~65535（Ubuntu中为65533），0~999留给系统用户，普通用户为1000~65533. 

进程如果不声明uid，启动时以登录用户uid启动进程；进程可以声明任一存在或不存在的uid启动进程。
创建用户时若不指定uid, 默认就是直接从已存在的uid中找到最大的那个加1。

综上，
+ 每个uid不一定有对应的用户名
+ 每个用户一定有自己的uid
+ 每个进程必定有uid
+ 进程uid不指定，则与启动命令的用户uid一致
+ 创建用户uid不指定，则每多一个用户，uid会max+1递增。

### 容器中的UID/GID
容器中的进程默认以 root 用户权限运行，Docker默认不启用user namespace, 所有的容器共用一个内核，所以内核控制的 uid 和 gid 则仍然只有一套。

如果容器内使用root用户，则容器内的进程与宿主机的root具有相同权限。会有很大的安全隐患，一旦容器有权限访问宿主机资源，则将具备宿主机root相同权限。

具体容器中的原理可参考[官方文档](#docker官网-linux内核功能)


# Reference

[Ubuntu下的用户权限](https://blog.csdn.net/u012668018/article/details/37727517)

## [Docker官网-Linux内核功能](https://docs.docker.com/engine/security/#linux-kernel-capabilities)

[理解 docker 容器中的 uid 和 gid](https://www.cnblogs.com/sparkdev/p/9614164.html)

[隔离 docker 容器中的用户](https://www.cnblogs.com/sparkdev/p/9614326.html)

[为pod设置权限和AccessControl](https://medium.com/kubernetes-tutorials/defining-privileges-and-access-control-settings-for-pods-and-containers-in-kubernetes-2cef08fc62b7)
