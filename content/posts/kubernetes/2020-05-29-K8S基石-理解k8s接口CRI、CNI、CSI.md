---
title: K8S基石-理解k8s接口CRI、CNI、CSI
categories:
  - Kubernetes
tags:
  - Kubernetes
  - Draft
date: '2020-05-29 00:52:19'
top: false
comments: true
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
CNI（Container Network Interface）是k8s中负责处理容器网络配置的接口。在 Kubernetes 集群中，各个容器需要能够相互通信，而 CNI 就负责为容器配置网络。
CNI 插件通过在容器创建、启动或停止时设置网络环境，使得容器能够正确地连接到集群网络。这种设计允许用户根据需要选择不同的网络解决方案，从而满足不同的网络需求。


### 2.1 CNI设计考量

CNI 插件分配了命名空间隔离、流量和 IP 过滤等功能，而 Kubernetes Kube-Net 插件默认情况下不提供这些功能。假设开发人员想要实现这些高级网络功能。
在这种情况下，他们必须使用带有容器网络接口（CNI）的 CNI 插件，以便更轻松地创建和管理网络。

- 容器运行时必须在调用任何插件之前为容器创建一个新的网络命名空间。
- 然后，容器运行时必须确定这个容器应属于哪个网络，并为每个网络确定哪些插件必须被执行。
- 

### 2.2 CNI网络模型
CNI 网络插件实现网络结构的网络模型分为两类：封装网络模型（例如 Virtual Extensible Lan，缩写是 VXLAN）或非封装网络模型（例如 Border Gateway Protocol，缩写是 BGP）。

- 封装网络(encapsulated network)

封装信息由 Kubernetes worker 之间的 UDP 端口分发，交换如何访问 MAC 地址的网络控制平面信息。此类网络模型中常用的封装是 VXLAN、Internet 协议安全性 (IPSec) 和 IP-in-IP。

封装网络在现有的 Kubernetes 集群节点三层（L3）网络拓扑之上创建了一个**逻辑**二层（L2）网络。通过这一模型，你能够为容器提供隔离的 L2 网络，无需进行路由分发。
封装网络会带来少量的处理开销，并因覆盖封装（生成IP header）而增加 IP 包的大小。封装信息通过`K8s-worker`之间的 UDP 端口传输，交换着关于访问 MAC 地址的网络控制平面信息。
在这类网络模型中，常见的封装方式包括 VXLAN、IPSec（Internet 协议安全性）和 IP-in-IP。

简单来说，这种网络模型在 `k8s-worker` 之间生成了一种扩展网桥，连接了各个pod。

如果偏向使用扩展 L2 网桥，则可以选择此网络模型。此网络模型对 Kubernetes worker 的 L3 网络延迟很敏感。如果数据中心位于不同的地理位置，请确保它们之间的延迟较低，以避免最终的网络分割。

使用这种网络模型的 CNI 网络插件包括 Flannel、Canal、Weave 和 Cilium。默认情况下，Calico 不会使用此模型，但你可以对其进行配置。

![](/images/post-image/k8s-cni-encapsulated-network.png)

- 非封装网络(Unencapsulated Network)

此网络模型创建了一个 L3 网络，用于在容器之间进行数据包路由。这种模型并不创建隔离的 L2 网络，因此不会引起额外的开销。然而，这些优点的代价是，k8s-worker节点必须管理所有必要路由分发。
该网络模型避免了使用 `IP header` 进行封装，而是通过`k8s-worker`之间的网络协议来传播路由信息，比如使用 BGP 协议，以实现 Pod 之间的连接。

简单来说，这种网络模型在`k8s-worker`之间形成了一个扩展网络路由器，提供了连接 Pod 所需的信息。

如果更偏好采用 L3 网络，则可以选择此网络模型。该模型在操作系统层面上为`k8s-worker`节点动态更新路由信息，对延迟不太敏感。

使用这一网络模型的 CNI 网络插件包括 Calico 和 Cilium。Cilium 也能够通过这一模型进行配置，尽管这并非其默认模式。

![](/images/post-image/k8s-cni-encapsulated-network.png)


## 3. 容器存储接口（CSI）
CSI（Container Storage Interface）是 Kubernetes 中处理容器存储的接口。CSI 使存储供应商能够开发插件，将各种存储系统集成到 Kubernetes 中。
这些插件允许管理员在不影响应用程序的情况下管理存储，例如动态卷配置、快照和克隆操作。通过 CSI，Kubernetes 的存储管理变得更加灵活，能够适应不同的存储需求。

总结：
Kubernetes 的成功在很大程度上得益于其丰富的接口体系，使得不同的组件能够协同工作，提供全面的容器编排解决方案。CRI、CNI 和 CSI 是 Kubernetes 中三个关键的接口，它们分别处理容器运行时、网络和存储方面的任务。
理解这些接口如何工作以及它们的作用，有助于更好地管理和优化 Kubernetes 集群，从而更好地支持应用程序的部署和运行。

# 参考文献

**[Understanding Kubernetes Interfaces: CRI, CNI, & CSI](https://caylent.com/understanding-kubernetes-interfaces-cri-cni-csi)**

**[K8S-handbook--容器存储接口](https://jimmysong.io/kubernetes-handbook/concepts/csi.html)**