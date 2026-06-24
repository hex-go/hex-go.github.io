---
title: IngressController 启用证书透传
categories:
  - Kubernetes
tags:
  - Kubernetes
  - Ingress
date: '2021-01-22 11:44:08'
top: false
comments: true
---

# 重要

ingress-nginx 启用 SSL Passthrough（证书透传）需要两步：部署时加 `--enable-ssl-passthrough` 参数，Ingress 对象中设 `ssl-redirect: "false"`。

# 环境说明

- Kubernetes v1.15.6
- nginx-ingress-controller v3.21.0

## 1. 获取 Chart

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm pull ingress-nginx/ingress-nginx --version=3.21.0
```

## 2. 启用 SSL Passthrough

修改 chart 模板 `templates/controller-deployment.yaml`，在 Deployment args 中添加：

```yaml
args:
  - /nginx-ingress-controller
  - --enable-ssl-passthrough
```

> 该功能默认禁用。Chart 的 values.yaml 未单独暴露此参数，需要直接修改模板。

## 3. 配置 Ingress 对象

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    kubernetes.io/ingress.class: nginx
  name: app-tls-ingress
spec:
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 443
```

| 配置 | 作用 |
|------|------|
| `--enable-ssl-passthrough` | Controller 层面开启 TLS 透传 |
| `ssl-redirect: "false"` | 不对该 Ingress 做 HTTP → HTTPS 重定向 |

证书透传模式下，TLS 握手由后端服务完成，Ingress Controller 只做 TCP 转发。

## 参考

- [ingress-nginx SSL Passthrough](https://kubernetes.github.io/ingress-nginx/user-guide/tls/#ssl-passthrough)
