---
title: Minikube--增加外部dns解析
categories:
  - Kubernetes
tags:
  - Kubernetes
  - coredns
date: '2020-08-07 08:29:55'
top: false
comments: true
---

# 重要

# 原理说明
kubernetes集群并采用Coredns进行解析，集群内部的服务都能通过内部域名进行访问。但是集群内部的coredns与物理机的dns解析不完全统一，
coredns不能解析物理机的hostname。k8s-coredns默认配置从本机`/etc/resolv.conf`获取上游DNS服务器的地址。
有两种方式解决这个问题：
1. 搭建解析物理机地址的dns服务器，并作为上游dns服务配置给k8s的coredns。
2. 通过coredns自带的`hosts`插件，手动添加自定义解析记录

# 配置
## 1. 配置外部dns服务器
搭建coredns服务参考coredns官网，此处只介绍k8s中dns服务器修改上游dns配置，有两种方式：
1. 修改`/etc/resolv.conf`中的nameserver
> nameserver地址换成自建的dns服务地址，默认监听53端口。
```conf
nameserver 192.168.100.254
```
2. 修改coredns配置文件 ConfigMap `coredns`
```bash
kubectl -n kube-system edit configmap coredns
```

```yaml
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           upstream
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        proxy . 192.168.100.254 # 修改为上游dns服务地址,端口默认53
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
```


配置修改后，需要重启coredns服务
> 查询coredns 的POD
```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns
```
> 删除 coredns 让 k8s 重新创建新的 coredns
```bash
kubectl -n kube-system delete pod -l k8s-app=kube-dns
```

## 2. 通过hosts添加自定义DNS解析记录
`coredns` 自带 `hosts` 插件， 允许像配置 hosts 一样配置自定义 DNS 解析

修改命名空间 `kube-system` 下的 configMap `coredns` 
```bash
kubectl edit configmap coredns -n kube-system
```

添加如下设置即可。
```yaml
    hosts {
        172.21.91.28 cache.redis
        172.21.91.28 persistent.redis
          
        fallthrough
    }
```
修改后文件如下（根据kubernetes 安装方式不同，可能有些许差别）
```yaml
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           upstream
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        hosts {
        10.10.0.10 reg.chebai.org
        10.15.0.2 hub.icos.city
        fallthrough
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
```
删除命名空间`kube-system`下的coredns pod，重启dns服务。

## 3. 通过pod增加hostalias
以`deployment`修改举例
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      hostAliases:
      - ip: "192.168.100.106"
        hostnames:
        - "rancher.icos.city"
      containers:
      - env:
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        image: nginx
        name: nginx
```

# Reference
[开发服务器 k8s 设置 自定义 dns解析](https://blog.csdn.net/fenglailea/article/details/100577403)
[coredns 官网](https://coredns.io/)