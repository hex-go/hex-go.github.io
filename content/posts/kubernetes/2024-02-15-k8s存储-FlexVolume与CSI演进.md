---
title: "K8s存储-FlexVolume与CSI演进"
categories:
  - Kubernetes
tags:
  - CSI
  - Kubernetes
  - Storage
date: 2024-02-15 00:00:00
comments: true
keywords:
  - FlexVolume
  - CSI
  - 存储插件
series:
  - k8s存储
pinned: false
---

## 系列导航

本系列从 K8s 存储模型入手，逐步展开到 CSI 插件实现与云原生存储全景。

`① 概念 → ② Volume 生命周期 → ③ CSI 架构 → ④ FlexVolume 演进 → ⑤ 对比 → ⑥ 排障 ‖ ⑦ 开发 → ⑧ 高级特性 → ⑨ 演进展望`

| 顺序 | 文章 | 定位 |
|------|------|------|
| ① | **[概念与入门]({{< relref "2024-02-01-k8s存储-概念与入门.md" >}})** | 基础——K8s 存储模型、PV/PVC/StorageClass |
| ② | **[Volume 生命周期全解析]({{< relref "2024-02-05-k8s存储-Volume生命周期全解析.md" >}})** | 全貌——两阶段处理、动态/静态供应 |
| ③ | **[CSI 架构详解]({{< relref "2024-02-10-k8s存储-CSI架构详解.md" >}})** | 标准——gRPC 三服务、Sidecar 模式 |
| ④ | **本篇 - FlexVolume 与 CSI 演进** | 演进——FlexVolume 原理、CSI 设计思想 |
| ⑤ | **[存储方案对比与选型]({{< relref "2024-02-20-k8s存储-方案对比与选型.md" >}})** | 选型——主流 CSI 插件横向对比 |
| ⑥ | **[排障思路与常用命令]({{< relref "2024-02-25-k8s存储-排障思路与常用命令.md" >}})** | 运维——工具链 + 场景排查 |
| — | **核心路径 ↑** | **扩展展望 ↓** |
| ⑦ | **[CSI 插件开发指南]({{< relref "2024-03-01-k8s存储-CSI插件开发指南.md" >}})** | 扩展——从零开发一个 CSI 插件 |
| ⑧ | **[高级特性详解]({{< relref "2024-03-05-k8s存储-高级特性详解.md" >}})** | 进阶——快照、克隆、扩容、拓扑感知 |
| ⑨ | **[云原生存储演进与展望]({{< relref "2024-03-10-k8s存储-云原生存储演进与展望.md" >}})** | 展望——容器原生存储、DPU 卸载 |

---

# 重要

K8s 存储插件经历了 In-tree → FlexVolume → CSI 三代演进。FlexVolume 用脚本实现、需 root 权限、无法动态供应；CSI 用 gRPC、容器化部署、独立升级。CSI 已成为唯一推荐的存储插件标准，In-tree 和 FlexVolume 均已废弃。

---

## 1. 三代演进

| 代次 | 方案 | 接口 | 部署 | 状态 |
|------|------|------|------|------|
| 第一代 | In-tree Plugin | Go 接口（编译进 kubelet） | 随 K8s 发布 | 废弃中（迁移到 CSI） |
| 第二代 | FlexVolume | 可执行脚本 | 宿主机路径 | 已废弃 |
| 第三代 | CSI | gRPC | 容器化 Sidecar | **推荐** |

---

## 2. In-tree Plugin

K8s 最初内置了 20 多种存储插件，代码直接写在 K8s 主仓库的 `pkg/volume/` 目录下。

### 2.1 工作方式

每个插件实现 `VolumePlugin` 接口，kubelet 直接调用 Go 函数：

```go
// 简化的接口
type VolumePlugin interface {
    Init(host VolumeHost) error
    NewMounter(spec *Volume, pod *Pod) Mounter
    NewUnmounter(name string, podUID types.UID) Unmounter
}
```

### 2.2 问题

| 问题 | 说明 |
|------|------|
| 耦合 K8s 版本 | 插件升级必须等 K8s 发版 |
| 测试困难 | 插件测试需要编译整个 K8s |
| 第三方不可扩展 | 存储厂商无法在不修改 K8s 源码的情况下添加新插件 |

---

## 3. FlexVolume

### 3.1 工作方式

FlexVolume 是一个**可执行文件**（脚本或二进制），放在宿主机固定路径下：

```
/usr/libexec/kubernetes/kubelet-plugins/volume/exec/<vendor>~<driver>/<driver>
```

kubelet 在 Mount/Unmount 阶段直接 fork 执行这个脚本：

```bash
# Mount 操作
/usr/libexec/kubernetes/kubelet-plugins/volume/exec/k8s~nfs/nfs mount <mountDir> <jsonParam>

# Unmount 操作
/usr/libexec/kubernetes/kubelet-plugins/volume/exec/k8s~nfs/nfs unmount <mountDir>
```

### 3.2 FlexVolume PV 定义

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-flex-nfs
spec:
  capacity:
    storage: 10Gi
  accessModes: ["ReadWriteMany"]
  flexVolume:
    driver: "k8s/nfs"          # 对应路径 k8s~nfs/nfs
    fsType: "nfs"
    options:
      server: "10.10.0.25"
      share: "export"
```

### 3.3 脚本必须实现的命令

| 命令 | 说明 |
|------|------|
| `init` | 初始化插件 |
| `mount <dir> <json>` | 挂载 Volume |
| `unmount <dir>` | 卸载 Volume |
| `attach` / `detach` | 可选：Attach/Detach |
| `waitfordetach` | 可选：等待 Detach 完成 |
| `isattached` | 可选：检查是否已 Attach |

### 3.4 FlexVolume 的局限

| 局限 | 说明 |
|------|------|
| 需要 root 权限 | 脚本以 root 运行在宿主机上，安全风险大 |
| 无动态供应 | 只支持静态供应，PV 必须手动创建 |
| 部署困难 | 需要在每个节点上安装脚本，无容器化方案 |
| 无法独立升级 | 脚本更新需要登录每台宿主机替换 |
| 无快照/克隆 | 只支持基本的 Mount/Unmount |
| 调试困难 | 错误信息只有脚本的 stdout/stderr |

---

## 4. CSI：为什么是更好的方案

### 4.1 设计思想对比

| 维度 | FlexVolume | CSI |
|------|-----------|-----|
| 接口 | 脚本命令行 | gRPC protobuf |
| 部署 | 宿主机脚本 | 容器化 Pod |
| 动态供应 | 不支持 | Sidecar（external-provisioner） |
| Attach/Detach | 可选，脚本实现 | Controller Service |
| 快照/克隆 | 不支持 | Sidecar + CSI 接口 |
| 扩容 | 不支持 | ControllerExpand + NodeExpand |
| 升级 | 逐台替换脚本 | 更新容器镜像 |
| 权限 | root | 可限制（但通常仍需 privileged） |

### 4.2 CSI 的解耦设计

{{< diagram >}}
K8s 主仓库
  ├── kubelet（调用 CSI gRPC，不关心实现）
  ├── AD Controller（创建 VolumeAttachment）
  └── PV Controller（创建 PV 对象）
       ↓ gRPC（标准接口）
CSI Plugin（独立仓库，独立发布）
  ├── Identity Service
  ├── Controller Service
  └── Node Service
       ↓
底层存储系统
{{< /diagram >}}

{{< keypoint >}}
FlexVolume 把存储逻辑塞进 kubelet 的执行路径。CSI 把存储逻辑完全抽离为独立进程，kubelet 只通过 gRPC 调用。这就是 CSI 的核心优势——解耦。
{{< /keypoint >}}

---

## 5. 迁移路径

### 5.1 In-tree → CSI

K8s 社区通过 CSI Migration 机制，将 In-tree 插件的调用透明转发到 CSI 插件：

| 阶段 | K8s 版本 | 说明 |
|------|---------|------|
| Alpha | 1.14 | csi-migration 开启 |
| Beta | 1.17 | 默认开启部分插件迁移 |
| GA | 1.18+ | AWS EBS、GCE PD、vSphere 等完成迁移 |

已迁移的 In-tree 插件：`awsElasticBlockStore`、`gcePersistentDisk`、`azureDisk`、`vSphere Volume`、`portworx`、`cinder`。

### 5.2 FlexVolume → CSI

FlexVolume 没有自动迁移机制。需要：

1. 部署对应的 CSI 插件
2. 将 PV 的 `flexVolume` 字段改为 `csi`
3. 更新 StorageClass 的 `provisioner` 字段
4. 测试兼容性

---

## 参考链接

- [FlexVolume Documentation](https://kubernetes.io/docs/concepts/storage/volumes/#flexVolume)
- [CSI Migration](https://kubernetes.io/blog/2022/09/26/csi-migration-phase-2/)
- [From FlexVolume to CSI](https://kubernetes-csi.github.io/docs/)
