---
title: Kubernetes-ingress-nginx配置grpc服务
categories:
  - Kubernetes
tags:
  - Kubernetes
date: '2020-11-06 06:17:38'
top: false
comments: true
---

# 重要
ingress-nginx对于暴露grpc的服务，要求必须tls加密。所以，要么ingress配置grpcs,在服务端自己管理证书；要么ingress配置grpc,在ingress配置统一管理证书。

为便于运维管理证书，此处采用`cert-manager`统一在ingress配置中。自动生成证书，发布https服务。

# 环境说明
+ 

# 使用
1. 生成自签发CA证书，并保存在secret中(供cert-manager签发证书使用)；
2. 配置`cluster-issuer`,和`certificate`，使生成Secret，保存证书、ca和私钥；
3. 创建pod,service,ingress, ingress的tls配置使用第二步生成的Secret；
4. 执行命令测试grpc端口是否暴露成功；
```bash
grpcurl -insecure test.icos.city:443 build.stack.fortune.FortuneTeller/Predict
```

# Reference
以上1.2步参考cert-manager相关内容
[cert-manager hex-博客](https://hex-go.github.io/2020/11/05/kubernetes-2020-11-05-Kubernetes-certmanager%E8%A7%A3%E5%86%B3ingress-tls%E8%AF%81%E4%B9%A6%E9%97%AE%E9%A2%98/)
[cert-manager hex-github-示例项目](https://github.com/hex-go/cert-manager-example.git)

第3,4部参考`ingress-nginx`的官方示例，
[IngressNginx官房GRPC示例](https://github.com/kubernetes/ingress-nginx/tree/master/images/grpc-fortune-teller)

第3,4部也可参考cert-manager的示例代码测试
[cert-manager hex-github-示例项目](https://github.com/hex-go/cert-manager-example.git)

其他关于grpc的内容，需要参考此链接

[grpc_github](https://github.com/grpc/grpc) 

[grpc_go_quick_start](https://grpc.io/docs/languages/go/quickstart/) 

[grpc python quick-start](https://grpc.io/docs/languages/python/quickstart/) 

[grpc_java_quick-start](https://github.com/grpc/grpc-java)

[ingress-nginx-grpcExample](https://github.com/kubernetes/ingress-nginx/tree/master/docs/examples/grpc)

[ingress-nginx-grpc-DOC](https://kubernetes.github.io/ingress-nginx/examples/grpc/)

[ingress-nginx-grocExampleImage](https://github.com/kubernetes/ingress-nginx/tree/master/images/grpc-fortune-teller)
