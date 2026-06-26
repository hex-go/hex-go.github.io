---
title: "K8s设备插件-编写自定义DevicePlugin"
categories:
  - Kubernetes
tags:
  - Device Plugin
  - Go
  - FPGA
  - RDMA
date: 2024-07-10 00:00:00
top: false
comments: true
keywords:
  - Device Plugin
  - 自定义
  - FPGA
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
| ② | **[Device Plugin 详解]({{< relref "2024-07-05-k8s设备插件-DevicePlugin详解.md" >}})** | 核心——机制原理、gRPC 接口、生命周期、部署 |
| ③ | **本篇 - 编写自定义 Device Plugin** | 扩展——FPGA、RDMA、ASIC 等自定义设备接入 |
| ④ | **[多设备管理与 AI 场景]({{< relref "2024-07-15-k8s设备插件-多设备管理与AI场景.md" >}})** | 进阶——GPU + RDMA + NVMe 组合调度 |
| ⑤ | **[DRA 动态资源分配]({{< relref "2024-07-20-k8s设备插件-DRA动态资源分配.md" >}})** | 演进——K8s 1.26+ 新一代资源分配机制，替代 Device Plugin 的新方向 |

---

# 重要

并非所有硬件加速器都有现成的 Device Plugin。FPGA、ASIC、自定义加密卡等设备需要自己编写 Device Plugin。核心是三个 gRPC 接口：ListAndWatch（汇报设备）、Allocate（分配设备）、PreStartContainer（容器初始化）。

---

## 1. 开发骨架

```go
package main

import (
    "net"
    "os"
    "time"
    "golang.org/x/net/context"
    "google.golang.org/grpc"
    pluginapi "k8s.io/kubelet/pkg/apis/deviceplugin/v1beta1"
)

// MyDevicePlugin 实现 DevicePluginServer 接口
type MyDevicePlugin struct {
    devices  []*pluginapi.Device
    socket   string
    server   *grpc.Server
}

// ListAndWatch：定期向 kubelet 汇报设备列表
func (p *MyDevicePlugin) ListAndWatch(e *pluginapi.Empty, s pluginapi.DevicePlugin_ListAndWatchServer) error {
    for {
        resp := &pluginapi.ListAndWatchResponse{Devices: p.devices}
        s.Send(resp)
        time.Sleep(10 * time.Second)
    }
}

// Allocate：分配设备给容器
func (p *MyDevicePlugin) Allocate(ctx context.Context, req *pluginapi.AllocateRequest) (*pluginapi.AllocateResponse, error) {
    var responses []*pluginapi.ContainerAllocateResponse
    for _, containerReq := range req.ContainerRequests {
        resp := &pluginapi.ContainerAllocateResponse{}
        for _, deviceID := range containerReq.DevicesIDs {
            resp.Devices = append(resp.Devices, &pluginapi.DeviceSpec{
                HostPath:      "/dev/" + deviceID,
                ContainerPath: "/dev/" + deviceID,
                Permissions:   "rw",
            })
        }
        responses = append(responses, resp)
    }
    return &pluginapi.AllocateResponse{ContainerResponses: responses}, nil
}

// PreStartContainer：容器启动前勾子
func (p *MyDevicePlugin) PreStartContainer(ctx context.Context, req *pluginapi.PreStartContainerRequest) (*pluginapi.PreStartContainerResponse, error) {
    return &pluginapi.PreStartContainerResponse{}, nil
}

// GetDevicePluginOptions
func (p *MyDevicePlugin) GetDevicePluginOptions(ctx context.Context, e *pluginapi.Empty) (*pluginapi.DevicePluginOptions, error) {
    return &pluginapi.DevicePluginOptions{PreStartRequired: false}, nil
}
```

---

## 2. 完整示例：FPGA Device Plugin

### 2.1 设备发现

```go
func (p *FPGAPlugin) discoverFPGAs() []*pluginapi.Device {
    var devices []*pluginapi.Device
    files, _ := filepath.Glob("/dev/xfpga/*")
    for i, f := range files {
        devices = append(devices, &pluginapi.Device{
            ID:     fmt.Sprintf("fpga-%d-%s", i, filepath.Base(f)),
            Health: pluginapi.Healthy,
        })
    }
    return devices
}
```

### 2.2 Allocate 返回环境变量和设备路径

```go
func (p *FPGAPlugin) Allocate(ctx context.Context, req *pluginapi.AllocateRequest) (*pluginapi.AllocateResponse, error) {
    responses := &pluginapi.AllocateResponse{}
    for _, cr := range req.ContainerRequests {
        resp := &pluginapi.ContainerAllocateResponse{
            Envs: map[string]string{
                "FPGA_DEVICE_IDS": strings.Join(cr.DevicesIDs, ","),
                "FPGA_BITSTREAM":  "/opt/bitstreams/default.aocx",
            },
            Mounts: []*pluginapi.Mount{
                {
                    ContainerPath: "/opt/bitstreams",
                    HostPath:      "/opt/fpga/bitstreams",
                    ReadOnly:      true,
                },
            },
            Devices: []*pluginapi.DeviceSpec{},
        }
        for _, id := range cr.DevicesIDs {
            resp.Devices = append(resp.Devices, &pluginapi.DeviceSpec{
                HostPath:      "/dev/xfpga/" + id,
                ContainerPath: "/dev/xfpga/" + id,
                Permissions:   "rw",
            })
        }
        responses.ContainerResponses = append(responses.ContainerResponses, resp)
    }
    return responses, nil
}
```

---

## 3. 注册到 kubelet

```go
func (p *MyDevicePlugin) register() error {
    conn, err := grpc.Dial("unix:///var/lib/kubelet/device-plugins/kubelet.sock", grpc.WithInsecure())
    if err != nil {
        return err
    }
    client := pluginapi.NewRegistrationClient(conn)
    req := &pluginapi.RegisterRequest{
        Version:      pluginapi.Version,
        Endpoint:     "my-device-plugin.sock",
        ResourceName: "example.com/my-device",
    }
    _, err = client.Register(context.Background(), req)
    return err
}
```

---

## 4. 常见设备类型接入

| 设备类型 | Resource Name | 发现方式 | Allocate 返回 |
|---------|-------------|---------|--------------|
| FPGA | `intel.com/fpga` | 扫描 `/dev/xfpga/` | 设备路径 + bitstream 路径 |
| RDMA | `rdma/hca` | 扫描 `ibv_devinfo` | `/dev/infiniband/uverbs*` |
| ASIC 加解密卡 | `vendor.com/crypto` | 扫描 `/dev/crypto*` | 设备路径 |
| NVMe 本地盘 | `nvme.com/ssd` | 扫描 `/dev/nvme*` | 块设备路径 |
| SR-IOV VF | `intel.com/sriov` | 扫描 `/sys/class/net/*/device/sriov_numvfs` | `/dev/vfio/*` |

---

## 5. 注意事项

| # | 注意 | 说明 |
|---|------|------|
| 1 | Plugin 以 `privileged: true` 运行 | 需要访问 `/dev/` 下的设备文件 |
| 2 | Socket 文件路径 | 必须在 `/var/lib/kubelet/device-plugins/` 下 |
| 3 | `ListAndWatch` 是长连接 | 断开后 kubelet 会重新连接，不要 panic |
| 4 | 设备 ID 需稳定 | 同一设备重启后 ID 应不变（用 UUID 或 PCI 地址） |
| 5 | Allocate 幂等 | 相同请求应返回相同结果 |
| 6 | 资源名格式 | `vendor-domain/resource-name`，如 `nvidia.com/gpu` |
| 7 | 健康检查要及时 | 设备故障后应尽快通过 `ListAndWatch` 报 `Unhealthy` |

---

## 参考链接

- [Kubernetes Device Plugin Framework](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/)
- [NVIDIA Device Plugin Source](https://github.com/NVIDIA/k8s-device-plugin)
- [Intel FPGA Device Plugin](https://github.com/intel/intel-device-plugins-for-kubernetes)
