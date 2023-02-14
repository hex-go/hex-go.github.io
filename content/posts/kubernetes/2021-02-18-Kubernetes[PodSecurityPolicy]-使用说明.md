---
title: 'Kubernetes[PodSecurityPolicy]-使用说明'
categories:
  - Kubernetes
tags:
  - Kubernetes
date: '2021-02-18 10:19:23'
top: false
comments: true
---

# 重要

Kubernetes: 1.20.2





# Pod 安全策略



## 1. 什么是PodSecurityPolicy？

Pod 安全策略（Pod Security Policy） 是集群级别的资源，它能够控制 Pod 规约 中与安全性相关的各个方面。 `PodSecurityPolicy` 对象定义了一组 Pod 运行时必须遵循的条件及相关字段的默认值，只有 Pod 满足这些条件 才会被系统接受。 Pod 安全策略允许管理员控制如下方面：



## 2. 启用PodSecurityPolicy

Pod 安全策略实现为一种可选（但是建议启用）的 [准入控制器(admission-controllers)](https://kubernetes.io/zh/docs/reference/access-authn-authz/admission-controllers/#podsecuritypolicy)。 [启用了准入控制器](https://kubernetes.io/zh/docs/reference/access-authn-authz/admission-controllers/#how-do-i-turn-on-an-admission-control-plug-in) 即可强制实施 Pod 安全策略，不过如果没有授权认可策略之前即启用 准入控制器 **将导致集群中无法创建任何 Pod**。

> 由于 Pod 安全策略 API（`policy/v1beta1/podsecuritypolicy`）是独立于准入控制器(admission-controllers)来启用的，对于现有集群而言，建议在启用准入控制器之前先添加策略并对其授权。



## 3. 配置PodSecurityPolicy举例



### 3.1 创建PSP(PodSecurityPolicy)

rke部署的集群会默认创建部分psp资源，比如`default-psp`

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: default-psp
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: '*'
spec:
  allowPrivilegeEscalation: true
  allowedCapabilities:
  - '*'
  fsGroup:
    rule: RunAsAny
  hostIPC: true
  hostNetwork: true
  hostPID: true
  hostPorts:
  - max: 65535
    min: 0
  privileged: true
  runAsUser:
    rule: RunAsAny
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  volumes:
  - '*'
```



### 3.2  RBAC授权

```bash
# 0. `default-psp`会在rke创建集群的时候自动创建

# 1. 创建role, 此角色可访问 `default-psp` 的psp
# kubectl -n <namespace> create role <role-name> --verb=use --resource=podsecuritypolicy --resource-name=default-psp

kubectl -n kube-ops create role psp:unprivileged --verb=use --resource=podsecuritypolicy --resource-name=default-psp

# 2. 创建`rolebinding`
# 在Namespace下会有一个默认账户`default`
# Deployment创建的pod, 不指定`serviceAccountName`时，使用`default`账户，需要将`default`账户与创建的角色关联（特定用户声明参考Ingress-Nginx部署举例）
# kubectl -n <Namespace> create rolebinding <Rolebinding-name> --role=<Role-name> --serviceaccount=<Namespace>:<ServiceAccount>
kubectl -n kube-ops create rolebinding default:psp:unprivileged --role=psp:unprivileged --serviceaccount=kube-ops:default

```



### 3.3 创建Deployment

```bash
# 创建Deployment测试，一切正常
# kubectl create deployment <Deployment-name> --image=<ImagePath> -n <Namespace>
kubectl create deployment kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1 -n kube-ops

# 查看，pod正常创建
root@hex-0001:~/# kubectl get pod -n kube-ops
NAME                                   READY   STATUS              RESTARTS   AGE
kubernetes-bootcamp-57978f5f5d-dbkcm   0/1     ContainerCreating   0          12s

```



### 3.4 调试方法

```bash
# 创建失败时通过`Deployment`和`event`查看状态

# 1. describe Deployment
root@lab-rke-hex-0001:~/bkp# kubectl describe  deployment kubernetes-bootcamp -n kube-ops
Name:                   kubernetes-bootcamp
Namespace:              kube-ops
Selector:               app=kubernetes-bootcamp
Replicas:               1 desired | 0 updated | 0 total | 0 available | 1 unavailable
StrategyType:           RollingUpdate
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=kubernetes-bootcamp
  Containers:
   kubernetes-bootcamp:
    Image:        gcr.io/google-samples/kubernetes-bootcamp:v1
  Volumes:        <none>
Conditions:
  Type             Status  Reason
  ----             ------  ------
  Progressing      True    NewReplicaSetCreated
  Available        False   MinimumReplicasUnavailable
  ReplicaFailure   True    FailedCreate
OldReplicaSets:    <none>
NewReplicaSet:     kubernetes-bootcamp-57978f5f5d (0/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  25s   deployment-controller  Scaled up replica set kubernetes-bootcamp-57978f5f5d to 1

# 2. get event
root@lab-rke-hex-0001:~/bkp# kubectl get event -n kube-ops
LAST SEEN   TYPE      REASON              OBJECT                                          MESSAGE
3m11s       Warning   FailedCreate        replicaset/kubernetes-bootcamp-57978f5f5d       Error creating: pods "kubernetes-bootcamp-57978f5f5d-" is forbidden: PodSecurityPolicy: unable to admit pod: []
8m39s       Normal    ScalingReplicaSet   deployment/kubernetes-bootcamp                  Scaled up replica set kubernetes-bootcamp-57978f5f5d to 1

```



## 4. IngressNginx部署举例

> - `serviceAccount: ingress-nginx-admission` 创建`job:ingress-nginx-admission-patch`和`job: ingress-nginx-admission-create`等
> - `serviceAccount: ingress-nginx` 创建`Deployment:ingress-nginx-controller`

>  所以需要将`PodSecurityPolicy: default-psp`给到两个账户`serviceAccount: ingress-nginx`和`serviceAccount: ingress-nginx-admission`

操作如下：

### 4.1 关联 `PodSecurityPolicy: default-psp`与`serviceAccount: ingress-nginx`

Deployment中声明的serviceAccount如下：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: ingress-nginx
  name: ingress-nginx-controller
spec:
  template:
    metadata:
      name: ingress-nginx-admission-create
      labels:
        app.kubernetes.io/name: ingress-nginx
    spec:
      containers:
        - name: create
          image: reg.chebai.org/kubernetes-ingress-controller/kube-webhook-certgen:v1.0.0
      serviceAccountName: ingress-nginx-admission
```

创建rbac, 关联`ServiceAccount`与`PodSecurityPolicy`。

```bash
# 0. `default-psp`会在rke部署集群的时候自动创建

# 1. 创建role `psp:unprivileged`, 此角色可访问psp `default-psp`
# kubectl -n <namespace> create role <role-name> --verb=use --resource=podsecuritypolicy --resource-name=default-psp
kubectl -n ingress-nginx create role psp:unprivileged --verb=use --resource=podsecuritypolicy --resource-name=default-psp

# 2. 创建rolebinding `ingress-nginx:psp:unprivileged`
# ingressNginx的Deployment创建的pod时，指定`serviceAccountName`为`ingress-nginx`。需要将`ingress-nginx`账户与创建的角色关联
# kubectl -n <Namespace> create rolebinding <Rolebinding-name> --role=<Role-name> --serviceaccount=<Namespace>:<ServiceAccount>
kubectl -n ingress-nginx create rolebinding ingress-nginx:psp:unprivileged --role=psp:unprivileged --serviceaccount=ingress-nginx:ingress-nginx

```



### 4.2 关联 `PodSecurityPolicy: default-psp`与`serviceAccount: ingress-nginx`

Job中声明的serviceAccount如下：

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ingress-nginx-admission-patch
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
  labels:
    app.kubernetes.io/name: ingress-nginx
spec:
  template:
    metadata:
      name: ingress-nginx-admission-patch
      labels:
        app.kubernetes.io/name: ingress-nginx
    spec:
      containers:
        - name: patch
          image: reg.chebai.org/kubernetes-ingress-controller/kube-webhook-certgen:v1.0.0
      serviceAccountName: ingress-nginx-admission
```

创建rbac, 关联`ServiceAccount`与`PodSecurityPolicy`。

```bash
# 0. `default-psp`会在rke部署集群的时候自动创建

# 1. `psp:unprivileged`在上一步已创建

# 2. 创建rolebinding `ingress-nginx-admission:psp:unprivileged`
# ingressNginx的Job创建的pod时，指定`serviceAccountName`为`ingress-nginx-admission`。需要将`ingress-nginx-admission`账户与创建的角色关联
# kubectl -n <Namespace> create rolebinding <Rolebinding-name> --role=<Role-name> --serviceaccount=<Namespace>:<ServiceAccount>
kubectl -n ingress-nginx create rolebinding ingress-nginx-admission:psp:unprivileged --role=psp:unprivileged --serviceaccount=ingress-nginx:ingress-nginx-admission
```



### 4.2 helm 部署ingress-nginx

```bash
helm install ingress-nginx ingress-nginx/ -n ingress-nginx
```



# Reference

[Pod 安全策略](https://kubernetes.io/zh/docs/concepts/policy/pod-security-policy/#run-another-pod)

