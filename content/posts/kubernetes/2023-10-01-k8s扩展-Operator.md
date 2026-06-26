---
title: "K8s扩展-Operator"
categories:
  - Kubernetes
  - Operator
tags:
  - Kubernetes
  - Operator
date: 2023-10-01 00:00:00
pinned: true
draft: false
series:
  - k8s扩展
pinned: true
draft: false
---

# 重要

Operator 是 Kubernetes 扩展机制的最高形式——通过 CRD 定义自定义资源 + 自定义控制器实现编排逻辑。理解 Operator 需要先搞清三层基础：声明式 API → 控制器/Informer 模式 → RBAC 权限。

## 系列导航

本系列按 K8S 扩展机制递进展开：

| 顺序 | 文章 | 定位 |
|------|------|------|
| ① | **[CRD 概念与使用]({{< relref "2020-08-13-CRD-概念、使用场景、go示例.md" >}})** | 数据模型扩展——CRD 的定义、校验、版本管理 |
| ② | **本篇 - Operator** | 逻辑扩展——自定义控制器 + Informer + RBAC + Operator 模式 |

# 环境说明

- Kubernetes：v1.26
- Go：go1.20

## 1. 命令式、声明式与声明式 API

K8S 有三种操作方式，区别在于"谁负责达到目标状态"：

| 方式 | 典型命令 | 谁负责 | 例子 |
|------|---------|--------|------|
| **命令式命令行** | `docker service create` | 用户记住每一步操作 | `docker service create --name nginx --replicas 2 nginx` |
| **命令式配置文件** | `kubectl create` + `kubectl replace` | 用户管理文件，全量替换 | `kubectl replace -f nginx.yaml` |
| **声明式 API** | `kubectl apply` | K8S 计算 diff 后 PATCH | `kubectl apply -f nginx.yaml` |

核心区别：

| | `kubectl replace` | `kubectl apply` |
|---|-------------------|-----------------|
| 操作方式 | 用新 YAML **替换**旧对象 | 对旧对象执行 **PATCH** |
| 字段处理 | YAML 缺字段 → 重置为默认值 | YAML 缺字段 → 保留旧值 |
| 并发安全 | 无保护，可能覆盖他人修改 | 依赖 `metadata.annotation` 记录上次 apply 内容 |
| 底层原理 | PUT 请求 | PATCH 请求 |

声明式 API 的本质：用户描述**期望状态**，Kubernetes 控制器通过持续调谐（Reconcile）将**实际状态**驱动到**期望状态**。

```text
用户提交 YAML (期望状态)
        ↓
    API Server (持久化到 Etcd)
        ↓
    控制器 Watch 到变更
        ↓
    执行 Reconcile：当前状态 ≠ 期望状态 → 调整
        ↓
    更新 Status 字段报告实际状态
```

## 2. API 对象的三要素：Group / Version / Resource

一个 API 对象在 Etcd 中的完整路径由三段组成：

| 要素 | 含义 | 示例（CronJob） | 位置 |
|------|------|----------------|------|
| **Group** | API 组，按功能分类 | `batch` | `/apis/batch` |
| **Version** | API 版本，兼容性管理 | `v2alpha1` | `/apis/batch/v2alpha1` |
| **Resource** | 资源类型名（Kind 的小写复数） | `cronjobs` | `/apis/batch/v2alpha1/cronjobs` |

```text
Kubernetes API 树形结构：

/api                          ← 核心 API（Pod、Node、Service 等，Group="")
└── /v1
    ├── pods
    ├── nodes
    └── services

/apis                         ← 非核心 API
├── apps/v1
│   └── deployments
├── batch/v1
│   ├── jobs
│   └── cronjobs
├── networking.k8s.io/v1
│   └── networkpolicies
└── <自定义 Group>/v1
    └── <自定义 Resource>
```

API Server 处理一个创建请求的流程：

```text
POST /apis/batch/v2alpha1/namespaces/default/cronjobs
  ↓
[1] 过滤 Filter：认证、授权、超时、审计
  ↓
[2] MUX & Routes：URL 匹配 → 找到 CronJob 的 Handler
  ↓
[3] 类型定义匹配：按 Group → Version → Resource 定位 CronJob 类型
  ↓
[4] Convert：将用户提交的 YAML 转换为 Super Version（该类型所有版本的字段全集）
  ↓
[5] Admission：准入控制（Admission Controller、Initializer）
  ↓
[6] Validation：字段校验
  ↓
[7] 写入 Etcd
```

多版本管理的作用：同一种 API 对象可以有 `v1alpha1` → `v1beta1` → `v1` 多个版本，通过 Super Version 保证不同版本字段的互转和兼容。

## 3. 自定义控制器：Informer 模式

### 3.1 控制器三层架构

自定义控制器的代码结构分为三层：

```text
main()                     ← 初始化 client、InformerFactory、启动控制器
  ↓
Controller 定义            ← Watch 回调注册、工作队列
  ↓
业务逻辑 (Reconcile)       ← 从队列取 key → 调谐逻辑 → 更新 Status
```

main 函数关键步骤：

```go
func main() {
    // 1. 创建 Kubernetes client 和自定义资源的 client
    cfg, _ := clientcmd.BuildConfigFromFlags(masterURL, kubeconfig)
    kubeClient, _ := kubernetes.NewForConfig(cfg)
    networkClient, _ := clientset.NewForConfig(cfg)

    // 2. 创建 Informer 工厂
    informerFactory := informers.NewSharedInformerFactory(networkClient, time.Second*30)

    // 3. 创建控制器
    controller := NewController(kubeClient, networkClient,
        informerFactory.Samplecrd().V1().Networks())

    // 4. 启动 Informer 和控制器
    go informerFactory.Start(stopCh)
    controller.Run(2, stopCh)
}
```

### 3.2 Informer 机制

Informer 是控制器模式的核心组件，负责从 API Server 获取并缓存 API 对象：

```text
API Server
    │
    │  List & Watch
    ▼
Reflector ──→ Delta FIFO ──→ Indexer（本地缓存）
                │
                │ 事件分发
                ▼
           Informer
                │
                │ 回调
                ▼
         Controller (工作队列 → Reconcile)
```

| 组件 | 职责 |
|------|------|
| **Reflector** | 通过 List & Watch 从 API Server 同步数据到 Delta FIFO |
| **Delta FIFO** | 存储对象的变化事件（Added/Updated/Deleted），先进先出 |
| **Indexer** | 本地线程安全的缓存，按 key 索引，避免反复查 API Server |
| **Informer** | 从 Delta FIFO 取事件，调用注册的回调函数，写入工作队列 |

核心优势：Informer 使用**本地缓存**而非每次查 API Server，控制器重连后通过 `resourceVersion` 从断点续传。

> 如果控制器以 Pod 方式运行在集群内，可以使用 `InClusterConfig()` 自动加载 ServiceAccount 的认证信息，无需手动指定 kubeconfig。

### 3.3 工作队列与调谐循环

```go
func (c *Controller) Run(workers int, stopCh <-chan struct{}) error {
    // 等待本地缓存同步完成
    if !cache.WaitForCacheSync(stopCh, c.informerSynced) {
        return fmt.Errorf("cache sync failed")
    }

    // 启动 workers
    for i := 0; i < workers; i++ {
        go wait.Until(c.runWorker, time.Second, stopCh)
    }
    <-stopCh
    return nil
}

func (c *Controller) runWorker() {
    for c.processNextWorkItem() {
    }
}

func (c *Controller) processNextWorkItem() bool {
    key, quit := c.workqueue.Get()
    defer c.workqueue.Done(key)
    err := c.syncHandler(key.(string))
    if err != nil {
        c.workqueue.AddRateLimited(key)  // 失败重试
    } else {
        c.workqueue.Forget(key)
    }
    return true
}
```

## 4. RBAC：控制器访问 API Server 的权限

自定义控制器需要操作 API 对象（CRD 和内置资源），必须通过 RBAC 授权。

### 4.1 三要素

| 概念 | 说明 | 示例 |
|------|------|------|
| **Role** | 一组权限规则，限定 Namespace | 对 Pod 有 get/watch/list 权限 |
| **Subject** | 被授权者：User、Group 或 ServiceAccount | `system:serviceaccount:default:my-controller` |
| **RoleBinding** | 绑定 Subject 和 Role | 把 my-controller 的 SA 绑定到 pod-reader Role |

> Kubernetes 中并没有名为 "User" 的 API 对象——"用户"只是一个授权逻辑概念，实际认证由外部系统（Keystone、证书、静态密码文件）提供。在集群内部，Pod 通过 **ServiceAccount** 获取身份。

### 4.2 Role / ClusterRole

```yaml
# 仅作用于 mynamespace 下的 Pod
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: mynamespace
  name: pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "watch", "list"]
```

```yaml
# 作用于全集群的 Node 对象
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: node-reader
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "watch", "list"]
```

### 4.3 RoleBinding

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-pods
  namespace: mynamespace
subjects:
  - kind: ServiceAccount
    name: my-controller
    namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### 4.4 Operator 的典型 RBAC 需求

以 Etcd Operator 为例，其 RBAC 权限覆盖三类资源：

| 资源类型 | 权限 | 原因 |
|---------|------|------|
| **内置资源**（Pod、Service、PVC、Deployment、Secret 等） | 全部 | Operator 需要创建和管理这些资源 |
| **CRD 对象** | 全部 | Operator 部署时注册 CRD |
| **本 Group 的 CR 对象**（如 `etcd.database.coreos.com`） | 全部 | Operator 监听并管理自己的自定义资源 |

## 5. Operator 模式

### 5.1 是什么

Operator = CRD + 自定义控制器 + 领域知识。

```text
CRD (CustomResourceDefinition)     ← 定义"什么是一个 EtcdCluster"
    +
Custom Controller (Informer 模式)  ← 持续调谐，驱动实际状态到期望状态
    +
领域知识 (编码在 Reconcile 中)     ← 知道如何创建/扩缩容/备份/恢复 Etcd
    =
Operator
```

Operator 的出现背景：编排"有状态应用"（数据库、消息队列等）时，仅靠 Deployment/StatefulSet 远远不够——需要处理初始化、扩缩容、备份、故障恢复等运维操作。Operator 将这些人工运维知识编码到控制器中。

### 5.2 Etcd Operator 举例

部署过程仅两步：

```bash
# 1. 创建 RBAC 规则
kubectl create -f example/rbac/create_role.sh

# 2. 部署 Operator
kubectl create -f example/deployment.yaml
```

Operator 启动后自动注册 CRD：

```bash
$ kubectl get crd
NAME                                    CREATED AT
etcdclusters.etcd.database.coreos.com   2023-09-18T11:42:55Z
```

CRD 结构：

```text
Group:    etcd.database.coreos.com
Kind:     EtcdCluster
Version:  v1beta2
Scope:    Namespaced
```

用户只需创建一个 EtcdCluster CR，Operator 就接管全部运维：

```yaml
apiVersion: etcd.database.coreos.com/v1beta2
kind: EtcdCluster
metadata:
  name: my-etcd
spec:
  size: 3
  version: "3.4.7"
```

Operator 会自动：
1. 创建 3 个 Pod 组成 Etcd 集群
2. 创建 Headless Service 用于节点发现
3. 配置 TLS 证书
4. 监控集群健康，故障时自动恢复
5. 支持滚动升级、备份/恢复

### 5.3 Operator 的控制循环

```text
用户创建 EtcdCluster CR (期望: size=3, version=3.4.7)
        ↓
API Server 写入 Etcd
        ↓
Etcd Operator (Informer Watch 到新 CR)
        ↓
Reconcile:
  1. 查当前状态: 0 个 Etcd Pod 在运行
  2. 调谐:
     ├── 创建 Service (Headless)
     ├── 创建 Seed Member (第一个 Pod)
     ├── 创建 Member 2
     └── 创建 Member 3
  3. 更新 CR Status: size=3, phase=Running
        ↓
运行中: 一个 Pod 挂了
        ↓
Operator 收到 Pod 事件
        ↓
Reconcile:
  1. 查当前状态: 2 个 Etcd Pod 在运行
  2. 调谐: 删除失败 Pod，创建新的
  3. 更新 Status
```

### 5.4 CRD、Controller 与 Operator 的关系

| 层级 | 组件 | 说明 |
|------|------|------|
| 数据模型 | CRD | 定义自定义资源的数据结构（Spec + Status） |
| 业务逻辑 | Controller | 通过 Informer 监听 CR 变化，执行调谐 |
| 运维知识 | Operator | Controller + 领域专有逻辑（初始化/备份/恢复） |

> 所有 Operator 都是 Controller，但不是所有 Controller 都是 Operator。区别在于 Operator 包含运维领域知识。

## 6. 总结

| 概念 | 一句话 |
|------|--------|
| 声明式 API | 用户描述期望状态，控制器驱动实际状态向其靠近 |
| Group/Version/Resource | API 对象的三段式命名空间，决定 Etcd 中的存储路径 |
| Informer | 通过 List/Watch + 本地缓存，为控制器提供高效的事件驱动机制 |
| RBAC | Role + Subject + RoleBinding，控制谁可以对哪些资源做什么操作 |
| Operator | CRD + Controller + 领域知识 = 自动化运维有状态应用 |

理解了 Operator，也就理解了 Kubernetes 扩展机制的全貌——从声明式 API 的设计，到控制器/Informer 模式的实现，再到 RBAC 的权限控制，最后到 CRD 和 Operator 的实际应用。

## 参考链接

- [Kubernetes 声明式 API 设计](https://kubernetes.io/docs/concepts/overview/working-with-objects/kubernetes-objects/)
- [CustomResourceDefinition](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)
- [Informer 机制详解](https://github.com/kubernetes/sample-controller)
- [Etcd Operator](https://github.com/coreos/etcd-operator)
- [KubeBuilder 简明教程](https://lailin.xyz/post/operator-03-kubebuilder-tutorial.html)
- [RBAC 授权](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
