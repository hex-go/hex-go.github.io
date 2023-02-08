---
title: 为博客添加 Gitalk 评论插件
categories:
  - 个人工具
tags:
  - Hexo
date: '2019-12-19 08:49:00'
sticky: 0
comments: true
---

# 前言
博客 **评论系统** 技术选型：

1.  Disqus 国内无法访问。
2.  [gitment](https://github.com/imsun/gitment)很久没有维护、更新。
3.  选用[Gitalk](https://github.com/gitalk/gitalk) 评论插件。



## Gitalk 说明

[Gitalk](https://gitalk.github.io/) 的界面和功能：

![image-20230206182144023](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/picgo/image-20230206182144023.png)
gitalk 使用 Github 帐号登录，界面干净整洁，且支持 `MarkDown语法`。

# 正文

## 1. 获取 Token
Gitalk 需要一个 **Github Application**，[点击这里申请](https://github.com/settings/applications/new)。

填写下面参数：

![image-20230208161904464](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/picgo/image-20230208161904464.png)

点击创建，获取 `Client ID` 和 `Client Secret` 之后填入 博客配置 Gitalk 部分

![image-20230208162254037](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/picgo/image-20230208162254037.png)

## 2. 博客配置

博客配置文件`source/_data/next.yml`，增加以下配置：


```html
<!-- Gitalk start  -->
{% if site.gitalk.enable %}
<!-- Link Gitalk 的脚本  -->
<link rel="stylesheet" href="https://unpkg.com/gitalk/dist/gitalk.css">
<script src="https://unpkg.com/gitalk@latest/dist/gitalk.min.js"></script>

<div id="gitalk-container"></div>
    <script type="text/javascript">
    var gitalk = new Gitalk({

    // gitalk的主要参数
		clientID: `Github Application clientID`,
		clientSecret: `Github Application clientSecret`,
		repo: `存储评论 issue 的 Github 仓库名（一般设置为 GitHub Page 的仓库名）`,
		owner: 'Github 用户名',
		admin: ['Github 用户名'],
		id: '页面的唯一标识。gitalk会根据这个标识，自动创建issue的标签',
    
    });
    gitalk.render('gitalk-container');
</script>
{% endif %}
<!-- Gitalk end -->
```

**主要参数**配置如下：

```yaml
clientID: `Github Application clientID`,
clientSecret: `Github Application clientSecret`,
repo: `Github 仓库名`,//存储评论 issue 的 Github 仓库名（建议直接用 GitHub Page 的仓库名）
owner: 'Github 用户名',
admin: ['Github 用户名'], //这个仓库的管理员，可以有多个，数组表示
id: 'window.location.pathname', //页面的唯一标识。gitalk 会根据这个标识，自动创建issue的标签，使用页面的相对路径作为标识
```
其他参数说明见[官方文档](https://github.com/gitalk/gitalk#options) 。比如，增加 **全屏遮罩** 的参数。

```
distractionFreeMode: true,
```




# 结语

遗留问题

Gitalk 需要点开每篇文章的页面，进行初始化issue创建。解决方案参考 [自动初始化 Gitalk 和 Gitment 评论](https://draveness.me/git-comments-initialize)。