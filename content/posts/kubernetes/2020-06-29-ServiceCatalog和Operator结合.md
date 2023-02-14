---
title: ServiceCatalog和Operator结合
categories:
  - Kubernetes
tags:
  - Kubernetes
date: '2020-06-29 03:11:43'
top: false
comments: true
---
> 当下流行两种方式来为云原生应用提供后台服务： `Operators`和`Open Services Broker API`。本文比较两种技术，并针对性研究如何整合两者协同工作。

> 运行在Kubernetes集群上的工作负载，需要访问许多相同的服务集。因此，Kubernetes社区构建了对OSBAPI规范，并创建了`ServiceCatalog`项目
> 来提供Kubernetes集群内的服务市场。云计算服务API规范变成了OSBAPI(Open Service Broker API)。`Operator`是这一领域出现的新技术。

# Operators介绍
最近一段时间，`Operator`的人气飙升。原因很简单。`Operators`允许使用Kubernetes的开发人员直接使用Kubernetes集群中的托管服务。
随后，`Operator`模式经常被用作构建符合`OSBAPI`的`service broker`的替代方案。

Operator：
1. 是一组自定义资源定义(crd)，具有对其进行操作的自定义控制器。
2. 
# 重要

# 环境说明

# 安装

# 使用

# Reference
[Operator和OSBAPI的最佳结合](https://thenewstack.io/kubernetes-operators-and-the-open-service-broker-api-a-perfect-marriage/)