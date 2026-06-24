---
title: Registry 部署至 K8s 集群并使用
categories:
  - Persistence
tags:
  - Persistence
  - Registry
  - Kubernetes
date: '2021-01-22 10:13:28'
top: false
comments: true
---

# 重要

nuclio 平台需要一个带认证的内部镜像仓库：构建时提供 base-image，存储 function 构建产物。使用 Helm 部署 `docker-registry` chart，配置 htpasswd 认证。

## 1. 背景

nuclio 部署依赖两个功能：

1. 构建时提供 build-base-image
2. 存储 function 构建后的结果镜像

需要部署带认证的 Registry 并推送基础依赖镜像。

## 2. 部署

### 2.1 参数

| 变量 | 说明 |
|------|------|
| `secrets.htpasswd` | 认证密码（htpasswd 格式） |

### 2.2 生成认证密码

```bash
docker run --entrypoint htpasswd registry:2 -Bbn icos 123456
```

将输出粘贴到 `values.yaml` 的 `secrets.htpasswd`。

### 2.3 安装

```bash
kubectl create ns nuclio
helm install prebaked-registry ./prebaked-registry/ -n nuclio
```

### 2.4 创建 Docker Registry Secret

```bash
read -s mypassword
kubectl -n nuclio create secret docker-registry registry-credentials \
  --docker-username icos \
  --docker-password $mypassword \
  --docker-server prebaked-registry.nuclio:5000 \
  --docker-email admin@example.com
unset mypassword
```

## 3. 使用

Kaniko / Buildpacks 构建时引用该 Secret：

```yaml
imagePullSecrets:
  - name: registry-credentials
```

## 参考

- [在 K8s 中部署 Registry](https://www.nearform.com/blog/how-to-run-a-public-docker-registry-in-kubernetes/)
