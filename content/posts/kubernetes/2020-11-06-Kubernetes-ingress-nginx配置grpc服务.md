---
title: Kubernetes-ingress-nginx 配置 gRPC 服务
categories:
  - Kubernetes
tags:
  - Kubernetes
  - Ingress
  - gRPC
date: 2020-06-16 00:00:00
top: false
comments: true
---

# 重要

ingress-nginx 暴露 gRPC 服务时要求必须使用 TLS。两种方案：

| 方案 | 证书位置 | 适用场景 |
|------|----------|----------|
| gRPCS（后端 TLS） | 服务端自己管理证书 | 微服务内部已统一证书 |
| gRPC（ingress TLS 终结） | Ingress 统一管理证书 | 运维集中管理，推荐 |

## 1.简介

gRPC 使用 HTTP/2 传输。ingress-nginx 的 gRPC 支持通过 annotation 开启，后端端口必须标记为 gRPC 协议。

## 2.说明

### 2.1 整体流程

```text
客户端 gRPC 请求（TLS）
    ↓
Ingress（TLS 终结，cert-manager 自动签发证书）
    ↓ annotation: nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
后端 gRPC Service（HTTP/2，纯文本）
```

### 2.2 前置：cert-manager 配置

ClusterIssuer 签发证书：

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
```

Certificate 申请证书：

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: grpc-cert
spec:
  secretName: grpc-tls
  dnsNames:
    - grpc.example.com
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
```

### 2.3 Ingress 配置

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grpc-ingress
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
spec:
  tls:
    - hosts:
        - grpc.example.com
      secretName: grpc-tls
  rules:
    - host: grpc.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grpc-service
                port:
                  number: 50051
```

关键配置：

| 配置 | 说明 |
|------|------|
| `backend-protocol: GRPC` | 告诉 ingress-nginx 使用 HTTP/2 连接后端 |
| `tls.secretName` | cert-manager 自动生成的证书 Secret |

### 2.4 测试

```bash
grpcurl -insecure grpc.example.com:443 build.stack.fortune.FortuneTeller/Predict
```

## 3.总结

1. gRPC over ingress-nginx 必须带 TLS；
2. 推荐 ingess TLS 终结方案——证书由 cert-manager 统一管理；
3. `backend-protocol: GRPC` annotation 是关键，缺少会报协议不匹配。

## 4.参考

- [cert-manager 博客](/posts/kubernetes/2020-11-05-kubernetes-certmanager解决ingress-tls证书问题/)
- [cert-manager 示例项目](https://github.com/hex-go/cert-manager-example.git)
- [ingress-nginx gRPC 示例](https://kubernetes.github.io/ingress-nginx/examples/grpc/)
