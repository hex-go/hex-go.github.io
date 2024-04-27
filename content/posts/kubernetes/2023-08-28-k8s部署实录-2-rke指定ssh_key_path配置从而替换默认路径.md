---
title: k8s部署实录-2-rke指定ssh_key_path配置从而替换默认路径
categories:
  - Kubernetes
tags:
  - Kubernetes
  - RKE
date: '2023-08-28 20:28:18'
top: false
comments: true
series:
  - k8s部署实录
---

# 重要
- 前因：
免密是由客户进行操作，出于安全的考虑，生成ssh-key-gen时选用的加密算法为`ed25519`, 而非默认的`rsa`, 从而生成的私钥文件目录为`~/.ssh/id_ed25519`

- 现状：
执行`rke up`命令，报错 `~/.ssh/id_rsa` 文件不存在，集群安装失败。
```text
INFO[0000] Building Kubernetes cluster
INFO[0000] [dialer] Setup tunnel for host [10.0.0.1]
WARN[0000] Failed to set up SSH tunneling for host [10.0.0.1]: Can’t establish dialer connection: Error while reading SSH key file: open /root/.ssh/id_rsa: no such file or directory
INFO[0000] [dialer] Setup tunnel for host [10.0.0.2]
WARN[0000] Failed to set up SSH tunneling for host [10.0.0.2]: Can’t establish dialer connection: Error while reading SSH key file: open /root/.ssh/id_rsa: no such file or directory
INFO[0000] [dialer] Setup tunnel for host [10.0.0.3]
WARN[0000] Failed to set up SSH tunneling for host [10.0.0.3]: Can’t establish dialer connection: Error while reading SSH key file: open /root/.ssh/id_rsa: no such file or directory
WARN[0000] Removing host [10.0.0.1] from node lists
WARN[0000] Removing host [10.0.0.2] from node lists
WARN[0000] Removing host [10.0.0.3] from node lists
FATA[0000] Cluster must have at least one etcd plane host: failed to connect to the following etcd host(s) [10.0.0.1]
```

- 原因分析：
配置ssh免密时，使用的key为`ed25519`加密算法生成的，而rke工具从操作机寻找文件`~/.ssh/id_rsa`，从而检查ssh免密，需要查找rke官方配置，从而指定ssh key的路径，替换默认值

- 处理方案：

修改配置文件`cluster.yaml`
```yaml
ssh_key_path: ~/.ssh/id_ed25519
```
> 如果在群集级别和节点级别都定义了`ssh_key_path`，则节点级别的密钥优先。

集群级别设置：
```yaml
cluster_name: mycluster
ssh_key_path: ~/.ssh/id_ed25519
nodes:
```
节点级别设置：
```yaml
cluster_name: mycluster
nodes:
  - address: 1.1.1.1
    user: ubuntu
    role:
      - controlplane
      - etcd
      - worker
    ssh_key_path: ~/.ssh/id_ed25519
  - address: 1.1.1.2
    user: ubuntu
    role:
      - controlplane
      - etcd
      - worker
    ssh_key_path: ~/.ssh/id_ed25519
```

# Reference
[RKE配置参数-ssh_key_path](https://rke.docs.rancher.com/config-options#cluster-level-ssh-key-path)

[RKE配制文件-full-example](https://rke.docs.rancher.com/example-yamls#full-clusteryml-example)