---
title: Kubernetes-使用sidecar配置filebeat收集容器日志
categories:
  - Kubernetes
tags:
  - Kubernetes
date: '2021-01-27 09:37:06'
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
      containers:
      {{- if .Values.filebeatSidecar }}
      - name: filebeat
        image: {{ $.Values.filebeat.image | quote }}
        volumeMounts:
          - name: log-data
            mountPath: /var/logs/app
          {{- if .Values.configMapEnable }}
          {{- range $i,$map :=  .Values.configMapList }}
          - name: {{ $map.name }}
            mountPath: {{ $map.mountPath | quote }}
            {{- if $map.subPath }}
            subPath: {{ $map.subPath }}
            {{- end }}
          {{- end }}
          {{- end }}
      {{- end }}
      - name: {{ template "common.containers.name" . }}
        image: "{{ .Values.global.imageRepositoryName }}/{{ .Values.imageRepository }}:{{.Chart.AppVersion}}"
        imagePullPolicy: {{ .Values.imagePullPolicy | quote }}

```

# Reference