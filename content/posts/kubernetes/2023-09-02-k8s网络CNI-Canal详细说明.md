---
title: "K8s网络CNI-Canal详细说明"
categories:
  - Kubernetes
tags:
  - Canal
  - Kubernetes
date: '2023-09-02 20:19:12'
draft: true
series:
  - k8s基石
---
Cannal 完美保持Flannel原生的三种模式，扩展支持Calico的BGP、IPIP模式。并且支持网络策略。

![](/images/post-image/k8s-cni-canal-diagram.png)




## 参考链接

[Calico网络策略确保CNI的安全（利用 Calico 强化 Kubernetes 网络策略）](https://platformengineering.org/talks-library/secure-kubernetes-container-network-interface-cni-with-calico)

[Kubernetes 网络：使用 Calico 实现高性能](https://platform9.com/blog/kubernetes-networking-achieving-high-performance-with-calico/)

[K8s 网络和 calico CNI 插件](https://medium.com/@BalajiSA/k8s-networking-and-calico-cni-plugin-7ebf84bf7fec)

