---
title: Docker-理解容器中的uid和gid(一)
categories:
  - Devops
tags:
  - Devops
  - Draft
date: '2020-06-28 09:36:19'
top: false
draft: true
comments: true
---

# 重要
问题：[安全漏洞 CVE-2019-11245 ](https://nvd.nist.gov/vuln/detail/CVE-2019-11245)
容器中的进程默认以 root 用户权限运行，
Docker默认不启用user namespace, 所有的容器共用一个内核，所以内核控制的`uid`和`gid`则仍然只有一套（可通过容器与宿主机执行此命令`ps --pid 25138 -O uid,uname,gid,group,ppid`测试）。
如果容器内使用root用户，则容器内的进程与宿主机的root具有相同权限。会有很大的安全隐患，一旦容器有权限访问宿主机资源，则将具备宿主机root相同权限。

解决方法：

+ 1. 为容器中的进程指定一个具有合适权限的用户，而不要使用默认的 root 用户。
+ 2. 应用 Linux 的 user namespace 技术，配置 docker 开启 user namespace 隔离用户。

# 相关链接
[理解容器中的uid和gid(一)-Linux中的uid和gid.md]()

# 1. 配置合适的用户
此处只讨论为进程指定合适用户，指定合适用户的方法有以下两种：

> kubernetes中，PodSecurityContext要求用户必须为数字。[详细信息参考此链接。](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#users-and-groups)
>[Issue with mustrunasnonroot implementation PR:56503 #59819](https://github.com/kubernetes/kubernetes/issues/59819)

>> 避免容器内的uid与宿主机的uid重复。建议指定uid时使用20000~65533的数值

+ 在 `Dockerfile` 中指定用户身份

```dockerfile
# alpine 举例
# 3. 设定非ROOT的用户
RUN addgroup -S icos && adduser icos -u 2001 -S icos -G icos && su icos -s /bin/sh -c "mkdir -p /home/icos/config"

USER 2001
COPY --chown=icos:icos --from=builder /build/app /home/icos/app
```

+ 在 `Pod Security Policies` 中指定用户身份
```yaml
# deployment 举例
spec:
  template:
    spec:
      containers:
        securityContext:
          runAsUser: 2001                
```

> `Pod Security Policies`中的配置优先级更高，可以覆盖`Dockerfile`中的参数。

# Reference
容器这种uid说明

[理解 docker 容器中的 uid 和 gid](https://www.cnblogs.com/sparkdev/p/9614164.html)

[隔离 docker 容器中的用户](https://www.cnblogs.com/sparkdev/p/9614326.html)

[为pod设置权限和AccessControl](https://medium.com/kubernetes-tutorials/defining-privileges-and-access-control-settings-for-pods-and-containers-in-kubernetes-2cef08fc62b7)
