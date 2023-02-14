---
title: Kubernetes中的uid和gid
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
Docker默认不启用user namespace, 所有的容器共用一个内核，所以内核控制的 uid 和 gid 则仍然只有一套。
如果容器内使用root用户，则容器内的进程与宿主机的root具有相同权限。会有很大的安全隐患，一旦容器有权限访问宿主机资源，则将具备宿主机root相同权限。

解决方法：

+ 1. 为容器中的进程指定一个具有合适权限的用户，而不要使用默认的 root 用户。

# uid说明

uid: 范围为0~65535（Ubuntu中为65533），0~999留给系统用户，普通用户为1000~65533. 

进程如果不声明uid，启动时以登录用户uid启动进程；进程可以声明任一存在或不存在的uid启动进程。
创建用户时若不指定uid, 默认就是直接从已存在的uid中找到最大的那个加1。

综上，
+ 每个uid不一定有对应的用户名
+ 每个用户一定有自己的uid
+ 每个进程必定有uid
+ 进程uid不指定，则与启动命令的用户uid一致
+ 创建用户uid不指定，则每多一个用户，uid会max+1递增。

容器中的进程uid\gid与宿主机的一致

# Reference
Ubuntu下的用户权限

[Ubuntu下的用户权限](https://blog.csdn.net/u012668018/article/details/37727517)

[/etc/passwd下的uid范围说明](https://blog.csdn.net/loryliu/article/details/24228045)

[/etc/passwd详细解释](https://blog.csdn.net/m0_37605642/article/details/97136282?utm_medium=distribute.pc_relevant_t0.none-task-blog-BlogCommendFromMachineLearnPai2-1.pc_relevant_is_cache&depth_1-utm_source=distribute.pc_relevant_t0.none-task-blog-BlogCommendFromMachineLearnPai2-1.pc_relevant_is_cache)

