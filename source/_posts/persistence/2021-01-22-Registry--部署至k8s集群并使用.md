---
title: Registry--部署至k8s集群并使用
categories:
  - Persistence
tags:
  - Persistence
  - Registry
  - Kubernetes
date: '2021-01-22 10:13:28'
top: false
comments: true
---
# 重要
最重要的事: 操作记录 

# 1.简介
nuclio平台部署，需要一个镜像仓库提供两个功能
1. 构建时，提供build-base-image;
2. 存储每个function构建后的结果镜像。

所以需要： 1. 部署带认证的registry； 2. 将基础依赖镜像(包括各个语言的build-handler镜像等)推送registry

# 2.环境准备
获取, 基于 
[此chart](https://github.com/helm/charts/tree/master/stable/docker-registry) 修改的registry。 
[离线chart](/images/charts/prebaked-registry-0.0.1.tgz)

# 3.部署
## 参数说明

`prebaked-registry/values.yaml`：


| 变量                  | 说明                                                         |
| ------------------------- | ------------------------------------------------------------ |
| secrets.htpasswd           | kaniko pull prebaked-registry时认证用的密码                |


## 生成prebaked-registry认证密码

```
docker run --entrypoint htpasswd registry:2 -Bbn icos 123456
```
## 部署prebaked-registry
把上一步生成的密码粘贴到 prebaked-registry/values.yaml secrets.htpasswd

执行命令部署服务：
```bash
kubectl create ns nuclio
helm install prebaked-registry ./prebaked-registry/ -n nuclio
```
## 创建registry credentials secret
```bash
# 输入registry密码，同prebaked-registry保持一致
read -s mypassword

# 注意修改 <user>
kubectl -n nuclio create secret docker-registry registry-credentials --docker-username icos --docker-password $mypassword --docker-server prebaked-registry.nuclio:5000 --docker-email admin@icos.city
# 注销变量
unset mypassword

```

# 4.使用
> 参考chart的Note内容

```template
1. Get the application URL by running these commands:
{{- if .Values.ingress.enabled }}
{{- range .Values.ingress.hosts }}
  http{{ if $.Values.ingress.tls }}s{{ end }}://{{ . }}{{ $.Values.ingress.path }}
{{- end }}
{{- else if contains "NodePort" .Values.service.type }}
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ template "docker-registry.fullname" . }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
{{- else if contains "LoadBalancer" .Values.service.type }}
     NOTE: It may take a few minutes for the LoadBalancer IP to be available.
           You can watch the status of by running 'kubectl get svc -w {{ template "docker-registry.fullname" . }}'
  export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ template "docker-registry.fullname" . }} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo http://$SERVICE_IP:{{ .Values.service.externalPort }}
{{- else if contains "ClusterIP" .Values.service.type }}
  export POD_NAME=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app={{ template "docker-registry.name" . }},release={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl -n {{ .Release.Namespace }} port-forward $POD_NAME 8080:5000
{{- end }}
```

# Reference

[Blog-private-docker-registry](https://blinkeye.github.io/post/public/2019-05-28-private-docker-registry/)

[Blog-在k8s中部署registry](https://www.nearform.com/blog/how-to-run-a-public-docker-registry-in-kubernetes/)
