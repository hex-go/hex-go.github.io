---
title: Ubuntu常见安装软件方式(ded、appimage、snap)说明.md
categories:
  - 个人工具
tags:
  - 个人工具
  - Ubuntu
  - snap
  - appimage
  - snap
date: '2020-04-23 09:09:56'
top: false
comments: true
---

# 重要
最重要的事: 



# 1.安装软件



## 1.1 通过软件中心安装

**Show Applications >> Search Ubuntu software center**.



## 1.2 安装.deb文件

[所有安装deb文件的方式](https://www.ubuntupit.com/cant-install-deb-files-ubuntu-heres-possible-ways-install-deb-packages/)

### 1.2.1 双击安装

双击`.deb`安装包，进入软件中心安装软件。

### 1.2.2 dpkg命令安装

```bash
dpkg -i XXX.deb
## 如果您得到任何依赖项错误，请运行下面的命令。它将修复所有的错误
apt install -f
## 删除应用
dpkg -r packagename.deb
## 重新配置/修复deb安装
dpkg-reconfigure packagename
```

### 1.2.3 apt命令安装

```bash
## 还有一种方法可以在Ubuntu系统上安装deb文件，apt-get工具。

sudo apt install ./name.deb
```



## 1.3 snap安装

​        Canonical为在任何Linux发行版上安装应用程序提供了跨平台的解决方案。这是一个通用的包管理系统，它提供了在任何Linux系统上运行软件所需的所有依赖项和库。

​        Ubuntu18.04之后都默认支持Snaps包。如果是Ubuntu 16.04和更老的版本环境，则在终端中运行以下命令来安装Snap包管理环境。

```bash
sudo apt install snapd
```

执行以下命令，通过snap安装软件

```bash
sudo snap install <package>
```



## 1.4 安装AppImage包

​        Deb软件包和RPM文件格式分别用于在Debian或Ubuntu和基于Fedora / SUSE的Linux发行版上安装软件。 对于应用程序开发人员来说，存在一个问题，他们必须为各种Linux发行版维护多个软件包。 为了克服这个问题，AppImage出现了，它为所有Linux发行版提供了通用的软件包管理系统。
​        AppImage文件格式类似于Windows系统中使用的.exe文件。但随着。AppImage格式，没有提取或安装，你删除AppImage，软件就会从Ubuntu中删除，双击AppImage就会运行该应用程序。

运行软件包，只用通过下面三步：

+ 下载`.appimage`格式的软件包。
+ 给次文件可执行权限。点击软件>>属性>>权限标签>>使其可执行，检查允许作为程序执行文件。
+ 双击运行。



### 1.5 通过apt命令安装

​        Ubuntu Linux上安装软件的另一种简单方法。就像从Ubuntu软件中心安装软件一样，命令行也类似于它。唯一不同的是Ubuntu软件中心是基于图形用户界面，apt命令是基于命令行界面。许多软件都提供了apt命令来安装软件 。

​       例如，Chromium浏览器有两种方式，Ubuntu软件中心和apt命令，可以在Ubuntu上安装它。如果你想安装它，那么去Ubuntu软件中心，通过关键字Chromium进行搜索，或者在终端中输入这个简单的apt命令。

```bash
## 创建应用
sudo apt install -y chromium-browser

## 删除应用
sudo apt chromium-browser
```



### 1.6 通过PPA安装应用

​        PPA个人软件包存档是另一种简单的方式来安装软件在Ubuntu Linux。许多开发人员希望直接向最终用户提供他们的软件的最新版本。在这种情况下，PPA可以作为Ubuntu官方软件仓库使用，需要一个月的时间在Ubuntu软件中心包含任何尖端软件。所以很多Ubuntu用户可能不会等待那么长时间，而是可以使用PPA立即安装最新版本。

举例：

```bash
sudo add-apt-repository ppa:embrosyn/cinnamon
sudo apt update
sudo apt install cinnamon
```

> 注意，这里总共遵循了三个命令。第一个用于将PPA知识库添加到系统s源列表中，第二个用于更新软件列表的缓存，最后一个用于使用PPA apt命令安装特定的软件。



# 2. 常用软件

**免费的密码管理软件：** `Bitwarden`

**Redis可视化工具：** `Redis Desktop Manager`

**OpenLDAP可视化工具：**

# Reference

[ubuntu安装软件说明](https://www.ubuntupit.com/how-to-install-software-in-ubuntu-linux-a-complete-guide-for-newbie/)