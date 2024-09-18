---
title: "K8s网络CNI-Canal详细说明"
categories:
  - Kubernetes
tags:
  - Canal
  - Kubernetes
date: '2023-09-02 20:19:12'
series:
  - k8s网络CNI
---
Canal 完美保持Flannel原生的三种模式，扩展支持Calico的BGP、IPIP模式。并且支持网络策略。

Canal 表示使用`Flannel`通过`VXLAN`处理主机间的`pod`流量，使用`Calico`处理同一主机内的`pod`流量和网络策略。

> Canal项目可以理解为**同时使用Calico、Flannel**的最佳实践, 通过`Calico CNI`和`Calico 网络策略`与`Flannel`和主机本地`IPAM`插件相结合，以提供具有策略执行功能的 VXLAN 网络。
> 同时具备了flannel与calico的能力，但相应的也存在维护两个组件的复杂度。

> canal项目初始是为了将两者深度集成，后来发现使用canal的用户的需求只是为了让两者更好的协同，没有将两者合一的需求。因此canal项目已不维护，只停留在部署方案上。如果熟悉两个中间件，又想同时使用calico、与flannel的能力，可以考虑canal


![](/images/post-image/k8s-cni-canal-diagram.png)



| Policy | IPAM       | CNI    | Overlay | Routing | Datastore  |
|--------|------------|--------|---------|---------|------------|
| Calico | Host-local | Calico | VXLAN   | Static  | Kubernetes |


路由：static，用于路由**主机之间**的pod流量。静态路由通常与主机本地 IPAM 插件结合使用，后者会为每个主机静态分配一个 /24 pod IP 地址范围。
数据持久化：Kubernetes，即通过连接api-server进行数据的修改（不需要单独的存储管理；可通过api-server的rbac进行权限管理；可通过k8s的审计功能进行审计）


## 参考链接

[Canal项目地址(不维护)](https://github.com/projectcalico/canal)
[Calico解决网络策略，flannel解决网络通信(canal）](https://docs.tigera.io/calico/latest/getting-started/kubernetes/flannel/install-for-flannel)

