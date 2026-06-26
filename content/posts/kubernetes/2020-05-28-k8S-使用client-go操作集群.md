---
title: k8S-使用client-go操作集群
categories:
  - Kubernetes
tags:
  - Go
  - Kubernetes
date: 2020-05-01 00:00:00
pinned: true
---

# 重要

client-go 是 K8S 官方 Go 客户端库，几乎所有 Go 写的 K8S 工具/Operator 底层都是它。

本文按实战需求渐近展开：客户端初始化 → 内置资源 CRUD → Dynamic Client 操作 CRD → Informer 模式 → 错误处理与重试。每步附实际可用代码。

# 环境说明

- Go：go1.20
- client-go：v0.28.x

## 1. 客户端初始化

client-go 提供两类客户端：
- **Clientset**：类型安全的客户端，操作内置资源（Pod、Deployment、Service 等）
- **Dynamic Client**：操作任意 CRD 资源，返回 `Unstructured` 对象

初始化有三种方式：

| 方式 | 场景 | 关键函数 |
|------|------|---------|
| 集群内 | 代码作为 Pod 运行在 K8S 里 | `rest.InClusterConfig()` |
| 集群外 | 本地开发调试 | `clientcmd.BuildConfigFromFlags("", kubeconfig)` |
| 字节流 | 从数据库/API 接收 kubeconfig 字符串 | `clientcmd.RESTConfigFromKubeConfig(kubeConfig)` |

### 1.1 字节流初始化 Clientset（推荐封装）

```go
import (
    "k8s.io/client-go/rest"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/tools/clientcmd"
)

type K8S struct {
    clientSet *kubernetes.Clientset
}

func (k *K8S) Connect(kubeConfig []byte) (err error) {
    restConf, err := clientcmd.RESTConfigFromKubeConfig(kubeConfig)
    if err != nil {
        return fmt.Errorf("parse kubeconfig: %w", err)
    }
    k.clientSet, err = kubernetes.NewForConfig(restConf)
    if err != nil {
        return fmt.Errorf("create clientset: %w", err)
    }
    return nil
}
```

### 1.2 Dynamic Client 初始化

用于操作 CRD 资源，不需要代码生成：

```go
import (
    "k8s.io/client-go/dynamic"
    "k8s.io/client-go/tools/clientcmd"
)

type DynamicClient struct {
    Client dynamic.Interface
}

func (d *DynamicClient) Connect(kubeConfig []byte) error {
    restConf, err := clientcmd.RESTConfigFromKubeConfig(kubeConfig)
    if err != nil {
        return err
    }
    d.Client, err = dynamic.NewForConfig(restConf)
    return err
}
```

### 1.3 校验 kubeconfig 可用性

```go
import (
    "k8s.io/client-go/tools/clientcmd"
    clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

func ParseConf(kubeConfig []byte) (clientcmdapi.Config, error) {
    restConf, err := clientcmd.NewClientConfigFromBytes(kubeConfig)
    if err != nil {
        return clientcmdapi.Config{}, err
    }
    return restConf.RawConfig()
}
```

## 2. 操作内置资源（Clientset）

### 2.1 根据 Deployment/StatefulSet 获取 Pods

通过 Label Selector 精确匹配：

```go
import (
    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/labels"
)

func (k *K8S) PodGetByStatefulSet(namespace string, sts appsv1.StatefulSet) ([]corev1.Pod, error) {
    labelMap := sts.ObjectMeta.GetLabels()
    selector := labels.SelectorFromSet(labelMap)

    pods, err := k.clientSet.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{
        LabelSelector: selector.String(),
    })
    if err != nil {
        return nil, err
    }
    // 返回指针切片，避免大对象拷贝
    result := make([]corev1.Pod, 0, len(pods.Items))
    for _, pod := range pods.Items {
        result = append(result, pod)
    }
    return result, nil
}
```

### 2.2 根据 Job 获取 Pods

Job 的 Pod 通过 `job-name` + `controller-uid` 标签关联：

```go
func (k *K8S) PodGetByJob(namespace string, job batchv1.Job) ([]corev1.Pod, error) {
    labelMap := map[string]string{
        "job-name":       job.ObjectMeta.Name,
        "controller-uid": string(job.ObjectMeta.UID),
    }
    selector := labels.SelectorFromSet(labelMap)

    pods, err := k.clientSet.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{
        LabelSelector: selector.String(),
    })
    if err != nil {
        return nil, err
    }
    result := make([]corev1.Pod, 0, len(pods.Items))
    for _, pod := range pods.Items {
        result = append(result, pod)
    }
    return result, nil
}
```

### 2.3 获取容器日志

```go
func (k *K8S) PodLogs(namespace, name string) (string, error) {
    req := k.clientSet.CoreV1().Pods(namespace).GetLogs(name, &corev1.PodLogOptions{})
    stream, err := req.Stream(context.TODO())
    if err != nil {
        return "", err
    }
    defer stream.Close()

    buf := new(bytes.Buffer)
    if _, err := io.Copy(buf, stream); err != nil {
        return "", err
    }
    return buf.String(), nil
}
```

## 3. Dynamic Client 操作 CRD

操作 CRD 不需要代码生成，只需定义 `GroupVersionResource` 定位资源。

### 3.1 定义 Schema 定位符

```go
var clusterCRD = schema.GroupVersionResource{
    Group:    "fleet.cattle.io",
    Version:  "v1alpha1",
    Resource: "clusters",
}
```

对应 CRD 声明中的映射关系：

| GVR 字段 | CRD YAML 对应 | 示例 |
|---------|-------------|------|
| `Group` | `spec.group` | `fleet.cattle.io` |
| `Version` | `spec.versions[].name` | `v1alpha1` |
| `Resource` | `spec.names.plural` | `clusters` |

### 3.2 List / Get / Delete 操作

```go
// List 查询
func (d *DynamicClient) ListClusters(namespace string) (*fleet.ClusterList, error) {
    list, err := d.Client.Resource(clusterCRD).Namespace(namespace).
        List(context.TODO(), metav1.ListOptions{})
    if err != nil {
        return nil, err
    }
    data, _ := list.MarshalJSON()
    var clusters fleet.ClusterList
    json.Unmarshal(data, &clusters)
    return &clusters, nil
}

// Get 单个
func (d *DynamicClient) GetCluster(namespace, name string) (*fleet.Cluster, error) {
    obj, err := d.Client.Resource(clusterCRD).Namespace(namespace).
        Get(context.TODO(), name, metav1.GetOptions{})
    if err != nil {
        return nil, err
    }
    data, _ := obj.MarshalJSON()
    var cluster fleet.Cluster
    json.Unmarshal(data, &cluster)
    return &cluster, nil
}

// Delete 删除
func (d *DynamicClient) DelCluster(namespace, name string) error {
    policy := metav1.DeletePropagationForeground
    return d.Client.Resource(clusterCRD).Namespace(namespace).
        Delete(context.TODO(), name, metav1.DeleteOptions{
            PropagationPolicy: &policy,
        })
}
```

> 对于非 Namespace 隔离的资源（Cluster scope），去掉 `.Namespace()`：`d.Client.Resource(crd).List(context.TODO(), metav1.ListOptions{})`

### 3.3 Create（从 YAML 字符串）

```go
import (
    "k8s.io/apimachinery/pkg/runtime/serializer/yaml"
    "k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

func (d *DynamicClient) CreateFromYAML(namespace string, yamlStr string) error {
    decoder := yaml.NewDecodingSerializer(unstructured.UnstructuredJSONScheme)
    obj := &unstructured.Unstructured{}
    _, gvk, err := decoder.Decode([]byte(yamlStr), nil, obj)
    if err != nil {
        return fmt.Errorf("decode yaml: %w", err)
    }

    gvr := schema.GroupVersionResource{
        Group:    gvk.Group,
        Version:  gvk.Version,
        Resource: strings.ToLower(gvk.Kind) + "s",
    }

    _, err = d.Client.Resource(gvr).Namespace(namespace).
        Create(context.TODO(), obj, metav1.CreateOptions{})
    return err
}
```

> YAML 解析必须用 `k8s.io/apimachinery/pkg/runtime/serializer/yaml`，标准库的 `gopkg.in/yaml` 解析 K8S 嵌套对象会丢失类型信息。

## 4. Informer 模式

本章是 P2 核心补充——**Informer 是所有 K8S 控制器的基石**。

### 4.1 为什么需要 Informer

轮询 API Server 有严重问题：
- 每次请求都消耗 API Server 资源和网络带宽
- 无法实时感知变更
- 控制器重启后丢失历史事件

Informer 通过 List-Watch + 本地缓存 + 事件回调解决这个问题的完整示意图见 [Operator 文章 §3.2](/posts/kubernetes/k8s扩展-operator/#32-informer-机制)。

### 4.2 SharedInformerFactory

client-go 提供了 SharedInformerFactory，它创建的 Informer 在同一个进程中共享底层连接和缓存，避免重复 List-Watch：

```go
import (
    "k8s.io/client-go/informers"
    "time"
)

func main() {
    kubeClient, _ := kubernetes.NewForConfig(restConf)

    // 创建共享 Informer 工厂，每 30 秒全量同步一次
    factory := informers.NewSharedInformerFactory(kubeClient, 30*time.Second)

    // 获取 Pod Informer
    podInformer := factory.Core().V1().Pods()

    // 注册事件回调
    podInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
        AddFunc: func(obj interface{}) {
            pod := obj.(*corev1.Pod)
            fmt.Printf("Pod Added: %s/%s\n", pod.Namespace, pod.Name)
        },
        UpdateFunc: func(oldObj, newObj interface{}) {
            newPod := newObj.(*corev1.Pod)
            fmt.Printf("Pod Updated: %s/%s [%s]\n",
                newPod.Namespace, newPod.Name, newPod.Status.Phase)
        },
        DeleteFunc: func(obj interface{}) {
            pod := obj.(*corev1.Pod)
            fmt.Printf("Pod Deleted: %s/%s\n", pod.Namespace, pod.Name)
        },
    })

    // 启动所有 Informer（后台 goroutine）
    stopCh := make(chan struct{})
    defer close(stopCh)
    factory.Start(stopCh)

    // 等待缓存同步完成
    if !cache.WaitForCacheSync(stopCh,
        podInformer.Informer().HasSynced) {
        panic("Failed to sync cache")
    }

    // 后续可以直接用 Lister 从缓存读取，不查 API Server
    pods, _ := podInformer.Lister().Pods("default").List(labels.Everything())
    fmt.Printf("Total pods in default: %d\n", len(pods))

    <-stopCh
}
```

### 4.3 Informer 核心组件

| 组件 | 作用 |
|------|------|
| **Reflector** | 通过 List & Watch 从 API Server 获取数据，写入 DeltaFIFO |
| **DeltaFIFO** | 缓存对象变更事件（Added/Updated/Deleted），先进先出 |
| **Indexer** | 线程安全的本地缓存，按 key 索引，避免反复查 API Server |
| **Informer** | 从 DeltaFIFO 取事件 → 回调通知 → 写入 WorkQueue |

### 4.4 Lister：从缓存读取

Informer 自带 Lister，读取操作直接走本地缓存，**不经过 API Server**：

```go
// 从缓存获取单个 Pod（无 API Server 调用）
pod, err := podInformer.Lister().Pods("default").Get("nginx-xxx")

// 从缓存列出所有 Pod
pods, err := podInformer.Lister().List(labels.Everything())

// 带 Selector 过滤
pods, err := podInformer.Lister().Pods("default").List(labels.Set{
    "app": "nginx",
}.AsSelector())
```

> Lister 读取的是缓存快照，可能存在短暂延迟（取决于 resync interval）。对实时性要求高的场景应直接从回调处理。

### 4.5 自定义控制器模式

Informer + WorkQueue + Reconcile 组合是 Operator 的标准结构：

```go
type Controller struct {
    indexer  cache.Indexer
    queue    workqueue.RateLimitingInterface
    informer cache.Controller
}

func (c *Controller) Run(stopCh chan struct{}) {
    go c.informer.Run(stopCh)           // 启动 Informer
    cache.WaitForCacheSync(stopCh, c.informer.HasSynced)

    for i := 0; i < 2; i++ {             // 启动 2 个 worker
        go wait.Until(c.runWorker, time.Second, stopCh)
    }
    <-stopCh
}

func (c *Controller) runWorker() {
    for c.processNextItem() {
    }
}

func (c *Controller) processNextItem() bool {
    key, quit := c.queue.Get()
    defer c.queue.Done(key)

    err := c.reconcile(key.(string))
    if err != nil {
        // 失败重试，指数退避，最多重试 5 次
        c.queue.AddRateLimited(key)
    } else {
        c.queue.Forget(key)
    }
    return true
}
```

## 5. 错误处理与重试

### 5.1 冲突重试（RetryOnConflict）

更新资源时最常遇到 `Conflict` 错误（其他人同时修改了同一对象）。标准做法是在闭包内 Get → 修改 → Update，冲突时自动重试：

```go
import (
    "k8s.io/client-go/util/retry"
)

err := retry.RetryOnConflict(retry.DefaultRetry, func() error {
    // 1. 获取最新版本
    deploy, err := k.clientSet.AppsV1().Deployments("default").
        Get(context.TODO(), "my-app", metav1.GetOptions{})
    if err != nil {
        return err
    }

    // 2. 修改
    deploy.Spec.Replicas = ptr.To(int32(5))

    // 3. 更新（如果版本冲突，自动重试）
    _, err = k.clientSet.AppsV1().Deployments("default").
        Update(context.TODO(), deploy, metav1.UpdateOptions{})
    return err
})
```

### 5.2 指数退避

```go
import (
    "k8s.io/apimachinery/pkg/util/wait"
)

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

### 5.3 连接恢复与健康检查

```go
// client-go 内部自动处理连接断开和重连
// 可以通过 discovery API 做健康检查
func (k *K8S) HealthCheck() error {
    _, err := k.clientSet.Discovery().ServerVersion()
    return err
}
```

## 6. 总结

| 模块 | 场景 | 关键 API |
|------|------|---------|
| Clientset | 操作内置资源 | `clientset.CoreV1().Pods(ns).List()` |
| Dynamic Client | 操作 CRD，无需代码生成 | `dynamic.Resource(gvr).Namespace(ns).List()` |
| Informer | 监听资源变化 + 本地缓存 | `factory.Core().V1().Pods().Informer()` |
| Lister | 从缓存读取，零 API Server 调用 | `podInformer.Lister().Pods(ns).Get(name)` |
| WorkQueue | 控制器的任务队列，支持限流重试 | `workqueue.NewRateLimitingQueue()` |
| RetryOnConflict | 变更冲突自动重试 | `retry.RetryOnConflict(retry.DefaultRetry, fn)` |

Informer + WorkQueue 的组合是编写 Operator / Controller 的标准范式，完整示例见 [Operator 文章](/posts/kubernetes/k8s扩展-operator/)。

# 参考链接

- [client-go 官方示例](https://github.com/kubernetes/client-go/tree/master/examples)
- [client-go 源码分析](https://www.huweihuang.com/kubernetes-notes/develop/client-go.html)
- [Sample Controller（Informer 标准模板）](https://github.com/kubernetes/sample-controller)
- [Dynamic Client 操作 CRD](https://mozillazg.com/2020/07/k8s-kubernetes-client-go-list-get-create-update-patch-delete-crd-resource-without-generate-client-code-update-or-create-via-yaml.html)
