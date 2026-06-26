---
title: K8s 调度扩展——Scheduler Framework 详解
categories:
  - Kubernetes
tags:
  - Kubernetes
  - Scheduler
  - 调度
date: 2024-08-01 00:00:00
top: false
comments: true
draft: false
---

# 重要

Kubernetes 默认调度器 `kube-scheduler` 按 CPU/内存请求 + 节点亲和性做 Pod 放置。当需要 GPU 拓扑感知、成本优先、实时性优先等自定义调度策略时，通过 Scheduler Framework 插入自定义逻辑。

Scheduler Framework 将调度拆成多个扩展点，每个扩展点可以注册多个插件，插件之间按权重协作。

# 环境说明

- Kubernetes v1.26+

## 1.简介

Kube-scheduler 的每一个调度决策可以拆成两阶段：

| 阶段 | 操作 | 关键扩展点 |
|------|------|-----------|
| 调度周期（Scheduling Cycle） | 为 Pod 选定一个 Node | QueueSort → Filter → Score → Reserve |
| 绑定周期（Binding Cycle） | 将 Pod 绑定到选定的 Node | Permit → Bind → PostBind |

调度周期是同步串行的（一次只处理一个 Pod），绑定周期是异步并行的。

## 2.说明

### 2.1 架构总览

```text
Pod 进入调度队列
    ↓
QueueSort       →  决定 Pod 出队顺序（如按优先级排列）
    ↓
PreFilter       →  预处理 Pod Spec，计算调度周期内不变的信息
    ↓
Filter          →  过滤不满足条件的 Node（遍历所有 Node，每次调用一个插件）
    ↓
PostFilter      →  Filter 全部失败后的补救（如抢占）
    ↓
PreScore        →  Score 阶段的前置处理
    ↓
Score           →  对每个通过 Filter 的 Node 打分
    ↓
NormalizeScore  →  分数归一化（0~100）
    ↓
Reserve         →  资源预占（避免并发调度冲突）
    ↓
Permit          →  放行 / 阻塞 / 拒绝
    ↓
PreBind         →  绑定前的准备（如挂载 Volume）
    ↓
Bind            →  执行 bind 操作（写 Pod.Spec.NodeName）
    ↓
PostBind        →  绑定后的清理或通知
```

每个扩展点可以注册多个插件，调度器在每个阶段**依次调用**，Score 阶段各插件分数加权求和。

### 2.2 关键扩展点

| 扩展点 | 输入 | 输出 | 用途 |
|--------|------|------|------|
| `QueueSort` | 待调度 Pods 列表 | 排序后的队列 | 优先级调度 |
| `Filter` | Pod + Node 信息 | `Success` or `Unschedulable` | 硬件筛选（GPU 型号）、拓扑约束 |
| `Score` | Pod + Node 信息 | 0~100 分 | 成本优选、装箱率优选 |
| `Reserve` | Pod + 选定 Node | `Reserve` / `Unreserve` | GPU 拓扑感知预留 |
| `Permit` | Pod + 选定 Node | `Approve` / `Deny` / `Wait` | 等待外部条件（如 license） |
| `Bind` | Pod + 选定 Node | 绑定结果 | 自定义绑定逻辑 |

### 2.3 插件注册

```go
package myplugin

import (
    "k8s.io/kubernetes/pkg/scheduler/framework"
)

type MyScorePlugin struct{}

func (p *MyScorePlugin) Name() string {
    return "MyScorePlugin"
}

func (p *MyScorePlugin) Score(ctx context.Context, state *framework.CycleState,
    pod *v1.Pod, nodeName string) (int64, *framework.Status) {
    // 优先选择标签中有 "cost=low" 的节点
    node := state.NodeInfo.Node()
    if node.Labels["cost"] == "low" {
        return 100, nil
    }
    return 0, nil
}
```

注册插件——在 `main()` 中用 `runtime.Registry` 注册：

```go
func main() {
    command := app.NewSchedulerCommand(
        app.WithPlugin("MyScorePlugin", &MyScorePlugin{}),
    )
    command.Execute()
}
```

### 2.4 配置示例

通过 `KubeSchedulerConfiguration` 启用自定义插件并配置权重：

```yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
  - schedulerName: custom-scheduler
    plugins:
      score:
        enabled:
          - name: MyScorePlugin
            weight: 10
```

| 配置项 | 说明 |
|--------|------|
| `schedulerName` | 使用此 Profile 的 Pod 需声明 `schedulerName: custom-scheduler` |
| `enabled` | 启用插件，`disabled` 可禁用默认插件 |
| `weight` | Score 阶段权重，最终得分加权求和决定选中 Node |
| `pluginConfig` | 向插件传入自定义参数 |

### 2.5 多 Profile

一个 kube-scheduler 实例可以加载多个 Profile，每个 Profile 有自己的一套启用插件 + 配置。不同业务通过 Pod 的 `schedulerName` 字段路由到不同 Profile。

```yaml
profiles:
  - schedulerName: default-scheduler     # 默认
  - schedulerName: gpu-scheduler         # GPU 任务专用，启用拓扑感知插件
  - schedulerName: batch-scheduler       # 批处理任务，启用成本优先插件
```

## 3.总结

1. Scheduler Framework 是 K8s 调度层的扩展接口，将调度拆成多个扩展点；
2. Filter 做裁剪，Score 做优选，Permit 做阻塞控制——三者覆盖大部分自定义调度需求；
3. 多 Profile 让同一集群内不同业务使用不同调度策略，无需部署多个调度器实例。

## 4.参考

- [Kubernetes Scheduling Framework](https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/)
- [Scheduler Configuration](https://kubernetes.io/docs/reference/scheduling/config/)
