---
title: "K8s设备插件-DevicePlugin详解"
categories:
  - Kubernetes
tags:
  - Device Plugin
  - GPU
  - gRPC
  - Kubernetes
date: 2024-07-05 00:00:00
top: false
comments: true
keywords:
  - Device Plugin
  - gRPC
  - kubelet
series:
  - k8s设备插件
pinned: false
---

## 系列导航

本系列介绍 K8s 中 Device Plugin 机制及其在 GPU 管理等 AI 场景中的应用。

`① GPU基础 → ② Device Plugin → ③ 开发Plugin → ④ 多设备/AI场景 → ⑤ DRA`

| 顺序 | 文章 | 定位 |
|------|------|------|
| ① | **[GPU 管理基础]({{< relref "2024-07-01-k8s设备插件-GPU管理基础.md" >}})** | 基础——NVIDIA GPU、CUDA、MIG、vGPU |
| ② | **本篇 - Device Plugin 详解** | 核心——机制原理、gRPC 接口、生命周期、部署 |
| ③ | **[编写自定义 Device Plugin]({{< relref "2024-07-10-k8s设备插件-编写自定义DevicePlugin.md" >}})** | 扩展——FPGA、RDMA、ASIC 等自定义设备接入 |
| ④ | **[多设备管理与 AI 场景]({{< relref "2024-07-15-k8s设备插件-多设备管理与AI场景.md" >}})** | 进阶——GPU + RDMA + NVMe 组合调度 |
| ⑤ | **[DRA 动态资源分配]({{< relref "2024-07-20-k8s设备插件-DRA动态资源分配.md" >}})** | 演进——K8s 1.26+ 新一代资源分配机制，替代 Device Plugin 的新方向 |

---

# 重要

Device Plugin 是 K8s 管理硬件设备（GPU、FPGA、RDMA、SR-IOV）的标准机制。它通过 gRPC 与 kubelet 交互，核心是 `ListAndWatch`（上报设备信息）和 `Allocate`（分配设备给容器）。一个设备一个 Plugin，以 DaemonSet 部署在每个有该设备的节点上。

---

## 1. 为什么需要 Device Plugin

### 1.1 传统方式的问题

在没有 Device Plugin 之前，GPU 支持需要：
1. 手动 PATCH Node Status 添加 `nvidia.com/gpu` 数量
2. 手动配置 kubelet 的 `--feature-gates=DevicePlugins=true`

### 1.2 Device Plugin 解决什么

| 问题 | Device Plugin 方案 |
|------|-------------------|
| 节点设备数量上报 | Plugin 通过 `ListAndWatch` 自动上报 |
| 容器分配设备 | Plugin 通过 `Allocate` 返回设备路径和环境变量 |
| 设备健康检查 | 定期上报设备状态 |
| 新设备类型接入 | 只需实现 Device Plugin gRPC 接口 |

---

## 2. 架构

{{< diagram >}}
kubelet
  ├── Device Manager（kubelet 内部组件）
  │   ├── 注册：接收 Device Plugin 的注册请求（Unix Socket）
  │   └── 分配：向 Device Plugin 请求设备分配
  │
  └── Device Plugin（DaemonSet，每个节点一个 Pod）
      ├── ListAndWatch → 上报设备列表（定期流式返回）
      ├── Allocate → 分配设备给容器（返回设备路径、环境变量、挂载点）
      └── PreStartContainer → 容器启动前的准备操作（可选）
{{< /diagram >}}

### 2.1 通信方式

| 步骤 | 说明 |
|------|------|
| 注册 | Plugin 启动后向 kubelet 的 Unix Socket 发送注册请求 |
| 监听 | kubelet 通过 gRPC 连接 Plugin，调用 `ListAndWatch` |
| 分配 | Pod 调度后，kubelet 调用 `Allocate` 获取设备信息 |

Unix Socket 路径：
- kubelet: `/var/lib/kubelet/device-plugins/kubelet.sock`
- Plugin: `/var/lib/kubelet/device-plugins/<resource-name>.sock`

---

## 3. gRPC 接口

### 3.1 Registration Service

```protobuf
service Registration {
    rpc Register(RegisterRequest) returns (Empty);
}

message RegisterRequest {
    string version = 1;            // 插件 API 版本
    string endpoint = 2;           // 插件 gRPC endpoint
    string resource_name = 3;      // 资源名，如 nvidia.com/gpu
}
```

### 3.2 Device Plugin Service

```protobuf
service DevicePlugin {
    rpc ListAndWatch(Empty) returns (stream ListAndWatchResponse);
    rpc Allocate(AllocateRequest) returns (AllocateResponse);
    rpc PreStartContainer(PreStartContainerRequest) returns (PreStartContainerResponse);
}

message ListAndWatchResponse {
    repeated Device devices = 1;
}

message Device {
    string ID = 1;       // 设备 ID
    string health = 2;   // Healthy / Unhealthy
}

message AllocateRequest {
    repeated string devices_ids = 1;
}

message AllocateResponse {
    repeated ContainerAllocateResponse container_responses = 1;
}

message ContainerAllocateResponse {
    map<string, string> envs = 1;        // 环境变量（如 NVIDIA_VISIBLE_DEVICES=GPU-xxx）
    repeated Mount mounts = 2;            // 挂载点（如 /usr/local/nvidia）
    repeated DeviceSpec devices = 3;      // 设备文件（如 /dev/nvidia0）
    map<string, string> annotations = 4;  // 注解
}
```

---

## 4. 工作流程

### 4.1 启动

```text
1. Device Plugin Pod 启动（DaemonSet）
2. Plugin 连接 kubelet socket：/var/lib/kubelet/device-plugins/kubelet.sock
3. Plugin 调用 Register API：
     resource_name = "nvidia.com/gpu"
     endpoint = "/var/lib/kubelet/device-plugins/nvidia-gpu.sock"
4. kubelet 注册该资源类型
5. kubelet 连接 Plugin 的 gRPC Server，启动 ListAndWatch
6. Plugin 定期通过 ListAndWatch 返回设备列表
```

### 4.2 调度与分配

```text
1. 用户创建 Pod（resources.limits.nvidia.com/gpu: 1）
2. 调度器根据 Node 的 Allocatable nvidia.com/gpu 选择合适的节点
3. kubelet 调 Plugin 的 Allocate(device_ids=["GPU-xxx"])
4. Plugin 返回：
     envs: {"NVIDIA_VISIBLE_DEVICES": "GPU-xxx"}
     mounts: [{host_path: "/usr/local/nvidia", container_path: "/usr/local/nvidia"}]
     devices: [{host_path: "/dev/nvidia0", container_path: "/dev/nvidia0"}]
5. kubelet 将这些信息注入 CRI 创建容器的参数
6. 容器启动，内部可访问 GPU 设备和驱动
```

### 4.3 ListAndWatch

ListAndWatch 是一个**服务端流式** RPC——Plugin 持续向 kubelet 推送设备状态：

```go
func (p *Plugin) ListAndWatch(empty *pluginapi.Empty, stream pluginapi.DevicePlugin_ListAndWatchServer) error {
    for {
        devices := p.getDevices()  // 扫描 /dev/nvidia*
        resp := &pluginapi.ListAndWatchResponse{
            Devices: devices,
        }
        stream.Send(resp)
        time.Sleep(10 * time.Second)  // 默认每 10 秒上报一次
    }
}
```

| 字段 | 说明 |
|------|------|
| `ID` | 设备唯一标识，如 `GPU-0ab1cd2e-3f45-6789-abcd-ef0123456789` |
| `health` | `Healthy`（设备正常）/ `Unhealthy`（设备故障，调度器排除） |

---

## 5. Health Check

```go
func (p *Plugin) healthCheck() {
    for {
        health := "Healthy"
        if p.isDeviceBroken() {
            health = "Unhealthy"
        }
        // 状态变化时通过 ListAndWatch 上报
        time.Sleep(30 * time.Second)
    }
}
```

当设备状态变为 Unhealthy 时，kubelet 会：
1. 更新 Node 的 Allocatable 资源量（减少该设备）
2. 不会立即驱逐已使用该设备的 Pod（取决于 kubelet 配置）

---

## 6. 部署（以 NVIDIA GPU 为例）

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin
  template:
    metadata:
      labels:
        name: nvidia-device-plugin
    spec:
      hostNetwork: true
      containers:
      - name: nvidia-device-plugin
        image: nvcr.io/nvidia/k8s-device-plugin:v0.14.3
        args: ["--resource-name=nvidia.com/gpu"]
        env:
        - name: NVIDIA_VISIBLE_DEVICES
          value: all
        - name: FAIL_ON_INIT_ERROR
          value: "false"
        securityContext:
          privileged: true
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
```

---

## 参考链接

- [Kubernetes Device Plugin Framework](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/)
- [NVIDIA Device Plugin](https://github.com/NVIDIA/k8s-device-plugin)
- [Device Plugin API](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/apis/deviceplugin/v1beta1/api.proto)
