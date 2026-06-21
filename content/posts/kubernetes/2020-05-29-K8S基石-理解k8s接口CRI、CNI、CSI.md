---
title: K8S基石-理解k8s接口CRI、CNI、CSI
categories:
  - Kubernetes
tags:
  - Kubernetes
  - CNI
  - CSI
  - CRI
date: '2020-05-29 00:52:19'
top: false
comments: true
keywords: 
  - CNI
series:
  - k8s基石
---

## 引言
Kubernetes 设计初衷是为模块化的云原生应用程序的部署、扩展和管理提供便捷性和灵活性。在 Kubernetes 的背后，有许多关键组件和接口，这些组件协同工作，以确保集群的正常运行。
本文将重点介绍三个重要的 Kubernetes 接口：CRI、CNI 和 CSI，它们在容器运行时、网络和存储方面发挥着关键作用。

## 1. 容器运行时接口（CRI）
CRI（Container Runtime Interface）是k8s用于与`容器运行时`通信的主要协议。容器运行时负责管理和执行容器的生命周期，包括创建、启动、停止和销毁容器。
CRI 通过定义一组 gRPC 服务和数据结构，使kubelet能够与各种容器运行时（如 Docker、Containerd 等）交互，无需重新编译集群组件。

Container Runtime 实现了`CRI gRPC Server`，包括`RuntimeService`和`ImageService`。该 gRPC Server 需要监听本地的`Unix socket`，而 kubelet 则作为`gRPC Client`运行。
<img height="70%" src="/images/post-image/k8s-cri-architecture.png" width="70%"/>

## 2. 容器网络接口（CNI）
CNI（Container Network Interface）是 CNCF 定义的容器网络接口标准。Kubelet 通过调用 CNI 插件为 Pod 配置网络——创建 veth pair、分配 IP、配置路由。

CNI 插件按数据路径分为两类：**Overlay（封装隧道，如 VXLAN/IPIP）** 和 **路由模式（不封装，如 BGP/HostGW）**。深度的概念解析、包流向、抓包分析和方案选型见 [K8s 网络 CNI 系列](/series/k8s网络/)。


## 3. 容器存储接口（CSI）
CSI（Container Storage Interface）是 CNCF 定义的容器存储接口标准。Kubernetes 通过 CSI 将存储管理（Provision、Attach、Mount、Snapshot 等）从核心代码剥离为独立的 Sidecar 组件 + CSI 插件。

CSI 替换了早期的 In-tree Volume Plugin 和 FlexVolume 模式，支持动态供应、快照、克隆、在线扩容等高级特性。深度架构解析和插件开发见 [K8s 存储 CSI 系列](/series/k8s存储/)。

总结：
Kubernetes 的成功在很大程度上得益于其丰富的接口体系，使得不同的组件能够协同工作，提供全面的容器编排解决方案。CRI、CNI 和 CSI 是 Kubernetes 中三个关键的接口，它们分别处理容器运行时、网络和存储方面的任务。
理解这些接口如何工作以及它们的作用，有助于更好地管理和优化 Kubernetes 集群，从而更好地支持应用程序的部署和运行。

# 参考文献

**[Understanding Kubernetes Interfaces: CRI, CNI, & CSI](https://caylent.com/understanding-kubernetes-interfaces-cri-cni-csi)**

**[K8S-handbook--容器存储接口](https://jimmysong.io/kubernetes-handbook/concepts/csi.html)**