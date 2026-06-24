---
title: Kubernetes 集群中以非 root 启动容器
categories:
  - Kubernetes
tags:
  - Kubernetes
  - Security
date: '2020-06-28 09:36:19'
top: false
comments: true
---

# 重要

容器默认以 root 运行，与宿主机 root 共享同一 UID 空间。一旦容器可访问宿主机资源，等同于宿主机 root 权限。

## 1. 问题

[安全漏洞 CVE-2019-11245](https://nvd.nist.gov/vuln/detail/CVE-2019-11245)：容器以 root 运行时，存在提权获取节点主机权限的风险。

## 2. 处理

两种方案：

| 方案 | 推荐度 |
|------|--------|
| 为容器指定非 root 用户运行 | 推荐——简单可靠 |
| 开启 Docker user namespace 隔离 | 不推荐——与部分功能冲突 |

## 3. 配置非 root 用户

### 3.1 Dockerfile

用户必须指定 UID（K8s 通过 UID ≠ 0 判断非 root），建议 >= 10000 避免与节点普通用户冲突。

```dockerfile
RUN addgroup -S paas && \
    adduser paas -u 10000 -S paas -G paas
USER 10000
```

将 `USER` 放在包安装等特权命令之后。

### 3.2 Pod Security Context

```yaml
spec:
  containers:
    - securityContext:
        runAsUser: 10000
        runAsNonRoot: true
```

Pod Security Context 的优先级高于 Dockerfile 中的 `USER`。

## 4. 常见问题

| 问题 | 处理 |
|------|------|
| 80 端口权限不足 | 容器监听 >1024 端口，通过 Service 映射 |
| 构建镜像时权限不足 | `USER` 放在构建命令之后 |
| 开源中间件镜像是 root | 重新构建 + 创建用户；或使用 [Bitnami](https://bitnami.com) 已重打包的镜像 |

## 5. UID/GID 事实

| 事实 | 说明 |
|------|------|
| 每个 UID 不一定有对应用户名 | 容器内 `USER 10000` 不会创建 `/etc/passwd` 条目 |
| 每个用户名一定有 UID | — |
| 每个进程一定有 UID | 不指定则继承启动用户 |
| 创建用户不指定 UID | max(uid) + 1 |
| Docker 不启用 user namespace | 容器与宿主机共享 UID 空间——容器内 root == 宿主机 root |

## 参考

- [Docker 内核安全能力](https://docs.docker.com/engine/security/#linux-kernel-capabilities)
- [理解 Docker 容器中的 UID 和 GID](https://www.cnblogs.com/sparkdev/p/9614164.html)
