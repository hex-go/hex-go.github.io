---
title: Kubernetes 弃用 API 迁移说明
categories:
  - Kubernetes
tags:
  - Kubernetes
date: 2020-07-04 00:00:00
top: false
comments: true
---

# 重要

Kubernetes 升级时 API 版本变更会导致已有 YAML 无法 `kubectl apply`。记录 v1.16 ~ v1.25 的主要 API 弃用变更，迁移时对照检查。

## v1.16

| 资源 | 旧 API | 新 API |
|------|--------|--------|
| NetworkPolicy | `extensions/v1beta1` | `networking.k8s.io/v1` |
| PodSecurityPolicy | `extensions/v1beta1` | `policy/v1beta1` |
| DaemonSet | `extensions/v1beta1`, `apps/v1beta2` | `apps/v1` |
| Deployment | `extensions/v1beta1`, `apps/v1beta1/2` | `apps/v1` |
| StatefulSet | `apps/v1beta1`, `apps/v1beta2` | `apps/v1` |
| ReplicaSet | `extensions/v1beta1`, `apps/v1beta1/2` | `apps/v1` |

DaemonSet / Deployment / StatefulSet 迁移要点：

- `spec.selector` 变为必填项，创建后不可变
- Deployment：`spec.rollbackTo` 被删除，`spec.progressDeadlineSeconds` 默认值变为 600s

## v1.22

| 资源 | 旧 API | 新 API |
|------|--------|--------|
| Ingress | `extensions/v1beta1` | `networking.k8s.io/v1` |
| IngressClass | `networking.k8s.io/v1beta1` | `networking.k8s.io/v1` |
| CRD | `apiextensions.k8s.io/v1beta1` | `apiextensions.k8s.io/v1` |
| Webhook | `admissionregistration.k8s.io/v1beta1` | `admissionregistration.k8s.io/v1` |
| RBAC | `rbac.authorization.k8s.io/v1beta1` | `rbac.authorization.k8s.io/v1` |
| CSIDriver / CSINode | `storage.k8s.io/v1beta1` | `storage.k8s.io/v1` |

**Ingress v1 迁移要点（最常用）：**

| 旧字段 | 新字段 |
|--------|--------|
| `spec.backend` | `spec.defaultBackend` |
| `backend.serviceName` | `backend.service.name` |
| `backend.servicePort` (数字) | `backend.service.port.number` |
| `backend.servicePort` (字符串) | `backend.service.port.name` |
| — | `pathType` 变为必填（`Prefix` / `Exact` / `ImplementationSpecific`） |

**CRD v1 迁移要点：**

| 旧字段 | 新字段 |
|--------|--------|
| `spec.version` | `spec.versions[]` |
| `spec.validation` | `spec.versions[*].schema` |
| `spec.scope` | 默认值 `Namespaced` 被移除，必须显式指定 |

## v1.25

| 资源 | 旧 API | 新 API |
|------|--------|--------|
| Event | `events.k8s.io/v1beta1` | `events.k8s.io/v1` |
| RuntimeClass | `node.k8s.io/v1beta1` | `node.k8s.io/v1` |
| PodSecurityPolicy | — | 完全移除，迁移至 Pod Security Admission |

## 参考

- [Kubernetes API 弃用策略](https://kubernetes.io/zh/docs/reference/using-api/deprecation-policy/)
- [v1.22 弃用指南](https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-22)
- [v1.25 弃用指南](https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-25)
