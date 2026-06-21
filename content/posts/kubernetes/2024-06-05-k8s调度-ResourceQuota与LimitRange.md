---
title: "K8s调度-ResourceQuota与LimitRange"
categories:
  - Kubernetes
tags:
  - ResourceQuota
  - LimitRange
  - Kubernetes
date: '2024-06-05 22:00:00'
draft: true
top: false
comments: true
keywords:
  - ResourceQuota
  - LimitRange
  - 多租户
series:
  - k8s调度
pinned: true
---

## 系列导航

本系列从 K8s 资源模型入手，逐步展开到调度器策略、优先级抢占与 AI 时代演进。

`① 资源模型 → ② Quota/LimitRange → ③ 调度器架构 → ④ 优先级抢占 → ⑤ AI调度演进 → ⑥ 排障`

| 顺序 | 文章 | 定位 |
|------|------|------|
| ① | **[资源模型与 QoS]({{< relref "2024-06-01-k8s调度-资源模型与QoS.md" >}})** | 基础——requests/limits、QoS 类、cgroups、OOM |
| ② | **本篇 - ResourceQuota 与 LimitRange** | 管控——资源配额、默认值、多租户隔离 |
| ③ | **[调度器架构与策略]({{< relref "2024-06-10-k8s调度-调度器架构与策略.md" >}})** | 核心——过滤/打分/绑定、调度策略详解 |
| ④ | **[优先级与抢占机制]({{< relref "2024-06-15-k8s调度-优先级与抢占机制.md" >}})** | 进阶——PriorityClass、抢占流程、驱逐 |
| ⑤ | **[AI 时代的调度演进]({{< relref "2024-06-20-k8s调度-AI时代的调度演进.md" >}})** | 展望——GPU拓扑感知、NUMA、coscheduling、Gang调度 |
| ⑥ | **[排障思路与常用命令]({{< relref "2024-06-25-k8s调度-排障思路与常用命令.md" >}})** | 运维——调度失败、资源不足、驱逐排查 |

---

# 重要

requests/limits 是 Pod 级别的资源管控。ResourceQuota 提供 Namespace 级别的总配额限制，LimitRange 为没有设置 requests/limits 的容器提供默认值。两者结合实现多租户的资源隔离。

---

## 1. ResourceQuota

### 1.1 概念

ResourceQuota 限制一个 Namespace 内所有 Pod 的总资源消耗：

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    persistentvolumeclaims: "5"
    requests.storage: 50Gi
```

| 配额项 | 说明 |
|--------|------|
| `requests.cpu / .memory` | 该 Namespace 所有 Pod 的 requests 总和上限 |
| `limits.cpu / .memory` | 该 Namespace 所有 Pod 的 limits 总和上限 |
| `persistentvolumeclaims` | PVC 数量上限 |
| `requests.storage` | PVC 总请求存储量上限 |
| `count/pods` | Pod 数量上限 |
| `count/services` | Service 数量上限 |

### 1.2 效果

创建 ResourceQuota 后，K8s 会拒绝超出配额的资源创建：

```bash
kubectl apply -f quota.yaml
# ResourceQuota 创建成功

# 如果 Team-A 已经用满了 10 CPU requests，再创建 Pod 会失败：
kubectl apply -f pod.yaml -n team-a
# Error from server (Forbidden): pods "big-pod" is forbidden:
# exceeded quota: compute-quota, requested: requests.cpu=2, used: requests.cpu=10
```

---

## 2. LimitRange

### 2.1 概念

LimitRange 为 Namespace 中的 Pod/容器设置默认值、最小值和最大值：

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: team-a
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "250m"
      memory: "256Mi"
    max:
      cpu: "4"
      memory: "8Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
    maxLimitRequestRatio:
      cpu: "10"
      memory: "4"
```

### 2.2 字段说明

| 字段 | 作用 | 示例含义 |
|------|------|---------|
| `default` | 未设置 limits 时的默认值 | 默认 limits.cpu=500m |
| `defaultRequest` | 未设置 requests 时的默认值 | 默认 requests.cpu=250m |
| `max` | 单容器最大资源限制 | 单容器最多 4 核、8Gi |
| `min` | 单容器最小资源保证 | 单容器至少 100m CPU、128Mi 内存 |
| `maxLimitRequestRatio` | limits/requests 最大比例 | limits 最多是 requests 的 10 倍 |

### 2.3 为什么需要 maxLimitRequestRatio

防止 Burstable Pod 的 limits 远超 requests，导致节点严重超卖：

```yaml
# 不允许这种行为（limits 是 requests 的 100 倍）
resources:
  requests:
    cpu: "10m"
  limits:
    cpu: "1"  # Ratio = 100 > 10, 被拒绝
```

---

## 3. ResourceQuota 与 LimitRange 配合

| 场景 | ResourceQuota 作用 | LimitRange 作用 |
|------|-------------------|----------------|
| 多团队共享集群 | 限制每个 Namespace 总配额 | 为每个容器设置默认值，防止遗漏 |
| 防止资源泄漏 | 统计 Namespace 内总消耗 | 设置最低资源保证 |
| 成本控制 | 按 Namespace 预算分配 | 限制单个容器的资源上限 |

### 3.1 典型多租户配置

```yaml
# Namespace: team-a
# 1. LimitRange：默认 requests=250m/256Mi，limits=500m/512Mi
# 2. ResourceQuota：总 CPU=10核，总内存=20Gi
---
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
---
apiVersion: v1
kind: LimitRange
metadata:
  name: defaults
  namespace: team-a
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "250m"
      memory: "256Mi"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    count/pods: "50"
```

| 效果 | 说明 |
|------|------|
| 新 Pod 不设 requests | 自动填 250m CPU / 256Mi 内存 |
| 新 Pod 不设 limits | 自动填 500m CPU / 512Mi 内存 |
| Pod 设 requests > 10 核 | 被 ResourceQuota 拒绝 |
| 单个容器 limits > 4 核 | 被 LimitRange 拒绝 |

---

## 4. ResourceQuota 的 Scope

ResourceQuota 支持限定只统计特定 QoS 类的 Pod：

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: besteffort-quota
  namespace: team-a
spec:
  hard:
    pods: "10"
  scopes:
    - BestEffort
```

| Scope | 说明 |
|-------|------|
| `Terminating` | 只统计有 `activeDeadlineSeconds` 的 Pod |
| `NotTerminating` | 只统计无 `activeDeadlineSeconds` 的 Pod |
| `BestEffort` | 只统计 QoS 为 BestEffort 的 Pod |
| `NotBestEffort` | 只统计 Guaranteed 和 Burstable |
| `PriorityClass` | 只统计指定优先级的 Pod |

---

## 5. 常见坑

| 问题 | 说明 | 解决 |
|------|------|------|
| 忘记设 defaults | 没有 LimitRange 时，Pod 不设 limits = 可能 OOM | 每个 Namespace 都配置 LimitRange |
| Burstable 超卖严重 | limits/requests 比例太大，节点资源拍卖 | 设 `maxLimitRequestRatio` |
| ResourceQuota 限制 Pod 数量 | Pod 无法创建但日志不明显 | `kubectl describe quota` 查看配额使用率 |
| LimitRange 只对新 Pod 生效 | 已存在的 Pod 不受 LimitRange 约束 | 重建 Pod 使其生效 |

---

## 参考链接

- [ResourceQuota](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [LimitRange](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Resource Quota Walkthrough](https://kubernetes.io/docs/tasks/administer-cluster/quota-memory-cpu-namespace/)
