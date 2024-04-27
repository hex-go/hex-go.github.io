---
title: WSL网络配置-镜像网络
categories:
  - 个人工具
tags:
  - WSL
date: '2024-04-08 10:08:43'
top: false
comments: true
---

在此之前使用网桥的方案进行网络配置，实现局域网同网段访问WSL内服务的访问。

但最近一年左右，Windows11 出了一个更加优雅的新解决方案：“镜像网络”，利用了 Hyper-V 虚拟交换机的`镜像端口`技术。
随着此次更新，WSL2 2.0版本有以下功能更新：
- 自动回收空闲内存
- 自动回收虚拟硬盘空间
- 镜像网络
- DNS 代理隧道
- Windows 系统防火墙集成
- Windows 代理设置集成
这些功能极大的方便了对子系统服务发现和暴露管理，深度优化了在子系统进行网络开发方向的体验。

镜像网络和桥接网络，两个方案都具有无需关注端口转发，仅需关注更宏观的路由规则及防火墙设置的优势。

## 版本说明
```powershell
> wsl -v
WSL 版本： 2.1.0.0
内核版本： 5.15.137.3-1
WSLg 版本： 1.0.59
MSRDC 版本： 1.2.4677
Direct3D 版本： 1.611.1-81528511
DXCore 版本： 10.0.25131.1002-220531-1700.rs-onecore-base2-hyp
Windows 版本： 10.0.22631.3296

> wsl -l -v
  NAME            STATE           VERSION
* Ubuntu-22.04    Running         2
```

## wsl更新
> Windows 11 23H2 ++

```powershell
wsl --update --pre-release
```

## 配置网卡路由规则、防火墙规则

1. 允许外部路由设备进站到 WSLg/WSL2 子系统
> Hyper-V默认防火墙规则会阻挡同一局域网的访问请求，[参考此链接解决](https://learn.microsoft.com/zh-cn/windows/wsl/networking)

管理员权限在PowerShell窗口执行下面命令，修改Hyper-V防火墙规则，允许入站请求：
```powershell
Set-NetFirewallHyperVVMSetting -NXXame '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow
```

2. 允许 WSLg/WSL2 虚拟交换机进行路由转发，主要是一些极特殊环境会用到
> 好像每次重启都会失效(因此重启后需要再次配置)，但是我们可以把它编写成“PowerShell 脚本”放到“本地组策略”里，实现开机自动重新配置
> 本地组策略 -> 计算机策略 - Windows 设置 -> 脚本(启动/关机)
```powershell
Get-NetIPInterface |
Where-Object {$_.InterfaceAlias -match "^vEthernet\s.*(Default Switch|WSL|WSLCore|LAN).*$"} |
Set-NetIPInterface -Forwarding Enabled -ErrorAction SilentlyContinue
```

防火墙放行WSL的出入站规则（没用-未设置）
```powershell
New-NetFirewallRule -WSL-mirror" -Direction Inbound -InterfaceAlias "vEthernet (Default Switch)" -Action Allow
```

## 配置`~\.wslconfig`

# 此代码块用于创建或打开配置文件 ~\.wslconfig
> `hostAddressLoopback`是实验性功能。
> 默认情况下，在wsl2中开启的网络端口，会通过localhost映射到win11上，在win11宿主机通过localhost访问，但是无法通过宿主机的局域网、公网IP访问。
> 当这个选项设置为true之后，就会允许wsl与宿主机通过局域网、公网IP(仅支持分配给主机的 IPv4 地址)访问两者之间的服务，且保留了localhost访问的能力。

```powershell

if (-not (Test-Path -Path "~/.wslconfig")) { New-Item -ItemType File ~/.wslconfig }
pushd ~ ; code .wslconfig
```

```editorconfig
# 推荐的一些配置项如下
[wsl2]                      # 核心配置
autoProxy=false             # 是否强制WSL使用 Windows 代理设置（按需启用）
dnsTunneling=true           # WSL DNS 代理隧道，以便由 Windows 代理转发 DNS 请求（按需启用）
firewall=true               #WSL的 Windows 防火墙集成，以便 Hyper-V 或者 WPF 能过滤子系统流量（按需启用）
guiApplications=true        # 启用 WSLg GUI 图形化程序支持
ipv6=true                   # 启用 IPv6 网络支持
localhostForwarding=true    # 启用 localhost 网络转发支持
memory=4GB                  # 限制WSL的最大内存占用
nestedVirtualization=true   # 启用WSL嵌套虚拟化功能支持
networkingMode=mirrored     # 启用镜像网络特性支持
#pageReporting=true         # 启用WSL页面文件通报，以便 Windows 回收已分配但未使用的内存
processors=8                # 设置WSL的逻辑 CPU 核心数为 8（最大肯定没法超过硬件的物理逻辑核心数）


[experimental]                  # 实验性功能
autoMemoryReclaim=gradual       # 启用空闲内存自动缓慢回收
hostAddressLoopback=true        # 启用WSL和 Windows 宿主之间的本地回环互通支持
sparseVhd=true                  # 启用WSL虚拟硬盘空间自动回收
useWindowsDnsCache=false        # 和 dnsTunneling 配合使用，决定是否使用 Windows DNS 缓存池
```

## 配置`/etc/wsl.conf`

```editorconfig
# 此配置文件不能通过 cd /etc && ln -Ps /mnt/d/Devs/WSL/wsl.conf wsl.conf 来配置，只能通过拷贝副本
# https://docs.microsoft.com/en-us/windows/wsl/wsl-config

[automount]
enabled=true
mountFsTab=true
options="metadata,dmask=0022,fmask=0077,umask=0022"
root=/mnt/

[filesystem]
umask=0022

[interop]
enabled=true
appendWindowsPath=false   # 不添加 Windows 环境变量 Path，防止路径变量污染带来的干扰

# 其它网络配置
[network]
generateHosts=true
generateResolvConf=true


# boot command 暂不支持 nohup 后台启动
# command=nohup service cron start >/dev/null 2>&1 &
[boot]
# command=/root/.start.sh
systemd=true
```


## 重启WSL

```powershell
wsl --shutdown ; wsl
```

测试
```bash
# 查询子系统的 IP Address 地址
# 你将能看到一组和 Windows 宿主一致的双栈 IPv4/IPv6 地址及 MAC 地址
# Just enjoy it!
ip address show eth0

# 你可以使用 python 临时启动一个 Web 服务器测试网络连通性
python3 -m http.server -d . -b 0.0.0.0 54321

```

## WSL镜像网络，宿主机无法访问Docker容器问题
镜像网络，win11宿主机无法访问wsl中的容器

问题分析：
当启用镜像网络后，本地主机转发的行为与之前的有所不同

```
windows  --->  linux(WSL)                                 --->       Docker container
  localhostforwarding (until)
ok    127.0.0.1   ---> 127.0.0.1(lo)    /   172.x.x.1(br-xxx)  --->  172.x.x.x(eth0)
ok    127.0.0.1   <--- 127.0.0.1(lo)    /   172.x.x.1(br-xxx)  <---  172.x.x.x(eth0)

  netowrkingMode=mirrored
ok    127.0.0.1   ---> 127.0.0.1(loopback0)/127.0.0.1(br-xxxx) --->  172.x.x.x(eth0)
                                          ~~~~~~~~~
ng                                                           <- - -  172.x.x.x(eth0)
```
本地转发设置（默认）：源地址（Win11）是 docker 网络网关（=指向 linux）。

镜像网络设置：源地址是`127.0.0.1`，因此，数据包会返回到`127.0.0.1`（wsl上的localhost），而不会到达 Win11。如果从另一个主机访问，则没有问题，因为源地址就是他的IP地址。

1. 方案一(简单粗暴)

禁用 iptables，使用userland-proxy(用户空间代理)

禁用iptables后的数据流：

本地转发（默认）：
```
windows           --->     linux(WSL)
ok    127.0.0.1   --->     127.0.0.1(lo)
ok    127.0.0.1   <---     127.0.0.1(lo)
```
镜像流量
```
windows           --->     linux(WSL)
ok    127.0.0.1   --->     127.0.0.1(loopback0)
ok    127.0.0.1   <---     127.0.0.1(loopback0)
```


> userland-proxy 是一种在 Docker 容器与外部网络之间进行端口转发的机制，它直接在用户空间进行网络数据包的处理，而不依赖于 iptables。
> 缺点：
> 1. 性能很差，数据包在内核空间、用户空间之间切换传递。
> 2. 安全性差，无法对数据包进行过滤、转发、Nat等操作。
> 3. 功能受限，不支持端口映射、网络隔离等功能。
> 总之，iptables禁用后，类似于所有容器启动默认设置`--network=host`,几个容器的简单使用可以，但影响复杂场景的使用(比如端口复用)。

在`/etc/docker/daemon.json`中增加以下内容
```
{
    "iptables": false
}
```
并重启docker服务
```
service docker restart
```

2. 方案二
增加iptables规则，在`PREROUTING`阶段对来自`loopback0`接口且目的地址为`127.0.0.1`的数据包进行`DNAT`，将目的地址转换为`127.0.0.1`。添加此链目的是破坏`PREROUTING`钩子，并禁用`PREROUTING`链中设置的所有 Docker 规则。

https://gist.github.com/shigenobuokamoto/b565d468541fc8be7d7d76a0434496a0



以上两方案都是临时手段，仍等待后续官方解决方案。


详情请见[issue](https://github.com/microsoft/WSL/issues/10494)


## 参考连接

https://learn.microsoft.com/zh-cn/windows/wsl/wsl-config#configuration-settings-for-wslconfig

https://blog.gazer.win/essay/wsl2-mirrored-network.html

https://github.com/microsoft/WSL/issues/10494

