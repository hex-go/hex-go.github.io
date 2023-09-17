---
title: k8s部署实录-3-rke部署集群忽略docker版本校验
categories:
  - Kubernetes
  - RKE
tags:
  - Kubernetes
date: '2023-08-28 21:15:10'
top: false
comments: true
series:
  - k8s部署实录
---

# 重要
- 前因：
由于客户现场不给root权限，docker-ce为客户自行安装，版本为24.0.5, 与准备的安装包不兼容（rke版本为`v1.2.6`, k8s版本为`v1.19`,兼容的docker版本为`v1.13.x - v20.10.x`）
报错信息如下：
```text
INFo[0000] [dialer] Setup tunnel for host [192.168.1.215]
INFo[0000] [dialer] Setup tunnel for host [192.168.1.228]
WARN[0000] [state] can't fetch legacy cluster state from Kubernetes: Unsupported Docker version found [24.0.5] on host [192.168.1.227], supported versions are [1.13.x 17.03.x 17.06.x 17.09.x 18.06.x 18.09.x 19.03.x 20.10.x]
INFO[0000] [certificates] Generating CA kubernetes certificates
INFO[0000] [certificates] Generating Kubernetes API server aggregation layer requestheader client CA certificates
```

- 现状：
rke up默认校验docker版本，docker-ce v24.0.5版本与rke-v1.2.6不兼容，导致安装失败

- 原因分析：
由于本身为开发环境部署，只为调研。打算将rke的docker版本校验忽略，继续安装

- 处理方案：

> `config.yml`文件中的`ignore_docker_version: true`配置无效，rke的参数`--ignore-docker-version`有效
```yaml
rke up --ignore-docker-version
```

# Reference
[Docker version not supported even with ignore_docker_version: true](https://github.com/rancher/rke/issues/3181)