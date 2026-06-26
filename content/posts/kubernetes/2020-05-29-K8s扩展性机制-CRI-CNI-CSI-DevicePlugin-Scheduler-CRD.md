---
title: K8s 扩展性机制——从基础设施到自定义控制器
categories:
  - Kubernetes
tags:
  - CNI
  - CSI
  - Device Plugin
  - Kubernetes
  - Operator
  - Scheduler
date: 2020-04-08 00:00:00
top: false
comments: true
pinned: true
series:
  - k8s基石
---

# 重要

Kubernetes 核心只做编排——调度、声明式 API、状态协调。容器的运行时、网络、存储、GPU、调度策略、自定义 API，全部通过扩展机制交给外部插件。

扩展机制按层级从下到上分为四层：

| 层级 | 扩展机制 | 管什么 | 代表实现 |
|------|----------|--------|----------|
| 基础设施层 | CRI、CNI、CSI | 运行时、网络、存储 | containerd、Calico、Ceph CSI |
| 资源层 | Device Plugin、DRA | GPU、FPGA 等硬件 | NVIDIA GPU Operator |
| 调度层 | Scheduler Framework | 自定义调度逻辑 | scheduler-plugins、Volcano |
| API 与控制层 | CRD、Operator | 自定义资源和控制器 | Prometheus Operator |

{{< keypoint >}}
K8s 的扩展哲学：核心只定义接口规范，具体实现全部下放。修改网络方案不碰 Kubelet，换 GPU 驱动不重启调度器，增加 CRD 不需要改 API Server 代码。
{{< /keypoint >}}

## 1.简介

Kubernetes 通过接口解耦核心组件和具体实现。日常工作中四层的接触频率：

| 接口 | 日常接触频率 | 说明 |
|------|-------------|------|
| CNI | 最高 | 网络问题排查频繁，跨节点不通先看 CNI |
| CSI | 中等 | 存储 PVC 挂不上、快照失败时排查 |
| CRI | 较低 | 通常由集群初始化工具配置（kubeadm/rke），日常运维少碰 |

## 2.基础设施层——CRI / CNI / CSI

### 2.1 CRI — 容器运行时接口

CRI（Container Runtime Interface）是 Kubelet 与容器运行时之间的 gRPC 协议。

```text
Kubelet (gRPC Client)
    |
    | Unix Socket (如 /run/containerd/containerd.sock)
    |
    v
containerd / CRI-O (gRPC Server)
    ├── RuntimeService  → 管理 Pod Sandbox、Container 生命周期
    └── ImageService    → 拉取、列表、删除镜像
```

Kubelet 在启动时通过 `--container-runtime-endpoint` 指定 CRI 的 socket 路径。

| 参数 | 示例值 | 说明 |
|------|--------|------|
| `--container-runtime-endpoint` | `unix:///run/containerd/containerd.sock` | CRI 实现监听的 socket |
| `--image-service-endpoint` | 默认与 runtime-endpoint 相同 | 用于单独的镜像服务 |

CRI 的核心流程：

```text
Kubelet 决定启动一个 Pod
    → RuntimeService.RunPodSandbox()    // 创建 Pod Sandbox（网络命名空间）
    → CNI 插件为 Sandbox 配置网络
    → RuntimeService.CreateContainer()  // 创建各容器
    → RuntimeService.StartContainer()   // 启动容器
```

Kubelet 的 CRI 请求是声明式的：只告诉容器运行时"我要一个什么状态的容器"，不管怎么实现。这也是 CRI-O 和 containerd 可以互相替换的前提。

### 2.2 CNI — 容器网络接口

CNI（Container Network Interface）是 CNCF 定义的容器网络规范。Kubelet 通过 CNI 调用插件为每个 Pod 分配 IP、创建网络接口、配置路由。

```text
Kubelet
    |
    | 读取 /etc/cni/net.d/*.conf  → 确定用哪个 CNI 插件
    | 调用 CNI 二进制（/opt/cni/bin/）
    |
    v
CNI Plugin
    ├── ADD    → 创建 veth pair，分配 IP，写入路由
    ├── DEL    → Pod 删除时回收 IP，删除 veth
    └── CHECK  → 周期性健康检查现有配置
```

CNI 插件按数据面分为两类：

| 类型 | 原理 | 代表 | 性能 |
|------|------|------|------|
| Overlay | 封装隧道（VXLAN/IPIP） | Flannel VXLAN、Calico IPIP | 有封装开销 |
| 路由 | 不封装，直接路由 | Calico BGP、Flannel HostGW | 接近裸机 |

深度解析、包流向和方案选型见 [K8s 网络 CNI 系列](/series/k8s网络/)。

### 2.3 CSI — 容器存储接口

CSI（Container Storage Interface）是 CNCF 定义的容器存储标准。Kubernetes 通过 CSI 将存储操作从核心代码剥离到外部组件。

```text
[外部 CSI 组件]
    ├── Controller Plugin      → Provision/Delete（创建/删除 PV）
    ├── Node Plugin            → Stage/Publish（挂载到 Pod）
    ├── external-provisioner   → 监听 PVC 事件，调用 Controller.CreateVolume
    ├── external-attacher      → 监听 VolumeAttachment 事件
    └── node-driver-registrar  → 注册插件到 Kubelet

[Kubernetes 核心]
    ├── kube-controller-manager → 创建 PV / PVC 对应的 VolumeAttachment
    └── Kubelet                 → 调用 Node Plugin 完成挂载
```

CSI 替换了早期的 In-tree Volume Plugin（插件编进 K8s 二进制）和 FlexVolume（脚本式插件），支持：

| 特性 | In-tree | CSI |
|------|---------|-----|
| 独立升级 | 否，需跟随 K8s 版本 | 是，独立发布 |
| 动态供应 | 部分支持 | 完整支持 |
| 快照/克隆 | 不支持 | 支持 |
| 在线扩容 | 不支持 | 支持 |

深度架构解析见 [K8s 存储 CSI 系列](/series/k8s存储/)。

### 2.4 三个接口的调用链（一次 Pod 启动）

```text
调度器选中 Node
    ↓
Kubelet 收到 Pod Spec
    ↓
┌── CRI: RunPodSandbox   → 创建 Pod Sandbox（共享网络命名空间）
│
├── CNI: ADD              → 分配 IP、创建 veth、配置路由 → Pod 网络就绪
│
├── CRI: CreateContainer  → 为 Init Container 和主 Container 分别创建
│
├── CSI: PublishVolume     → 将 PV 挂载到 Pod 对应的路径
│
└── CRI: StartContainer   → 启动容器 → Pod Running
```

三个接口不是孤立工作——CRI 创建 Sandbox 之后 CNI 才能插网络，CSI 挂载在容器启动之前，CRI 拉起容器在最后。

## 3.资源层——Device Plugin / DRA

基础设施层管 CPU、内存、磁盘、网络，但当 Pod 需要 GPU、FPGA、Infiniband 等专用硬件时，Kubelet 不知道这些设备的存在。Device Plugin 是 Kubelet 发现和分配硬件资源的扩展机制。

### 3.1 Device Plugin

```text
Kubelet
    |
    | 通过 Unix Socket 发现插件（/var/lib/kubelet/device-plugins/）
    |
    v
Device Plugin (vendor-provided)
    ├── ListAndWatch  → 向 Kubelet 上报设备列表及健康状态
    ├── Allocate      → 调度器选出 Node 后，Kubelet 调用 Allocate 获取设备挂载信息
    └── 健康检查       → 设备变更时重新上报
```

Pod 声明需要 GPU：

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
```

Device Plugin 上报的资源名（`nvidia.com/gpu`）出现在 Node 的 `status.allocatable` 中，调度器据此做 Pod 放置决策。

| 步骤 | 动作 |
|------|------|
| Device Plugin 启动 → 向 Kubelet 注册 | Kubelet 将资源加入 Node Status |
| 用户创建带 GPU 请求的 Pod | 调度器根据资源筛选节点 |
| Kubelet 调用 Allocate | Device Plugin 返回设备路径、环境变量等挂载信息 |
| Kubelet 启动容器 | 挂载 GPU 设备、注入环境变量 |

深度解析见 [K8s 设备插件系列](/series/k8s设备插件/)。

### 3.2 DRA——动态资源分配

Device Plugin 是静态的——Pod 必须声明固定数量的 GPU。DRA（Dynamic Resource Allocation，K8s 1.26+）允许更灵活的设备分配：

| 特性 | Device Plugin | DRA |
|------|---------------|-----|
| 分配粒度 | 整卡 | 整卡或 MIG 分区 |
| 设备选择 | 由调度器决定 | 用户可在 Claim 中描述需求 |
| 跨 Pod 共享 | 不支持 | 支持 |
| 网络设备 | 不支持 | 支持 Infiniband、DPU |

## 4.调度层——Scheduler Framework

K8s 默认调度器只认 CPU/内存/节点亲和性。当需要自定义调度逻辑（如 GPU 拓扑感知、成本优先、实时性优先）时，通过 Scheduler Framework 的扩展点插入自定义逻辑。

```text
调度周期（每个 Pod 一次）
  QueueSort → PreFilter → Filter → PreScore → Score → Reserve → Permit → Bind
                                                                       ↓
绑定周期（异步）                                                     PreBind → Bind → PostBind
```

关键扩展点：

| 扩展点 | 作用 | 示例 |
|--------|------|------|
| Filter | 过滤不满足条件的 Node | GPU 型号筛选、存储类型筛选 |
| Score | 为每个 Node 打分 | 成本优先（选最便宜）、装箱率优先（选最满） |
| Reserve | 资源预占 | GPU 拓扑感知预留 |
| Permit | 阻塞/放行调度 | 等待外部条件满足（如 license 校验） |

各扩展点可以注册多个插件，调度器在每个阶段依次调用，Score 阶段的分数加权求和决定最终选中节点。

Scheduler Framework 的深度解析见独立文章 [Scheduler Framework 详解](/posts/kubernetes/2026-06-24-k8s调度扩展-scheduler-framework详解/)。

## 5.API 与控制层——CRD / Operator

前面三层解决"如何运行 Pod"，这一层解决"如何声明和管理业务对象"。

### 5.1 CRD——自定义资源

CRD（Custom Resource Definition）允许在 K8s API 中注册新的资源类型。

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: mysqls.database.example.com
spec:
  group: database.example.com
  versions:
    - name: v1
      served: true
      storage: true
  scope: Namespaced
  names:
    plural: mysqls
    singular: mysql
    kind: MySQL
```

注册后 kubectl 可以直接操作：

```bash
kubectl get mysqls
kubectl describe mysql my-db
```

CRD 本身只声明数据结构，不包含业务逻辑。业务逻辑由 Operator 实现。

### 5.2 Operator——自定义控制器

Operator 监听 CRD 资源的变化（创建、更新、删除），调用 K8s API 实现自动化运维。

```text
CRD 声明期望状态          →  例如：Spec.Replicas = 3
Operator（控制器）        →  持续对比 Spec 和实际状态
实际状态                  →  kubectl get pods | grep mysql
  ↓ 有差异
Operator 执行调谐          →  创建 StatefulSet、Service、PVC…
```

| 场景 | 人工操作 | Operator 自动化 |
|------|----------|----------------|
| 扩缩容 | 手动改 Deployment replicas | 改 CRD Spec，Operator 执行 |
| 备份恢复 | 登录 Pod，dump + 上传 | CRD 声明备份策略，Operator 定时执行 |
| 主从切换 | 手动 promote slave | Operator 检测主库异常，自动切换 |

深度解析见 [CRD 概念、使用场景、go 示例](/posts/kubernetes/2020-08-13-crd-概念使用场景go示例/) 和 [K8s 扩展——Operator](/posts/kubernetes/2023-10-01-k8s扩展-operator/)。

## 6.总结

四层扩展机制从基础设施到业务逻辑：

| 层级 | 机制 | 解决的核心问题 |
|------|------|---------------|
| 基础设施层 | CRI / CNI / CSI | 容器怎么跑、网怎么通、盘怎么挂 |
| 资源层 | Device Plugin / DRA | GPU / FPGA 等硬件怎么接入调度 |
| 调度层 | Scheduler Framework | 自定义 Node 筛选和打分逻辑 |
| API 与控制层 | CRD / Operator | 业务状态怎么声明、怎么自愈 |

选型逻辑：先有（基础设施层），再加（资源层），后改（调度层），最后配（CRD/Operator）。从下到上是扩展能力的递进。

## 7.参考

- [Understanding Kubernetes Interfaces: CRI, CNI, & CSI](https://caylent.com/understanding-kubernetes-interfaces-cri-cni-csi)
- [Kubernetes Handbook - CSI](https://jimmysong.io/kubernetes-handbook/concepts/csi.html)
- [K8s 网络 CNI 系列](/series/k8s网络/)
- [K8s 存储 CSI 系列](/series/k8s存储/)
- [K8s 设备插件系列](/series/k8s设备插件/)
- [CRD 概念、使用场景、go 示例](/posts/kubernetes/2020-08-13-crd-概念使用场景go示例/)
- [K8s 扩展——Operator](/posts/kubernetes/2023-10-01-k8s扩展-operator/)
- [Scheduler Framework 详解](/posts/kubernetes/2026-06-24-k8s调度扩展-scheduler-framework详解/)


