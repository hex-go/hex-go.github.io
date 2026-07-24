---
title: K8s client-go 自定义控制器实战：Service 自动注册 Consul
categories:
  - Kubernetes
tags:
  - Go
  - Kubernetes
date: 2020-05-01 00:00:00
pinned: true
---

# 重要

client-go 的核心不是 CRUD，而是 **Informer + WorkQueue + Reconcile** 这套控制器模式。

本文通过一个工作真实案例——监听 Service annotation 自动注册到 Consul——展开客户端初始化、Informer、resync、WorkQueue、Reconcile。

# 环境说明

- Go：go1.20
- client-go：v0.28.x

## 1. 客户端初始化

不管哪种方式，第一步都是拿到 kubeconfig。常见三种来源：

| 来源 | 场景 | 关键函数 |
|------|------|---------|
| 集群内 | 控制器作为 Pod 运行，自动挂载 ServiceAccount | `rest.InClusterConfig()` |
| 集群外 | 本地调试，指定 kubeconfig 文件路径 | `clientcmd.BuildConfigFromFlags("", kubeconfig)` |
| 字节流 | 平台类系统，kubeconfig 存在数据库或配置中心 | `clientcmd.RESTConfigFromKubeConfig(kubeConfig)` |

拿到 kubeconfig 后，解析出 `rest.Config`，再用它创建不同类型的 client：

| Client | 定位 | 适合操作 |
|--------|------|----------|
| Clientset | typed client，类型安全 | 内置资源：Pod、Service、Deployment 等 |
| Dynamic Client | unstructured client，弱类型 | CRD、未生成 client 的资源 |

{{< keypoint >}}
初始化不是重点，重点是后面怎么用 client-go 写一个长期运行的控制器。基础 CRUD 只做速查，真正需要理解的是 Informer、WorkQueue、Reconcile。
{{< /keypoint >}}

## 2. 基础用法速查

理解控制器之前，先看 client-go 怎么操作资源。这里只留最小示例，够用就行。

### 2.1 Clientset 操作内置资源

Clientset 是 typed client，适合操作 Kubernetes 内置资源。

```go {hl_lines=[1,5,7]}
pods, err := k.clientSet.CoreV1().Pods("default").List(context.TODO(), metav1.ListOptions{
    LabelSelector: "app=nginx",
})

pod, err := k.clientSet.CoreV1().Pods("default").Get(context.TODO(), "nginx-xxx", metav1.GetOptions{})

err = k.clientSet.CoreV1().Pods("default").Delete(context.TODO(), "nginx-xxx", metav1.DeleteOptions{})
```

更新资源时需要注意 `resourceVersion` 冲突，标准方式是 `RetryOnConflict`：

```go {hl_lines=[1,9,12]}
err := retry.RetryOnConflict(retry.DefaultRetry, func() error {
    deploy, err := k.clientSet.AppsV1().Deployments("default").
        Get(context.TODO(), "nginx", metav1.GetOptions{})
    if err != nil {
        return err
    }

    replicas := int32(3)
    deploy.Spec.Replicas = &replicas

    _, err = k.clientSet.AppsV1().Deployments("default").
        Update(context.TODO(), deploy, metav1.UpdateOptions{})
    return err
})
```

### 2.2 Dynamic Client 操作 CRD

Dynamic Client 不依赖 Go struct，只需要知道 `GroupVersionResource`。

```go {hl_lines=[1,7]}
var clusterCRD = schema.GroupVersionResource{
    Group:    "fleet.cattle.io",
    Version:  "v1alpha1",
    Resource: "clusters",
}

obj, err := d.Client.Resource(clusterCRD).Namespace("default").
    Get(context.TODO(), "demo", metav1.GetOptions{})
```

GVR 与 CRD 声明中的映射关系：

| GVR 字段 | CRD YAML 对应 | 示例 |
|---------|-------------|------|
| `Group` | `spec.group` | `fleet.cattle.io` |
| `Version` | `spec.versions[].name` | `v1alpha1` |
| `Resource` | `spec.names.plural` | `clusters` |

> 对于非 Namespace 隔离的资源（Cluster scope），去掉 `.Namespace()`：`d.Client.Resource(crd).List(context.TODO(), metav1.ListOptions{})`

## 3. Informer：控制器的数据入口

以上是操作 API Server 的基础能力。但控制器不能靠轮询活着，需要 Informer 提供持续、可靠、低成本的变更监听。

### 3.1 为什么需要 Informer

轮询 API Server 有严重问题：

- 每次请求都消耗 API Server 资源和网络带宽；
- 无法实时感知变更；
- 控制器重启后需要重新处理历史状态；
- 多个控制逻辑重复 List/Watch，容易放大 API Server 压力。

Informer 通过 List-Watch + 本地缓存 + 事件回调解决这些问题。

![自定义控制器工作流程](/images/controller-workflow.png)

### 3.2 Informer 核心组件

| 组件 | 作用 |
|------|------|
| **Reflector** | 对 API Server 执行 List & Watch，维护资源版本 |
| **DeltaFIFO** | 保存 Added / Updated / Deleted 等增量事件 |
| **Indexer** | 线程安全本地缓存，按 key 索引对象 |
| **ResourceEventHandler** | 接收 Add / Update / Delete 事件 |
| **WorkQueue** | 保存待处理 key，支持限速和失败重试 |
| **Reconcile** | 根据 key 对比期望状态和实际状态 |

<details>
<summary>数据流转全貌：oldObj / newObj 从哪里来</summary>

{{< diagram >}}
                    API Server (Etcd)
                         │
          ┌──────────────┼──────────────┐
          │ List         │ Watch        │ re-connect
          │ (启动全量)    │ (增量推送)    │ (断线续传)
          ▼              ▼              ▼
        ┌─────────────────────────────────┐
        │          Reflector              │
        │  维护 ResourceVersion 游标       │
        └──────────┬──────────────────────┘
                   │ 写入 Delta{Type, Object}
                   ▼
        ┌─────────────────────────────────┐
        │         DeltaFIFO               │
        │  Added / Updated / Deleted      │
        └──────────┬──────────────────────┘
                   │ Pop
                   ▼
        ┌─────────────────────────────────┐
        │   SharedIndexInformer 处理循环   │
        │                                 │
        │  Added:                          │
        │    → Object 写入 Indexer         │
        │    → AddFunc(Object)             │
        │                        ┌────────┤
        │  Updated (真实变更):     │        │
        │    → oldObj ← Indexer   │ 旧对象  │
        │    → newObj ← Delta     │ 新对象  │
        │    → Object 覆盖 Indexer │        │
        │    → UpdateFunc(old,new)│  RV不同 │
        │                        └────────┤
        │  Updated (resync 触发):  │        │
        │    → oldObj ← Indexer   │ 同对象  │
        │    → newObj ← Indexer   │ 同对象  │
        │    → UpdateFunc(old,new)│  RV相同 │
        │                        ┌────────┤
        │  Deleted:              │        │
        │    → 从 Indexer 删除key │        │
        │    → DeleteFunc(被删对象)│        │
        └──────────┬──────────────────────┘
                   │ ResourceEventHandler
                   ▼
        ┌─────────────────────────────────┐
        │          WorkQueue              │
        │     只存 key (namespace/name)    │
        │     同一 key 自动去重            │
        └──────────┬──────────────────────┘
                   │ Get
                   ▼
        ┌─────────────────────────────────┐
        │           Worker                │
        │  1. Lister 读期望状态(Indexer)   │
        │  2. 查实际状态(外部系统)         │
        │  3. 对比 → 新建/更新/删除/跳过   │
        └─────────────────────────────────┘
{{< /diagram >}}

| 对比项 | Watch 真实变更 | resync |
|--------|--------------|--------|
| oldObj 来源 | Indexer 中更新前的旧对象 | Indexer 当前对象 |
| newObj 来源 | Watch 事件携带的新对象 | Indexer 当前对象（同一指针） |
| ResourceVersion | old ≠ new | old == new |
| 触发条件 | Etcd 数据变化 | resyncPeriod 周期到达 |

</details>

{{< keypoint >}}
Informer 的本质：带本地缓存、事件回调、索引能力的 Kubernetes client。
{{< /keypoint >}}

### 3.3 Indexer 与 Etcd 同步

Indexer（本地缓存）通过 Reflector 的 ListAndWatch 保持与 API Server 同步，不是靠 resync。

```text
Reflector 启动
    ↓
List：全量拉取一次所有对象 → 写入 Indexer
    ↓
Watch：持续监听增量变化 → 实时更新 Indexer
    ↓
连接断开后重连：从上次的 ResourceVersion 继续 Watch
```

| 机制 | 做什么 | 数据来源 |
|------|--------|----------|
| ListAndWatch | 保证 Indexer == Etcd | API Server |
| resync | 周期性把 Indexer 对象投递给 ResourceEventHandler | 本地 Indexer |

Indexer 本身一直是最新的（靠 Watch 实时同步），resync 只是周期性多给一次触发 Reconcile 的机会，不参与数据同步逻辑。

### 3.4 ResourceEventHandler

ResourceEventHandler 的回调参数由 SharedIndexInformer 内部组装，用户代码不直接访问 DeltaFIFO 或 Indexer。

<details>
<summary>回调参数来源：SharedIndexInformer 处理循环</summary>

```text
SharedIndexInformer 处理循环（简化）：

从 DeltaFIFO Pop 一个 Delta
    ↓
Delta.Type == Added
    → 把 Delta.Object 写入 Indexer
    → 调用 AddFunc(Delta.Object)

Delta.Type == Updated
    → 从 Indexer 取 key 对应的旧对象 → oldObj
    → 把 Delta.Object 写入 Indexer（覆盖旧对象）
    → 调用 UpdateFunc(oldObj, Delta.Object)

Delta.Type == Deleted
    → 从 Indexer 删除该 key
    → 调用 DeleteFunc(被删对象)
```

| 回调 | 参数来源 |
|------|---------|
| AddFunc(obj) | obj 来自 DeltaFIFO 中的 Delta.Object |
| UpdateFunc(oldObj, newObj) | oldObj 来自 Indexer（更新前），newObj 来自 DeltaFIFO |
| DeleteFunc(obj) | obj 来自 DeltaFIFO（或被 Indexer 包装的 tombstone） |

</details>

实际控制器中，事件回调里只做一件事：把对象 key 放入 WorkQueue。

```go {hl_lines=[4,5,6,11,24,28,30,38,40]}
func main() {
    kubeClient, _ := kubernetes.NewForConfig(restConf)

    factory := informers.NewSharedInformerFactory(kubeClient, 30*time.Second)
    podInformer := factory.Core().V1().Pods()
    queue := workqueue.NewNamedRateLimitingQueue(
        workqueue.DefaultControllerRateLimiter(),
        "pod-controller",
    )

    podInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
        AddFunc: func(obj interface{}) {
            key, err := cache.MetaNamespaceKeyFunc(obj)
            if err == nil {
                queue.Add(key)
            }
        },
        UpdateFunc: func(oldObj, newObj interface{}) {
            // 若只想响应对象真实变更，可在此过滤 resync：
            // if oldObj.(*corev1.Pod).ResourceVersion == newObj.(*corev1.Pod).ResourceVersion { return }

            key, err := cache.MetaNamespaceKeyFunc(newObj)
            if err == nil {
                queue.Add(key)
            }
        },
        DeleteFunc: func(obj interface{}) {
            key, err := cache.DeletionHandlingMetaNamespaceKeyFunc(obj)
            if err == nil {
                queue.Add(key)
            }
        },
    })

    stopCh := make(chan struct{})
    defer close(stopCh)

    factory.Start(stopCh)

    if !cache.WaitForCacheSync(stopCh, podInformer.Informer().HasSynced) {
        panic("wait cache sync failed")
    }

    <-stopCh
}
```

需要注意：

| 点 | 说明 |
|----|------|
| `factory.Start()` | 启动所有已创建的 Informer |
| `WaitForCacheSync()` | 必须等待缓存同步完成后再启动 worker |
| `ResourceVersion` | 若只需响应对象真实变更，可选过滤 resync 事件 |
| `DeletionHandlingMetaNamespaceKeyFunc()` | 能处理删除事件中的 tombstone 对象 |

### 3.5 Lister：从缓存读取

Informer 自带 Lister，读取操作直接走本地缓存，**不经过 API Server**：

```go {hl_lines=[1,4,7]}
pod, err := podInformer.Lister().Pods("default").Get("nginx-xxx")

// 从缓存列出所有 Pod
pods, err := podInformer.Lister().List(labels.Everything())

// 带 Selector 过滤
pods, err := podInformer.Lister().Pods("default").List(labels.Set{
    "app": "nginx",
}.AsSelector())
```

> Lister 读取的是缓存快照，可能存在短暂延迟（取决于 resync interval）。对实时性要求高的场景应直接从回调处理。

### 3.6 自定义控制器模式

Informer + WorkQueue + Reconcile 组合是 Operator 的标准结构：

{{< diagram >}}
事件回调
    ↓ 放入 key
WorkQueue
    ↓ worker 取出 key
Lister 读取期望状态
    ↓
Reconcile 对比实际状态
    ↓
执行创建 / 更新 / 删除 / 跳过
{{< /diagram >}}

Reconcile 不应该强依赖事件类型。Add / Update / Delete 只是触发一次对账，真正动作由“期望状态”和“实际状态”的差异决定。

### 3.7 resync 与 ResourceVersion

`resyncPeriod` 容易误解。它不是重新 List 全量数据，也不是强制刷新所有对象。

<details>
<summary>resyncPeriod 在代码中如何体现</summary>

`resyncPeriod` 就是 `SharedInformerFactory` 的构造函数第二个参数：

```go
factory := informers.NewSharedInformerFactory(kubeClient, 30*time.Second)
//                                                       ↑ resyncPeriod
```

含义：

| 设定 | 效果 |
|------|------|
| `30*time.Second` | 每 30 秒，Informer 遍历本地缓存中的对象，以 `Update` 事件的形式投递给 ResourceEventHandler |
| `0` | 不做周期性 resync，只响应 Watch 事件 |
| 设为 `0` 的场景 | 控制器只关心 API 对象变化，不存在外部状态漂移 |
| 设为正值的场景 | 控制器依赖外部系统，需要周期性对比期望状态和实际状态 |

resync 触发的是 `UpdateFunc`，且新旧对象的 `ResourceVersion` 相同。所以可以这样过滤：

```go
if oldObj.ResourceVersion == newObj.ResourceVersion {
    return
}
```

但如果控制器依赖外部系统（如 Consul、数据库等），过滤掉 resync 事件会失去兜底能力。具体选择要看控制器是否需要处理外部状态漂移。

</details>

在 Informer 语义里，resync 的作用是：周期性把缓存里的对象重新投递给事件处理逻辑，触发一次同步机会。

常见用途：

- 外部系统状态被人工修改；
- 上一次 Reconcile 失败但事件丢失；
- 控制器逻辑升级后需要重新计算状态；
- Kubernetes 对象没有变化，但实际状态已经漂移。

<details>
<summary>resync 触发的 Update 事件：oldObj 与 newObj 从哪来</summary>

先看真实 Watch 变更时的流程：

```text
Etcd 中 Pod 被更新
    ↓
API Server Watch 推送事件（携带新 Pod {ResourceVersion: "100"}）
    ↓
Reflector 包装为 Updated Delta → DeltaFIFO
    ↓
Informer Pop 取出 Delta
    1. 从 Indexer 取出旧 Pod {ResourceVersion: "99"} → oldObj
    2. 从 Delta 取出新 Pod {ResourceVersion: "100"} → newObj
    3. 把 newObj 写入 Indexer（覆盖旧版本）
    4. 调用 UpdateFunc(oldObj, newObj)
```

resync 时：

```text
Informer 遍历 Indexer 中所有对象
    ↓
对每个对象，构造 Updated Delta（内含同一个对象指针）
    ↓
Informer Pop 取出 Delta
    1. 从 Indexer 取 → oldObj（同指针）
    2. 从 Delta 取 → newObj（同指针）
    3. oldObj == newObj，ResourceVersion 必然相等
    4. 调用 UpdateFunc(oldObj, newObj)
```

| 场景 | oldObj 来源 | newObj 来源 | ResourceVersion |
|------|------------|------------|-----------------|
| Watch 真实变更 | Indexer 中更新前的旧对象 | Watch 事件携带的新对象 | 不同 |
| resync | Indexer 当前对象 | Indexer 当前对象（同一个） | 相同 |

</details>

{{< keypoint >}}
resyncPeriod 解决的是“没有新的 K8S 事件，但外部实际状态可能已经偏离期望状态”的问题。
{{< /keypoint >}}

resync 可能触发 UpdateFunc，但对象本身没有变化，所以常见过滤方式如下：

```go {hl_lines=[1]}
if oldPod.ResourceVersion == newPod.ResourceVersion {
    return
}
```

需要注意的是，`ResourceVersion` 只能说明 API 对象版本是否变化，不能说明外部系统状态是否变化。如果控制器依赖外部系统状态，不建议简单过滤所有 resync 事件。

{{< keypoint >}}
控制器不应该“响应事件做动作”，而应该“借事件触发一次状态对账”。
{{< /keypoint >}}

## 4. WorkQueue与Reconcile：事件→动作

Informer 负责接收事件，WorkQueue + Reconcile 负责把事件变成具体的业务动作。

### 4.1 WorkQueue：为什么只放 key

Informer 负责监听变化，WorkQueue 负责削峰、去重、失败重试。

| 队列 | 场景 |
|------|------|
| `workqueue.Interface` | 普通队列，无重试能力 |
| `workqueue.DelayingInterface` | 支持延迟入队 |
| `workqueue.RateLimitingInterface` | 控制器常用，支持限速重试 |

控制器一般使用：

```go {hl_lines=[1]}
queue := workqueue.NewNamedRateLimitingQueue(
    workqueue.DefaultControllerRateLimiter(),
    "pod-controller",
)
```

Add、Update、Delete 以及 resync 触发的事件回调，全都只做同一件事：取出对象的 `namespace/name`，放入 WorkQueue。

删除事件也放入 key 的原因是：工作队列本质上就是一个“需要调谐的对象 ID 列表”。同一 key 多次入队会被去重，增删改只触发同一套 Reconcile 逻辑。

真正的处理在 handler 中：先从 Lister 读取期望状态，如果读不到就去实际系统中删除，如果能读到再按属性对比决定新建、更新还是删除。

| 原因 | 说明 |
|------|------|
| 避免对象过期 | 队列里的对象可能已经不是最新版本 |
| 降低内存占用 | key 比完整对象小很多 |
| 合并重复事件 | 多次操作同一个对象，队列中只会保留一个 key |
| 统一处理逻辑 | 增删改都只触发同一个 Reconcile handler |

工作流程：

{{< diagram >}}
事件对象 Pod
    ↓ MetaNamespaceKeyFunc
key: default/nginx
    ↓ 入队
WorkQueue
    ↓ 出队
Lister 从缓存读取最新对象
    ↓
Reconcile
{{< /diagram >}}

### 4.2 Reconcile 基本结构

Reconcile 的目标是让实际状态不断逼近期望状态，它是控制器模式的最后一步。

一个完整的 Reconcile 流程：

{{< diagram >}}
从 WorkQueue 取出 key
    ↓
Lister 读取期望状态
    ↓
对象不存在 → 清理外部系统
    ↓
对象存在 → 查询实际状态
    ↓
对比差异 → 创建 / 更新 / 跳过
{{< /diagram >}}

Reconcile 的核心原则：只关心“当前应该是什么”和“当前实际是什么”，不关心事件是怎么来的。

以上是控制器开发的核心概念。下面通过真实案例举例实现。

## 5. 实战案例：监听 Service 注册到 Consul

### 5.1 设计目标

生产环境中，部分服务需要同步注册到 Consul，不能要求业务方手动维护两套服务发现配置。

更合理的方式是：业务方只在 Service 上声明 annotation，控制器监听 Service 变化后自动完成 Consul 注册。

在本案例中，三种状态的定义：

| 角色 | 来源 | 说明 |
|------|------|------|
| 期望状态 | Service annotation + spec | `enabled=true`、服务名、端口、Tags |
| 实际状态 | Consul 当前服务列表 | 是否已注册、字段是否一致 |
| 调协动作 | 控制器执行 | 注册 / 更新 / 注销 |

resync 在本案例中的作用——兜底修正外部系统漂移：

| 情况 | K8S 有事件 | 是否需要 resync 兜底 | 说明 |
|------|-----------|----------------------|------|
| Service 新增/更新/删除 | 是 | 否 | 事件触发 Reconcile |
| Consul 中服务被人工删除 | 否 | 是 | 期望状态没变，实际状态漂移 |
| Consul 中端口/Tag 被人工改错 | 否 | 是 | 同上 |
| 上一次注册 Consul 失败 | 不一定 | 是 | WorkQueue 先重试，resync 周期性兜底 |

{{< diagram >}}
Service Annotation
    ↓
Service Informer
    ↓
WorkQueue(namespace/name)
    ↓
Reconcile
    ↓
解析 ServiceName / Port / Tags
    ↓
注册或注销 Consul Service
{{< /diagram >}}

### 5.2 Annotation 约定

示例 Service：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: default
  annotations:
    discovery.example.com/enabled: "true"
    discovery.example.com/name: "order-service"
    discovery.example.com/port: "8080"
    discovery.example.com/tags: "go,http,prod"
spec:
  selector:
    app: order-service
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

Annotation 设计：

| Annotation | 说明 | 是否必填 |
|------------|------|----------|
| `discovery.example.com/enabled` | 是否注册到 Consul | 是 |
| `discovery.example.com/name` | 注册到 Consul 的服务名 | 否，默认使用 Service 名称 |
| `discovery.example.com/port` | 注册端口 | 否，默认取 Service 第一个端口 |
| `discovery.example.com/tags` | Consul tags | 否 |

### 5.3 核心数据结构

控制器内部不直接传递 Kubernetes Service，而是转换成内部模型，避免业务逻辑和 K8S API 强绑定。

```go {hl_lines=[1,6]}
type ServiceRegistration struct {
    ID        string
    Name      string
    Namespace string
    Address   string
    Port      int
    Tags      []string
}
```

Controller 结构如下：

```go {hl_lines=[5,8,9]}
type Controller struct {
    serviceLister corev1listers.ServiceLister
    serviceSynced cache.InformerSynced
    queue         workqueue.RateLimitingInterface
    consul        ConsulRegistry
}

type ConsulRegistry interface {
    Register(ctx context.Context, svc ServiceRegistration) error
    Deregister(ctx context.Context, id string) error
}
```

这样做有两个好处：

| 设计 | 作用 |
|------|------|
| `ServiceRegistration` | 屏蔽 Kubernetes 原始对象细节 |
| `ConsulRegistry` interface | 方便 mock 测试，避免控制器强依赖 Consul SDK |

### 5.4 事件入队

事件回调只负责入队，不直接调用 Consul。

```go {hl_lines=[2,6,10,14]}
func (c *Controller) enqueue(obj interface{}) {
    key, err := cache.MetaNamespaceKeyFunc(obj)
    if err != nil {
        return
    }
    c.queue.Add(key)
}

func (c *Controller) enqueueDelete(obj interface{}) {
    key, err := cache.DeletionHandlingMetaNamespaceKeyFunc(obj)
    if err != nil {
        return
    }
    c.queue.Add(key)
}
```

注册事件处理：

```go {hl_lines=[1,3,7,9]}
serviceInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
    AddFunc: c.enqueue,
    UpdateFunc: func(oldObj, newObj interface{}) {
        c.enqueue(newObj)
    },
    DeleteFunc: c.enqueueDelete,
})
```

### 5.5 解析 Service Annotation

```go {hl_lines=[2,3,4,5,9,10,14,19,24,28,29,30]}
const (
    annEnabled = "discovery.example.com/enabled"
    annName    = "discovery.example.com/name"
    annPort    = "discovery.example.com/port"
    annTags    = "discovery.example.com/tags"
)

func buildRegistration(svc *corev1.Service) (ServiceRegistration, bool, error) {
    annotations := svc.GetAnnotations()
    if annotations[annEnabled] != "true" {
        return ServiceRegistration{}, false, nil
    }

    name := annotations[annName]
    if name == "" {
        name = svc.Name
    }

    port, err := resolvePort(svc, annotations[annPort])
    if err != nil {
        return ServiceRegistration{}, false, err
    }

    return ServiceRegistration{
        ID:        svc.Namespace + "/" + svc.Name,
        Name:      name,
        Namespace: svc.Namespace,
        Address:   svc.Name + "." + svc.Namespace + ".svc.cluster.local",
        Port:      port,
        Tags:      splitTags(annotations[annTags]),
    }, true, nil
}
```

端口解析：

```go {hl_lines=[2,10,14]}
func resolvePort(svc *corev1.Service, raw string) (int, error) {
    if raw != "" {
        port, err := strconv.Atoi(raw)
        if err != nil {
            return 0, err
        }
        return port, nil
    }

    if len(svc.Spec.Ports) == 0 {
        return 0, fmt.Errorf("service has no ports")
    }

    return int(svc.Spec.Ports[0].Port), nil
}
```

### 5.6 Reconcile 注册逻辑

```go {hl_lines=[7,8,9,15,20,21,24]}
func (c *Controller) syncHandler(ctx context.Context, key string) error {
    namespace, name, err := cache.SplitMetaNamespaceKey(key)
    if err != nil {
        return err
    }

    svc, err := c.serviceLister.Services(namespace).Get(name)
    if errors.IsNotFound(err) {
        return c.consul.Deregister(ctx, key)
    }
    if err != nil {
        return err
    }

    registration, enabled, err := buildRegistration(svc)
    if err != nil {
        return err
    }

    if !enabled {
        return c.consul.Deregister(ctx, key)
    }

    return c.consul.Register(ctx, registration)
}
```

这段逻辑体现了 Reconcile 的核心：

| 场景 | 动作 |
|------|------|
| Service 被删除 | 从 Consul 注销 |
| annotation 关闭 | 从 Consul 注销 |
| annotation 开启 | 注册或更新 Consul 服务 |
| Service 端口变化 | 重新注册 Consul 服务 |

<details>
<summary>Reconcile 如何判断新增、更新、删除</summary>

Informer 接收到 Add / Update / Delete 事件后都做同一件事：把对象的 `namespace/name` 放入 WorkQueue。同一个 key 多次入队会被去重，队列里只保留一份。工作队列本质上就是一个“需要调谐的对象 ID 列表”，不区分事件类型。

Worker 从队列取出 key 后进入 Reconcile：

```text
从 Lister 读取期望状态（Service）
    ↓
如果读不到 → 实际中删除该服务（注销 Consul）
    ↓
如果读到了 → 继续判断
    ↓
对比期望状态（annotations/spec）和实际状态（Consul）
    ↓
不存在 → 新建
属性不一致 → 更新
一致 → 跳过
```

<table>
<tr><th>队列事件</th><th>Lister 读取期望状态</th><th>查询实际状态</th><th>Reconcile 动作</th></tr>
<tr><td>Add / Update / Delete / resync</td><td>能读到 Service</td><td>Consul 不存在</td><td>注册服务</td></tr>
<tr><td>Add / Update / Delete / resync</td><td>能读到 Service</td><td>Consul 已存在但字段不同</td><td>更新注册</td></tr>
<tr><td>Add / Update / Delete / resync</td><td>能读到 Service</td><td>Consul 已存在且一致</td><td>跳过</td></tr>
<tr><td>Delete</td><td>Lister 读不到 Service</td><td>Consul 存在</td><td>注销服务</td></tr>
<tr><td>Add / Update / resync</td><td>能读到 Service，但 annotation 关闭</td><td>Consul 存在</td><td>注销服务</td></tr>
</table>

核心原则：Add / Update / Delete 事件不直接决定动作，只是把 key 放进队列。真正动作由 Reconcile 读取最新期望状态 + 查询实际状态后判断。

</details>

### 5.7 Consul 注册实现

Consul SDK 细节可以封装在 adapter 中，控制器只依赖接口。

```go {hl_lines=[6,7,8,9,10,11,12,13,21]}
type ConsulClient struct {
    client *api.Client
}

func (c *ConsulClient) Register(ctx context.Context, svc ServiceRegistration) error {
    return c.client.Agent().ServiceRegister(&api.AgentServiceRegistration{
        ID:      svc.ID,
        Name:    svc.Name,
        Address: svc.Address,
        Port:    svc.Port,
        Tags:    svc.Tags,
        Check: &api.AgentServiceCheck{
            TCP:      fmt.Sprintf("%s:%d", svc.Address, svc.Port),
            Interval: "10s",
            Timeout:  "3s",
        },
    })
}

func (c *ConsulClient) Deregister(ctx context.Context, id string) error {
    return c.client.Agent().ServiceDeregister(id)
}
```

### 5.8 生产环境最佳实践

| 实践 | 说明 |
|------|------|
| 事件只入队 | Add/Update/Delete 不直接访问 Consul |
| key 作为队列元素 | 避免对象过期，支持事件合并 |
| Lister 读缓存 | Reconcile 时读取最新期望状态 |
| 失败限速重试 | Consul 短暂不可用时避免打爆外部系统 |
| 删除走 Deregister | Lister NotFound 代表期望状态已删除 |
| annotation 做开关 | 业务方通过声明式配置控制是否注册 |
| SDK 做接口隔离 | 控制器逻辑可单测，Consul 实现可替换 |
| 指标和日志 | 记录注册成功、失败、重试、注销次数 |

### 5.9 部署形态与 RBAC 配置

上述代码本质上是一个**自定义控制器（Custom Controller）**，不是 Operator。区别在于：它监听的是 K8S 内置的 Service 资源，没有定义 CRD。

控制器以 Deployment 方式运行在集群中，需要 RBAC 授权才能访问 Service：

**ServiceAccount**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: service-discovery-controller
  namespace: default
```

**ClusterRole** — 只读 Service

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: service-discovery-controller
rules:
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch"]
```

**ClusterRoleBinding**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: service-discovery-controller
subjects:
  - kind: ServiceAccount
    name: service-discovery-controller
    namespace: default
roleRef:
  kind: ClusterRole
  name: service-discovery-controller
  apiGroup: rbac.authorization.k8s.io
```

**Deployment** — 使用内置 ServiceAccount

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-discovery-controller
spec:
  replicas: 1
  selector:
    matchLabels:
      app: service-discovery-controller
  template:
    metadata:
      labels:
        app: service-discovery-controller
    spec:
      serviceAccountName: service-discovery-controller
      containers:
        - name: controller
          image: service-discovery-controller:latest
          env:
            - name: CONSUL_ADDR
              value: "consul:8500"
```

控制器以 Pod 方式运行后，通过 `rest.InClusterConfig()` 自动加载 ServiceAccount 的认证信息，无需手动传入 kubeconfig。

## 6. 补充：错误处理与重试

以下几个错误处理模式适用于基础 CRUD 和控制器开发，生产中常用。

### 6.1 冲突重试（RetryOnConflict）

更新资源时最常遇到 `Conflict` 错误（resourceVersion 冲突）。`retry.RetryOnConflict` 检测到 `Conflict` 后会重新执行整个闭包——重新 Get 拿最新版本、修改、再 Update：

```go {hl_lines=[1]}
err := retry.RetryOnConflict(retry.DefaultRetry, func() error {
    deploy, err := k.clientSet.AppsV1().Deployments("default").
        Get(context.TODO(), "my-app", metav1.GetOptions{})
    if err != nil {
        return err
    }

    deploy.Spec.Replicas = ptr.To(int32(5))

    _, err = k.clientSet.AppsV1().Deployments("default").
        Update(context.TODO(), deploy, metav1.UpdateOptions{})
    return err
})
```

### 6.2 指数退避

指数退避是指每次重试的等待时间是上一次的倍数，而非固定间隔。

<details>
<summary>重试间隔计算</summary>

```text
第1次失败 → 等待 1s 重试
第2次失败 → 等待 2s 重试
第3次失败 → 等待 4s 重试
第4次失败 → 等待 8s 重试
第5次失败 → 等待 16s（被 Cap=60s 限制，实际最多等 60s）
```

`Factor: 2.0` 控制倍率，`Steps: 5` 控制最大重试次数，`Cap: 60s` 是等待上限。

作用：避免异常对象瞬间打爆 API Server 或外部系统，同时给故障恢复留出时间窗口。

</details>

```go {hl_lines=[2,4,6,10,14,19]}
// 指数退避：初始 1s，最大 60s，步长 2x
backoff := wait.Backoff{
    Duration: 1 * time.Second,
    Factor:   2.0,
    Jitter:   0.1,
    Steps:    5,
    Cap:      60 * time.Second,
}

err := wait.ExponentialBackoff(backoff, func() (bool, error) {
    pod, err := k.clientSet.CoreV1().Pods("default").
        Get(context.TODO(), "my-pod", metav1.GetOptions{})
    if err != nil {
        return false, nil // 继续重试
    }
    if pod.Status.Phase != corev1.PodRunning {
        return false, nil // 未到目标状态，继续等
    }
    return true, nil // 成功，停止重试
})
```

### 6.3 连接恢复与健康检查

```go {hl_lines=[3]}
// 可以通过 discovery API 做健康检查
func (k *K8S) HealthCheck() error {
    _, err := k.clientSet.Discovery().ServerVersion()
    return err
}
```

## 7. 总结

| 模块 | 定位 | 重点 |
|------|------|------|
| Clientset | typed client | 适合内置资源的简单 CRUD |
| Dynamic Client | unstructured client | 适合无代码生成场景下操作 CRD |
| Informer | 控制器基础设施 | List-Watch、本地缓存、事件回调 |
| Lister | 缓存读取入口 | 从 Indexer 读取对象，减少 API Server 请求 |
| WorkQueue | 异步处理队列 | 去重、削峰、限速、失败重试 |
| Reconcile | 控制器核心逻辑 | 对比期望状态与实际状态 |
| Service Informer | 实战入口 | 监听 Service annotation，驱动 Consul 注册 |
| Consul Registry | 外部系统适配层 | 注册、更新、注销服务发现记录 |

client-go 基础 API 能完成资源操作，但控制器开发的重点是 Informer 机制。真正稳定的控制器不应该按事件类型硬编码动作，而应该通过 WorkQueue 触发 Reconcile，对期望状态和实际状态持续对账。

Service 注册 Consul 的案例中，Service annotation 是期望状态，Consul 服务列表是实际状态，控制器只负责持续对账：该注册就注册，该更新就更新，该删除就注销。

本文的控制器和 Operator 的本质区别只有一点：Operator 多了一层 CRD，控制器监听的是自定义资源；本文监听的是 Kubernetes 内置的 Service 资源，通过 annotation 扩展语义。底层的 Informer + WorkQueue + Reconcile 机制完全一样。

Informer + WorkQueue 的组合是编写 Operator / Controller 的标准范式，完整示例见 [Operator 文章](/posts/kubernetes/2023-10-01-k8s扩展-operator/)。

# 参考链接

- [client-go 官方示例](https://github.com/kubernetes/client-go/tree/master/examples)
- [client-go 源码分析](https://www.huweihuang.com/kubernetes-notes/develop/client-go.html)
- [Sample Controller（Informer 标准模板）](https://github.com/kubernetes/sample-controller)
- [Dynamic Client 操作 CRD](https://mozillazg.com/2020/07/k8s-kubernetes-client-go-list-get-create-update-patch-delete-crd-resource-without-generate-client-code-update-or-create-via-yaml.html)
