---
title: 'Kubernetes[Release]-弃用API迁移说明(持续更新)'
categories:
  - Kubernetes
tags:
  - Kubernetes
date: '2021-02-18 07:10:42'
top: false
comments: true
---

# 重要
[Kubernetes API弃用策略](https://kubernetes.io/zh/docs/reference/using-api/deprecation-policy/)

Kubernetes 升级， 主要的API变化在v1.16\v1., 具体说明如下：

[v1.16 变化](https://kubernetes.io/blog/2019/07/18/api-deprecations-in-1-16/)
v1.16版本将停止提供以下不推荐使用的API版本，而支持更新和更稳定的API版本：

- `NetworkPolicy`资源:          由`extensions/v1beta1`迁移至v1.8以来可用的`networking.k8s.io/v1`API。
- `PodSecurityPolicy`资源: 由`extensions/v1beta1`迁移至v1.10以来可用的`policy/v1beta1`API。
- `DaemonSet`资源:                  由`extensions/v1beta1`和`apps/v1beta2`迁移至v1.9以来可用的`apps/v1`API。
  - `spec.templateGeneration`字段被删除。
  - `spec.selector`为必填项, 且在创建后是不变的。使用现有的`tmplate labels`作为`selector`无缝升级
  - `spec.updateStrategy.type`默认值为`RollingUpdate`（`extensions/v1beta1`默认值为`OnDelete`)
- `Deployment`资源:                由`extensions/v1beta1` `apps/v1beta1` `apps/v1beta2`迁移至v1.9以来可用的`apps/v1`API。
  - `spec.rollbackTo`字段被删除
  - `spec.selector`为必填项, 且在创建后是不变的。使用现有的`tmplate labels`作为`selector`无缝升级
  - `spec.progressDeadlineSeconds`默认值为`600s`(`extensions/v1beta1`默认值没有截止日期）
  - `spec.revisionHistoryLimit`默认值为`10`(`apps/v1beta1`默认值为2，`extensions/v1beta1`中默认值为保留所有)
  - `maxSurge`和`maxUnavailable`默认值为`25％`(`extensions/v1beta1`默认值为`1`)
- `Statefulset`资源:              由`apps/v1beta1`和`apps/v1beta2`迁移至v1.9以来可用的`apps/v1`API。
  - `spec.selector`为必填项, 且在创建后是不变的。使用现有的`tmplate labels`作为`selector`无缝升级
  - `spec.updateStrategy.type`默认值为`RollingUpdate`（`extensions/v1beta1`默认值为`OnDelete`)
- `ReplicaSet`资源:                 由`extensions/v1beta1` `apps/v1beta1` `apps/v1beta2`迁移至v1.9以来可用的`apps/v1`API。
  - `spec.selector`为必填项, 且在创建后是不变的。使用现有的`tmplate labels`作为`selector`无缝升级



[v1.22变化](https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-22)

- `MutatingWebhookConfiguration`和`ValidatingWebhookConfiguration`资源:  由`admissionregistration.k8s.io/v1beta1`迁移至v1.16以来可用的`admissionregistration.k8s.io/v1` API 

  - `webhooks[*].failurePolicy` 默认值 from `Ignore` to `Fail` 
  - `webhooks[*].matchPolicy` 默认值 from `Exact` to `Equivalent`
  - `webhooks[*].timeoutSeconds` 默认值 from `30s` to `10s` 
  - `webhooks[*].sideEffects` 变为必填项 oneof  `None` and `NoneOnDryRun`
  - `webhooks[*].admissionReviewVersions` 变为必填项
  - `webhooks[*].name` 名称必须唯一

- `CustomResourceDefinition`资源:  由`apiextensions.k8s.io/v1beta1` 迁移至v1.16以来可用的`apiextensions.k8s.io/v1`API。

  - `spec.scope` 去除默认值 `Namespaced`，变为必须指定。
  - `spec.version` 去除，由 `spec.versions` 替换。
  - `spec.validation` 去除，由`spec.versions[*].schema` 替换。
  - `spec.subresources` 去除，由`spec.versions[*].subresources` 替换。
  - `spec.additionalPrinterColumns` 去除，由`spec.versions[*].additionalPrinterColumns` 替换。
  - `spec.conversion.webhookClientConfig`迁移至`spec.conversion.webhook.clientConfig`。
  - `spec.conversion.conversionReviewVersions`迁移至`spec.conversion.webhook.conversionReviewVersions`
  - `spec.versions[*].schema.openAPIV3Schema` 为必填项, 并且必须为[结构化schema](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#specifying-a-structural-schema)。
  - `spec.preserveUnknownFields: true` 不被允许，必须通过schema中指定 `x-kubernetes-preserve-unknown-fields: true`
  -  `additionalPrinterColumns` 中, `JSONPath` 字段改为`jsonPath` (fixes [#66531](https://github.com/kubernetes/kubernetes/issues/66531))

- `APIService`资源:         由`apiregistration.k8s.io/v1beta1` 迁移至v1.10以来可用的`apiregistration.k8s.io/v1`API。

- `TokenReview`资源:       由`authentication.k8s.io/v1beta1` 迁移至v1.6以来可用的`authentication.k8s.io/v1`API。

- `LocalSubjectAccessReview`、`SelfSubjectAccessReview`、`SubjectAccessReview`

  由`authentication.k8s.io/v1beta1` 迁移至v1.6以来可用的`authentication.k8s.io/v1`API。

  - `spec.group`字段重命名为`spec.groups`(fix [#32709](https://github.com/kubernetes/kubernetes/issues/32709))

- `CertificateSigningRequest`资源: 由`certificates.k8s.io/v1beta1` 迁移至v1.19以来可用的`certificates.k8s.io/v1`API。

  - 请求证书：
    - `spec.signerName`为必填项(请参阅[Kubernetes signers](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/#kubernetes-signers)), 并且不允许通过。`certificate.k8s.io/v1`API创建对`kubernetes.io/legacy-unknown`的请求。
    - `spec.usages`为必填项、不可重复，并且只能包含已知用法。
  - 颁发证书：
    - `status.condition`不可重复。
    - `status.conditions[*].status`为必填项。
    - `status.certificate` 必须为PEM-encoded, 并且仅包含`CERTIFICATE` 块。

- `Lease`资源: 由`coordination.k8s.io/v1beta1` 迁移至v1.14以来可用的`coordination.k8s.io/v1`API。

- `Ingress`资源: 由`extensions/v1beta1`迁移至v1.19以来可用的`networking.k8s.io/v1beta1`API。

  - `spec.backend` 字段名变为 `spec.defaultBackend`
  - `spec.rules[*].http.paths[*].backend.serviceName` 字段变为 `spec.rules[*].http.paths[*].backend.service.name`
  - `spec.rules[*].http.paths[*].backend.servicePort` 字段，值为数字变为 `spec.rules[*].http.paths[*].backend.service.port.number`
  - `spec.rules[*].http.paths[*].backend.servicePort` 字段，值为字符串变为 `spec.rules[*].http.paths[*].backend.service.port.name`
  - `spec.rules[*].http.paths[*].pathType` 为必填项，oneof`Prefix`, `Exact`, and `ImplementationSpecific`. `ImplementationSpecific`用来对应`v1beta1`.
  - `spec.rules[*].http.paths[*].backend.path`为必填项，匹配所有路径值设置为`/`。

- `IngressClass`资源: 由`networking.k8s.io/v1beta1`迁移至v1.19以来可用的`networking.k8s.io/v1`API。

- `ClusterRole`, `ClusterRoleBinding`, `Role`, and `RoleBinding` 资源由`rbac.authorization.k8s.io/v1beta1`迁移至v1.8以来可用的`rbac.authorization.k8s.io/v1`API

- `PriorityClass`资源由`scheduling.k8s.io/v1beta1`迁移至v1.14以来可用的`scheduling.k8s.io/v1`API

- `CSIDriver, CSINode, StorageClass, and VolumeAttachment `资源由`storage.k8s.io/v1beta1`迁移至`storage.k8s.io/v1`API

  - `CSIDriver`在`v1.19`可用
  - `CSINode`在`v1.17`可用
  - `StorageClass`在`v1.6`可用
  - `VolumeAttachment`在`v1.13`可用



[1.25变化](https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-25)

- `Event`资源:   由`events.k8s.io/v1beta1`迁移至v1.19以来可用的`events.k8s.io/v1`API
  - `type` 仅限于 `Normal` 、 `Warning`
  - `involvedObject` 被重命名为 `regarding`
  - `action`, `reason`, `reportingComponent`, and `reportingInstance` 为必填项
  - `eventTime`                              替换废弃的字段`firstTimestamp` 
  - `series.lastObservedTime` 替换废弃的字段`lastTimestamp` 
  - `series.count`                        替换废弃的字段`count`
  - `reportingComponent`            替换废弃的字段`source.component`
  - `reportingInstance`              替换废弃的字段`source.host`

- `RuntimeClass`资源:  由`node.k8s.io/v1beta1`迁移至v1.20以来可用的`node.k8s.io/v1`API



# Reference
[Kubernetes API弃用策略](https://kubernetes.io/zh/docs/reference/using-api/deprecation-policy/)

[启用API迁移指南](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)