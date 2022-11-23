---
title: 'Linux查漏补缺-3-特殊设备文件[loop,null,zero,full,random,tcp..]'
categories:
  - Bash
tags:
  - Bash
  - Linux
  - 特殊/dev
date: '2022-10-27 01:46:34'
top: false
comments: true
---
# 1.简介

> Linux查漏补缺，还剩：
> - 4-安装包管理[rpm/dpkg]
> - 5-proc程序查看说明
> - 6-磁盘格式化
> - 7-mount说明
> - 8-LVM
> - 9-账号管理与ACL

# 2.说明


# 3.总结


# 4.参考

Base

https://www.cnblogs.com/chengmo/archive/2010/10/25/1857775.html

Kernel - all /dev

https://www.kernel.org/doc/html/v4.20/admin-guide/devices.html

关于 /dev/tcp/${HOST}/${PORT}

https://www.jianshu.com/p/f10736931b93
https://ithelp.ithome.com.tw/articles/10221819


4-安装包管理[rpm/dpkg]

[第二十二章、软件安装 RPM, SRPM 与 YUM](https://linux.vbird.org/linux_basic/centos7/0520rpm_and_srpm.php)

5-proc程序查看说明

[16.3 程序管理](https://linux.vbird.org/linux_basic/centos7/0440processcontrol.php#process)

6-磁盘格式化与逻辑卷管理

[7.3 磁盘的分区、格式化、检验与挂载](https://linux.vbird.org/linux_basic/centos7/0230filesystem.php#disk)

8-LVM

[14.3 逻辑卷轴管理员 （Logical Volume Manager）](https://linux.vbird.org/linux_basic/centos7/0420quota.php#lvm)

7-mount说明

所谓的“挂载”就是利用一个目录当成进入点，将磁盘分区的数据放置在该目录下； 也就是说，进入该目录就可以读取该分区的意思。这个动作我们称为“挂载”，那个进入点的目录我们称为“挂载点”。

目录树与文件系统的关系：通过挂载，实现目录树的架构与磁盘内的数据(文件系统)结合。

[7.1.7 挂载点的意义 （mount point）](https://linux.vbird.org/linux_basic/centos7/0230filesystem.php#harddisk-mount)

[7.3.5 文件系统挂载与卸载： mount, umount](https://linux.vbird.org/linux_basic/centos7/0230filesystem.php#mount)

8-账号管理与ACL

[第十三章、Linux 帐号管理与 ACL 权限设置](https://linux.vbird.org/linux_basic/centos7/0410accountmanager.php)



