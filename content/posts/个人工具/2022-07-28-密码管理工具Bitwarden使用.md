---
title: 密码管理工具Bitwarden使用
categories:
  - 个人工具
tags:
  - 个人工具
date: '2022-07-28 07:07:32'
top: false
comments: true
---

# 重要
最重要的事: 

# 1.简介

## 1.1 从LastPass迁移至Bitwarden
[import-from-lastpass](https://bitwarden.com/help/import-from-lastpass/)

- lastPass导出 - Web端

左下角 `Advanced Options` - `Export`

- lastPass导出 - 浏览器插件

navigate to `Account Options` → `Advanced` → `Export` → `LastPass CSV File`


- Bitwarden导入

`Tools` - `Import Data` - `选择文件格式(lastPass CSV)` - `导入`


## 1.2 设置浏览器自动填充
[auto-fill-browser](https://bitwarden.com/help/auto-fill-browser/)

- 快捷键

Windows: `Ctrl + Shift + L`

MacOS: `Cmd + Shift + L`

Linux: `Ctrl + Shift + L`

- 页面加载时

浏览器插件图标，点击左键。`Setting` - `Options` - `Enable Auto-fill on Page Load`

## 1.3 Web端设置中文显示

`账号设置` - `偏好设置` - `语言`

`ACCOUNT SETTINGS` - `Preferences` - `Language`

## 1.4 Web端创建多层级文件夹

举例：
创建 `个人`， 再创建`个人/生活`

## 1.5 URI说明
[URI匹配说明](https://bitwarden.com/help/uri-match-detection/)

> 如果子域名相同(*.icos.city)，尽量不选择默认规则，否则无法区分。
> 规则间关系是且，而非或， 所以可以通过正则实现多个域名用一个用户名密码访问。

- 正则
> 只保证有唯一秘钥被匹配，下面正则并不严谨，但够用。这样自动填充就能、也只能填充唯一一个正确秘钥，节省时间。

URI规则： ^(http|https)://((gitlab|zentao|jenkins)\.icos\.city|(nextcloud|icoswiki)\.chebai.org)
可匹配项：
    - https://zentao.icos.city
    - https://gitlab.icos.city
    - https://jenkins.icos.city
    - http://icoswiki.chebai.org
    - http://nextcloud.chebai.org

## 1.6 Web修改未同步至浏览器插件

手动同步

左键点击插件图标，点击右下角`Setting` - 点击上方 `Sync`按钮 手动同步

# Reference


[Web端访问地址](https://vault.bitwarden.com/)

[官方说明文档](https://bitwarden.com/help/)

[Bitwarden 帮助中心中文版](https://help.ppgg.in/auto-fill/using-uris#regular-expression)
