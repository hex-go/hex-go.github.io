---
title: 跨级群DNS方案-解析各集群ingress与custom-dns记录
categories:
  - Kubernetes
tags:
  - Kubernetes
date: '2021-11-08 02:36:40'
top: false
comments: true
---

# 重要

![image](https://tva2.sinaimg.cn/large/006hT4w1ly1gw8ppmvt2jj31280t6gwd.jpg)

# 环境说明

部署的external-dns包括以下组件:

- external-dns: k3s集群内部，kube-system命名空间 [下载](/images/charts/dns/external-dns.yaml)
- etcd        : k3s集群内部，paas命名空间        [下载](/images/charts/dns/etcd.tar.gz)
- coredns     : k3s集群内部，paas命名空间        [下载](/images/charts/dns/coredns-1.16.0.tgz)

external-dns 可以将`ingress`和`external-service`对象存储至etcd中，CoreDNS使用此etcd作为后端，解析所注册的服务。

例如它解决了 registry，openldap、cassandra(headless) 、keycloak(loadbalancer) 这些服务的域名注册问题。

external-dns可以通过设置coredns前缀,同时为不通的域名提供解析服务.

## 部署

### 1. 部署 etcd

#### 1.1 边缘使用`local storage`部署

1. 在运行etcd的节点创建本地目录
```bash
mkdir "/opt/etcd-dns"
```

2. 创建pv
> pv创建修改详情，参考`etcd/chart/etcd-pv/README.md`
```bash
kubectl apply -f etcd/chart/etcd-pv/pv.yaml 
```

3. 部署etcd
> auth.rbac.enabled 设置为false, 不启用认证
> service.type      设置为 LoadBalancer
> service.loadBalancerIP   设置为"192.168.83.10"
> persistence.enable       设置为 true
> persistence.storageClass 设置为 paas-storage , 值与上一步创建pv时的sc一致
> persistence.size         设置为 8Gi , 值与上一步创建的pv大小一致
```bash
helm install etcd etcd/chart/etcd -n paas
```

4. 检测是否组成集群
```bash
etcdctl endpoint status --cluster -w table
```

### 2. 部署coredns

#### 2.1 部署


1. chart配置说明

部署配置：
> service.loadBalancerIP  设置dns服务的loadBalanceIP, 默认为 "192.168.83.5"

corefile相关配置：
```yaml
servers:
- zones:
  - zone: .
  port: 53
  plugins:
  # bugsize 由默认 512 设置为 1232 (loadBalance 只能代理TCP或UDP一种，此处coredns设置为UDP. 
  # 为防止大数据记录数据超过512，走TCP协议,故将默认大小调大)
  - name: bufsize
    parameters: 1232
  - name: errors
  # health 会启动一个监听 :8080/health 的服务 , 此chart中的 livenessProbe 检查此端口
  - name: health
    configBlock: |-
      lameduck 5s
  # ready 会启动一个监听 :8181/ready 的服务 , 此chart中的 readinessProbe 检查此端口
  - name: ready
  # 
  # prometheus 会启动一个监听 :9153/metrics 的服务 , 此chart中的 serviceMonitor 检查此端口
  - name: prometheus
    parameters: 0.0.0.0:9153
  # 转发，配置上游DNS地址
  - name: forward
    parameters: . 114.114.114.114
  - name: log
  # 自定义 zone 配置，需要与下面 zonefile 对应
  - name: file
    parameters: /etc/coredns/example.db deploy.org

# adp租户 zone 配置，
# 1. 设置 bufsize; 2. path 设置 /edge 取决与external-dns启动的设置，如果多个external-dns，则通过此处区分
# 2. endpoint 设置的地址为ETCD的LoadBalance IP和端口号
- zones:
    - zone: adp.icos.city
  port: 53
  bufsize: 1232
  plugins:
    - name: errors
    - name: log
    - name: etcd
      configBlock: |-
        path /edge
        endpoint http://192.168.83.10:2379
```

自定义zone配置
```yaml
zoneFiles:
  - filename: example.db
    domain: deploy.org
    contents: |
      deploy.org.         IN  SOA  ns.deploy.org. root.deploy.org. 2015082541 7200 3600 1209600 3600
      deploy.org.         IN  NS   ns.deploy.org.
      license.deploy.org. IN  TXT  "QClDmn9IdX50gDN59UXNpb4oR733jsk05zLuCAkj0="
```

2. 部署
```bash
helm install coredns coredns/chart/coredns -n paas
```

### 3. 部署external-dns

Deployment中的配置
> spec.template.spec.containers.[0].args   
> `--coredns-prefix=/edge/`参数决定数据存储在etcd的目录前缀，此处不同可区分不同集群内的external-dns;
> 而集群内部不同租户的服务，通过ingress中的租户名可以区分开

部署
~~~bash
kubectl apply -f external-dns.yaml
~~~

### 禁用节点DNS缓存
所有节点执行一下操作，注意IP地址设置正确
```bash
systemctl disable systemd-resolved
systemctl stop systemd-resolved

echo '
network:
  bonds:
    bond0:
      addresses:
      - 192.168.82.11/23
      gateway4: 192.168.82.1
      interfaces:
      - ens3f0
      - ens3f1
      nameservers:
        addresses:
        - 192.168.83.5
        search: []  
      parameters:
        mode: balance-rr
  ethernets:
    ens3f0: {}
    ens3f1: {}
  version: 2' > /etc/netplan/01-netcfg.yaml

rm -rf /etc/resolv.conf
echo "nameserver 192.168.83.5" > /etc/resolv.conf

netplan apply
```

## 常用修改说明

### license配置DNS-TXT记录说明
1. 在zone为`.`的域的plugins参数增加name为file的参数，值为`/etc/coredns/example.db deploy.org`
```yaml
servers:
- zones:
    - zone: .
  port: 53
  plugins:
  - name: file
    parameters: /etc/coredns/example.db deploy.org
```
2. 在zoneFiles增加如下配置，`license.deploy.org. IN  TXT`行的值为从QA获取的由私钥签名过的ou名Signature
```yaml
zoneFiles:
  - filename: example.db
    domain: deploy.org
    contents: |
      deploy.org.         IN  SOA  ns.deploy.org. root.deploy.org. 2015082541 7200 3600 1209600 3600
      deploy.org.         IN  NS   ns.deploy.org.
      license.deploy.org. IN  TXT  "QCUEsCx70xK2u9pdrm6y0hf4up8C9S44tvekF9LVODBPHbryRQGqh9dUyb8VcN11IlPXcl7hVdqC3qsIgYUo5/KBdNCX+edFYquOeKEyEfnkHRzoi8hjR6NIzOQoHh518EJClDmn9IdX50gDN59UXNpb4oR733jsk05zLuCAkj0="

```

## 冒烟测试

- 集群中创建external-svc

```bash
echo '
apiVersion: v1
kind: Service
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: reg.chebai.org
  name: reg-chebai-org
  namespace: paas
spec:
  externalName: 10.90.0.11
  type: ExternalName' > test-svc.yaml
kubectl apply -f test-svc.yaml
```

- 检查 ETCD 中是否有正确写入的数据

```bash
etcdctl --prefix --keys-only=true get /
# etcdctl --user="root" --password="OH4dQD4Cww" --prefix --keys-only=true get /
```

- 检查各个节点的测试数据域名解析

> 1.如果etcd中能查询到数据，但解析出错；则检查CoreDNS是否配置域adp.icos.city
> 2.注意仔细看存储路径的prefix, 是否与CoreDNS中配置的保持一致

```bash
nslookup reg.chebai.org <NODEIP>
```

或

```bash
dig @192.168.83.5 reg.chebai.org
```




# Reference
- DNS相关

[DNS之BIND使用小结(Forward转发)](https://www.cnblogs.com/kevingrace/p/9359989.html)

[Linux系统解析域名的先后顺序files(/etc/hosts)OR dns(/etc/resolv.conf)](https://www.cnblogs.com/emilyyoucan/articles/8118173.html)

[resolv.conf(5) — Linux manual page](https://man7.org/linux/man-pages/man5/resolv.conf.5.html)

[/etc/resolv.conf 中的第二个nameserver未被 wget 拾取](https://serverfault.com/questions/398837/second-nameserver-in-etc-resolv-conf-not-picked-up-by-wget)