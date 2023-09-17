---
title: Docker-理解容器中的uid和gid(二)-Kubernetes中使用uid
categories:
  - Devops
tags:
  - Devops
  - Kubernetes
  - Docker
date: '2020-06-28 09:36:19'
top: false
comments: true
---

# 重要
问题：[安全漏洞 CVE-2019-11245 ](https://nvd.nist.gov/vuln/detail/CVE-2019-11245)
容器中的进程默认以 root 用户权限运行，
Docker默认不启用user namespace, 所有的容器共用一个内核，所以内核控制的 uid 和 gid 则仍然只有一套。
如果容器内使用root用户，则容器内的进程与宿主机的root具有相同权限。会有很大的安全隐患，一旦容器有权限访问宿主机资源，则将具备宿主机root相同权限。

# 相关链接
[理解容器中的uid和gid(一)-Linux中的uid和gid.md]()

[理解容器中的uid和gid(二)-Docker容器中的uid和gid.md]()

# 常见问题
## 1. pod中uid与宿主机冲突产生问题
因为一个原因：

当pod设置`runAsNoneroot`，容器uid与宿主机uid一样，但username不一致时。会触发报错 
```Error: container has runAsNonRoot and image has non-numeric user (kong), cannot verify user is non-root```
原因待定位，现猜测 pod设置`runAsNoneroot`会获取容器uid,此时的user会变成宿主机的用户名，之后根据宿主机用户名在容器内获取uid时

尽量要避免容器内的uid与宿主机的uid重复。所以建议在指定uid时，使用20000~65533的数值。

# 3. 使用securityContext设置挂卷文件权限
当设置runAsNoneRoot后，往往会带来权限问题。比如有些私有云挂卷后，权限默认给的755权限。此时普通用户没有写权限，导致无法使用。所以需要

# 总结
还有一种方式，解决uid未隔离导致的安全问题问题。但未做测试。

- docker 开启`user namespace`隔离用户

[隔离 docker 容器中的用户](https://www.cnblogs.com/sparkdev/p/9614326.html)

# Reference

理解 k8s 中 SecurityContext

[k8s文档--为pod配置安全性上下文](https://kubernetes.io/zh/docs/tasks/configure-pod-container/security-context/)

[源码剖析--SecurityContext](https://developer.aliyun.com/article/777651)

**[docker挂载volume的用户权限问题](https://www.cnblogs.com/woshimrf/p/understand-docker-uid.html)**

[Docker mounting volume. Permission denied](https://stackoverflow.com/questions/47197493/docker-mounting-volume-permission-denied)

k8s挂载宿主机卷解决权限问题：securityContext fsgroup

为非root用户启动的pod挂卷

[Add ability to mount volume as user other than root](https://github.com/moby/moby/issues/2259)

[Volumes are created in container with root ownership and strict permissions](https://github.com/kubernetes/kubernetes/issues/2630)

[stack overflow k8s 设置挂卷的userGroup和文件权限](https://stackoverflow.com/questions/43544370/kubernetes-how-to-set-volumemount-user-group-and-file-permissions)

