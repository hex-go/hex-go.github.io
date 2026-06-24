---
title: Kubernetes 使用 Sidecar 配置 Filebeat 收集容器日志
categories:
  - Kubernetes
tags:
  - Kubernetes
  - Filebeat
  - Sidecar
  - 日志
date: '2021-01-27 09:37:06'
top: false
comments: true
---

# 重要

K8s 中收集容器日志有两种模式：

| 模式 | 原理 | 优缺点 |
|------|------|--------|
| DaemonSet | 每个 Node 部署一个日志采集 Pod，读 `/var/log/containers` | 运维简单，但不支持自定义日志路径 |
| Sidecar | 在业务 Pod 内嵌入日志采集容器，共享 emptyDir Volume | 灵活，支持自定义路径和格式；额外消耗资源 |

当业务容器将日志写到自定义路径（非 stdout/stderr）时，只能用 Sidecar 模式。

## 1.简介

业务容器和 Filebeat Sidecar 共享一个 `emptyDir` Volume——业务容器写日志到该卷，Filebeat 读取并上报到 Elasticsearch 或 Kafka。

## 2.说明

### 2.1 共享 Volume 原理

```text
Pod
├── 业务容器
│   └── 写日志到 /var/logs/app/app.log
│
├── Filebeat Sidecar
│   └── 读 /var/logs/app/app.log → 上报到 ES/Kafka
│
└── emptyDir Volume (log-data)
    挂载到两个容器的 /var/logs/app
```

### 2.2 Deployment 配置

```yaml
spec:
  containers:
    - name: filebeat
      image: docker.elastic.co/beats/filebeat:7.10.0
      volumeMounts:
        - name: log-data
          mountPath: /var/logs/app
        - name: filebeat-config
          mountPath: /usr/share/filebeat/filebeat.yml
          subPath: filebeat.yml

    - name: app
      image: my-app:v1.0.0
      volumeMounts:
        - name: log-data
          mountPath: /var/logs/app

  volumes:
    - name: log-data
      emptyDir: {}
    - name: filebeat-config
      configMap:
        name: filebeat-config
```

| 关键配置 | 说明 |
|----------|------|
| 两个容器挂载同一个 `emptyDir` | 实现日志共享 |
| `emptyDir` | Pod 生命周期内有效，Pod 删除后日志随 Volume 清除 |
| Filebeat 配置通过 ConfigMap 挂载 | 便于更新采集规则 |

### 2.3 Filebeat ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
data:
  filebeat.yml: |
    filebeat.inputs:
      - type: log
        paths:
          - /var/logs/app/*.log
    output.elasticsearch:
      hosts: ["elasticsearch:9200"]
```

## 3.总结

1. stdout/stderr 日志用 DaemonSet 模式，自定义路径日志用 Sidecar 模式；
2. Sidecar 模式的核心是 emptyDir Volume 在两个容器间共享；
3. Filebeat 配置通过 ConfigMap 注入，保持容器镜像不变。

## 4.参考

- [Filebeat 官方文档](https://www.elastic.co/guide/en/beats/filebeat/current/index.html)
