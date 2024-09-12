---
title: 容器调试工具-cdebug
categories:
  - Kubernetes
tags:
  - Kubernetes
  - cdebug
date: '2024-09-10 09:16:33'
top: false
comments: true
---

## 问题

- 如何调试一个没有shell的容器
- 如何访问容器未export的端口
- 如何将容器内的文件导出

## 什么是cdebug

cdebug 是一个功能强大的容器调试工具。可以处理`Docker容器`、Kubernetes Pod，还是其他类型的容器，cdebug 都能给你提供所需的工具和便利。

Github 地址: https://github.com/iximiuz/cdebug

关键功能
- 调试 **无 Shell** 容器: 即使容器内没有 Shell 或调试工具，也能轻松进入并调试。
- 端口魔术师: 将未公开的端口或 localhost 端口转发到主机系统。
- 反向通道: 将主机系统的端点暴露给容器和 Kubernetes 网络。
- 文件系统导出专家: 轻松将镜像或容器的文件系统导出到本地文件夹。

## 安装cdebug

### 举例(linux-amd64)
```bash
GOOS=linux
GOARCH=amd64

curl -Ls https://github.com/iximiuz/cdebug/releases/latest/download/cdebug_${GOOS}_${GOARCH}.tar.gz | tar xvz

mv cdebug /usr/local/bin
```

## cdebug exec：调试"无 Shell" 容器
> `cdebug exec` = `docker exec` + `kubectl debug` 的完美结合。它能让你在目标容器中启动一个调试用的Sidecar容器，感觉像使用 `docker exec`，但功能更强:
> - 调试容器的根文件系统==目标容器的根文件系统；
> - 目标容器不会被重新创建或重启；
> - 无需额外的卷或复制调试工具；
> - 调试工具在目标容器中随时可用；

### 1. 调试rke2运行的k8s集群中，以static-pod形式运行的etcd容器

#### 1.1 调试方式选择

> cdebug调试K8S集群容器，是通过`K8S debug`实现的，但由于无法对StaticPod创建临时容器，下图为报错举例。
> - namespace指的是K8S集群中的命名空间
```bash
root@devops-k8s-master1:~# cdebug exec --namespace kube-system -it pod/etcd-devops-k8s-master1
Debugger container name: cdebug-e59ec365
Starting debugger container...
cdebug: Error adding debugger container: Pod "etcd-devops-k8s-master1" is invalid: []: Forbidden: static pods do not support ephemeral containers.
```
> 因此，需要采取**宿主机调试containerd容器**的方式

#### 1.2 环境信息
登录待调试容器所在宿主机，执行以下命令进行ctr客户端设置。如，rke2安装的k8s集群，master节点：

```bash
# 将工具复制到PATH目录下
cp /var/lib/rancher/rke2/bin/ctr /usr/local/bin/

# 向containerd的默认sock位置，创建一个软链接
ln -s  /run/k3s/containerd/containerd.sock /run/containerd/containerd.sock
```

#### 1.3 获取容器ID
> ctr

```bash
etcd_container_id=$(ctr -n k8s.io container ls |grep etcd |awk '{print $1}')
```

#### 1.4 运行调试容器
> -n,--namespace: 命名空间，会对应到相应的runtime，比如此处是containerd的命名空间
> --image: 进行debug的工具镜像，默认为`docker.io/library/busybox:musl`

```bash
cdebug exec -n k8s.io --image jenkins/busybox:musl -it --rm containerd://${etcd_container_id}
```


### 2. "无 Shell" 容器：运行在K8S集群，非StaticPod
> - NAMESPACE: 对应运行时的命名空间，此处为K8S集群中的命名空间
> - POD_NAME: 必填，Pod名称
> - CONTAINER_NAME：选填，容器名称，可指定特定的容器
```bash
cdebug exec -it <-n NAMESPACE> pod/{POD_NAME}/{CONTAINER_NAME}

# cdebug启动调试容器
cdebug exec -it -n kube-system --image jenkins/busybox:musl pod/rke2-coredns-rke2-coredns-84b9cb946c-47n5s
```

### 3. "无 Shell" 容器：运行在Dockerd
```bash
# 启动测试容器
docker run -d --rm \
  --name my-distroless gcr.io/distroless/nodejs \
  -e 'setTimeout(() => console.log("Done"), 99999999)'

# cdebug启动调试容器
cdebug exec -it my-distroless
```

### 4. "无 Shell" 容器：运行在Containerd

参考 `1. 调试rke2运行的k8s集群中，以static-pod形式运行的etcd容器`


## cdebug port-forward：端口转发

### 1. 未发布容器端口：将容器中的端口映射到宿主机本地端口

```bash
# 使用 cdebug 将本地 8080 端口转发到容器的 80 端口
cdebug port-forward {容器名称: nginx} -L 8080:80

# 可以通过宿主机8000端口，访问nginx容器的80端口
curl localhost:8080
```

### 2. 容器监听127.0.0.1：将宿主机本地端口映射到容器内的端口

```bash

docker run -d --name local-c python:3-alpine python3 -m 'http.server' -b 127.0.0.1 8888

# 使用 cdebug 将本地 8080 端口转发到容器的 80 端口
cdebug port-forward {容器名称: local-c} -L 127.0.0.1:8888
# 返回信息
# ...
# Forwarding 127.0.0.1:49176 to 127.0.0.1:8888 through 172.17.0.4:34128
# 从上面信息可知，通过宿主机49176端口可访问该容器内服务
curl localhost:49176
```