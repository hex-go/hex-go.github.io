---
title: Kubernetes-使用初始化容器修改挂卷的权限
categories:
  - Kubernetes
tags:
  - Kubernetes
date: '2021-01-27 09:35:59'
top: false
comments: true
---

# 重要

# 配置

Deployment中配置举例
```yaml
spec:
  selector:
    matchLabels:
      app: {{ template "common.name" . }}
  replicas: {{ .Values.deploymentReplicas }}
  template:
    metadata:
      name: {{ template "common.name" . }}
      annotations:
        container.security.alpha.kubernetes.io/{{- template "common.name" . -}}: "runtime/default"
      labels:
        app: {{ template "common.name" . }}
        release: "{{ .Release.Name }}"
    spec:
      {{- if .Values.persistenceEnabled}}
      initContainers:
      - name: volume-permissions
        image: reg.chebai.org/paas/busybox:latest
        command: ['sh', '-c', 'chmod -R 777 {{ .Values.volumeMounts.mountPath | quote }}']
        volumeMounts:
        - mountPath: {{ .Values.volumeMounts.mountPath | quote }}
          name: {{ $.Values.serviceName }}-nfs
      {{- end }}

```

# Reference