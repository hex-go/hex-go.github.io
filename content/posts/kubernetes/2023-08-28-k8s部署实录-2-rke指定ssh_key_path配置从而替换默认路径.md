---
title: k8s部署实录-2-rke指定ssh_key_path替换默认密钥路径
categories:
  - Kubernetes
tags:
  - Kubernetes
date: 2023-08-28 00:00:00
top: false
comments: true
series:
  - k8s部署实录
---

# 重要

rke 默认读取 `~/.ssh/id_rsa`。如果 SSH 密钥使用 ed25519 等非 RSA 算法生成，需要在 `cluster.yaml` 中指定 `ssh_key_path`。

# 环境说明

- rke v1.2.6
- SSH 密钥算法：ed25519（客户安全要求，私钥路径 `~/.ssh/id_ed25519`）

## 1.简介

客户出于安全考虑使用 ed25519 生成 SSH 密钥。执行 `rke up` 时报 `id_rsa` 文件不存在，所有节点连接失败。

## 2.说明

### 2.1 报错

```text
WARN[0000] Failed to set up SSH tunneling for host [10.0.0.1]:
  Can't establish dialer connection: Error while reading SSH key file:
  open /root/.ssh/id_rsa: no such file or directory
WARN[0000] Removing host [10.0.0.1] from node lists
FATA[0000] Cluster must have at least one etcd plane host
```

rke 在 `~/.ssh/` 下依次查找 `id_rsa` → `id_dsa` → `id_ecdsa` → `id_ed25519`。但**不会自动**探测 ed25519 密钥。

### 2.2 处理

在 `cluster.yaml` 中配置 `ssh_key_path`。

| 级别 | 配置位置 | 生效范围 |
|------|----------|----------|
| 集群级别 | `cluster.yaml` 顶层 | 所有节点 |
| 节点级别 | 每个 `nodes[]` 条目内 | 单个节点 |

节点级别优先级高于集群级别。

集群级别：

```yaml
cluster_name: mycluster
ssh_key_path: ~/.ssh/id_ed25519
nodes:
  - address: 10.0.0.1
    user: ubuntu
    role: [controlplane, etcd, worker]
```

节点级别：

```yaml
nodes:
  - address: 10.0.0.1
    user: ubuntu
    role: [controlplane, etcd, worker]
    ssh_key_path: ~/.ssh/id_ed25519
```

## 3.参考

- [RKE 配置参数 - ssh_key_path](https://rke.docs.rancher.com/config-options#cluster-level-ssh-key-path)
- [RKE full cluster.yml 示例](https://rke.docs.rancher.com/example-yamls#full-clusteryml-example)
