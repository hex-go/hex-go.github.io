---
title: 部署组件--IngressController启用证书透传
categories:
  - Kubernetes
tags:
  - Kubernetes
  - IngressController
date: '2021-01-22 11:44:08'
top: false
comments: true
---

# 重要
ingress controller 启用证书透传需要做两步操作

1. 部署IngressController时，需要增加参数`--enable-ssl-passthrough`
2. 在ingress对象中设置`annotation`，值为`nginx.ingress.kubernetes.io/ssl-redirect: "false"`

> `--enable-ssl-passthrough`标志启用SSLPassthrough功能，​​此功能默认情况下处于禁用状态。

# 环境说明
kubernetes 1.15.6

nginx-ingress-controller:3.21.0

# 配置

## 1. 获取chart
[离线备份](images/charts/ingress-nginx-3.21.0.tgz)

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 拉取 最新 版本chart
# 建议拉取chart,而不是在线安装
helm pull ingress-nginx/ingress-nginx --version=3.21.0

# helm install 
helm install --name ingress-nginx --namespace ingress-nginx ingress-nginx-3.21.0.tgz

helm install ingress-nginx ingress-nginx/ingress-nginx
```

## 2. 配置`ingress-nginx`,增加参数`--enable-ssl-passthrough`
1. ingress-nginx的未在values文件中分离变量控制透传，需要改动`template/controller-deployment.yaml#77`：
```yaml
{{- if or (eq .Values.controller.kind "Deployment") (eq .Values.controller.kind "Both") -}}
{{- include  "isControllerTagValid" . -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "ingress-nginx.controller.fullname" . }}
spec:
  revisionHistoryLimit: {{ .Values.revisionHistoryLimit }}
  minReadySeconds: {{ .Values.controller.minReadySeconds }}
  template:
    metadata:
    {{- if .Values.controller.podAnnotations }}
      annotations:
      {{- range $key, $value := .Values.controller.podAnnotations }}
        {{ $key }}: {{ $value | quote }}
      {{- end }}
    {{- end }}
      labels:
        {{- include "ingress-nginx.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: controller
      {{- if .Values.controller.podLabels }}
        {{- toYaml .Values.controller.podLabels | nindent 8 }}
      {{- end }}
    spec:
      dnsPolicy: {{ .Values.controller.dnsPolicy }}
      containers:
        - name: controller
          {{- with .Values.controller.image }}
          image: "{{.repository}}:{{ .tag }}{{- if (.digest) -}} @{{.digest}} {{- end -}}"
          {{- end }}
          imagePullPolicy: {{ .Values.controller.image.pullPolicy }}
        {{- if .Values.controller.lifecycle }}
          lifecycle: {{ toYaml .Values.controller.lifecycle | nindent 12 }}
        {{- end }}
          args:
            - /nginx-ingress-controller
            - --enable-ssl-passthrough
```

## 3. 配置 ingress-object 的注解

 创建的需要透传的ingress对象举例：
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "false"
  kubernetes.io/ingress.class: nginx
creationTimestamp: "2020-08-18T07:35:48Z"
name: paas-sample-ingress
spec:
rules:
- host: paassample.icos.city
  http:
    paths:
    - backend:
        serviceName: paas-sample-svc
        servicePort: 80
      path: /
```

# Reference

[IngressNginx设置SSL Passthrough](https://kubernetes.github.io/ingress-nginx/user-guide/tls/#ssl-passthrough)