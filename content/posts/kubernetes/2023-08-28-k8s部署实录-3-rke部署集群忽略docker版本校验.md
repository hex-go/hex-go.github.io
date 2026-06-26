---
title: k8s部署实录-3-rke部署集群忽略docker版本校验
categories:
  - Kubernetes
tags:
  - Kubernetes
  - RKE
date: 2023-08-28 00:00:00
top: false
comments: true
series:
  - k8s部署实录
---

# 重要

rke 默认校验 Docker 版本。`config.yml` 中的 `ignore_docker_version: true` 不生效，必须传 CLI 参数 `--ignore-docker-version`。

# 环境说明

- rke v1.2.6
- Kubernetes v1.19
- Docker CE v24.0.5（rke v1.2.6 兼容的 Docker 版本为 v1.13.x ~ v20.10.x）

## 1.简介

客户现场 Docker 为自行安装的 v24.0.5，与 rke v1.2.6 不兼容。开发环境只为调研，忽略版本校验继续安装。

## 2.说明

### 2.1 报错

```text
INFo[0000] [dialer] Setup tunnel for host [192.168.1.215]
WARN[0000] [state] can't fetch legacy cluster state from Kubernetes:
  Unsupported Docker version found [24.0.5] on host [192.168.1.227],
  supported versions are [1.13.x 17.03.x 17.06.x 17.09.x 18.06.x 18.09.x 19.03.x 20.10.x]
```

### 2.2 处理

| 方式 | 是否生效 |
|------|----------|
| `config.yml` 中 `ignore_docker_version: true` | 不生效 |
| rke CLI 参数 `--ignore-docker-version` | 生效 |

```yaml
rke up --ignore-docker-version
```

## 3.参考

- [Docker version not supported even with ignore_docker_version: true](https://github.com/rancher/rke/issues/3181)
