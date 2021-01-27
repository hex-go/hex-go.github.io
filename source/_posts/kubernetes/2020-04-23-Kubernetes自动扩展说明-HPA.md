---
title: Kubernetes自动扩展说明--HPA
categories:
  - Kubernetes
tags:
  - Kubernetes
  - draft
date: '2020-04-23 08:17:02'
top: false
comments: true
---

# 重要

## 概念说明：

HPA（Horizontal Pod Autoscaler）是kubernetes（以下简称k8s）的一种资源对象，能够根据某些指标对在statefulSet、replicaController、replicaSet等集合中的pod数量进行动态伸缩，使运行在上面的服务对指标的变化有一定的自适应能力。

HPA目前支持四种类型的指标，分别是Resource、Object、External、Pods。其中在稳定版本autoscaling/v1中只支持对CPU指标的动态伸缩，在测试版本autoscaling/v2beta2中支持memory和自定义指标的动态伸缩，并以annotation的方式工作在autoscaling/v1版本中。

## 问题记录：

+ 从网上直接找hpa的yaml文件，apiVersion一直不对。后改为`autoscaling/v1`正常，执行命令`kubectl api-versions | grep autoscaling | head -n 3`可获取，[参考链接](https://github.com/kubernetes/kubernetes/issues/45076#issuecomment-490665845)

+ Statefulset的hpa用命令创建一直失败，无法正常监控到pod资源使用。原因是 `spec.scaleTargetRef.apiVersion`字段缺失，补上并设置值为`apps/v1`(所监控的资源所在接口，比如Statefulset的接口为apps/v1)之后正常。[参考链接](https://github.com/kubernetes/kubernetes/issues/44033#issuecomment-380064796)

# 环境说明

Kubernetes: v1.15.6

> k8s版本不同，HPA的接口发生了变化。



# 安装

要想使用自动调度，需要安装`Metric Server`

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
```

## 示例yaml

```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: icos-icosinquery-sit-saas-1-0-0
spec:
  maxReplicas: 2
  minReplicas: 1
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: icos-icosinquery-sit-saas-1-0-0
  targetCPUUtilizationPercentage: 80
status:
  currentReplicas: 0
  desiredReplicas: 0

```



# 使用







# Reference

[探索Kubernetes HPA](https://zhuanlan.zhihu.com/p/89453704)

[K8S集群基于heapster的HPA测试](https://blog.51cto.com/ylw6006/2113848)

[Horizontal StatefulSet/RC Autoscaler](https://github.com/kubernetes/kubernetes/issues/44033#issuecomment-380064796)



