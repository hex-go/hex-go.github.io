---
title: jenkins-pipeline-lib使用
categories:
  - Devops
tags:
  - Devops
  - Jenkins
  - JenkinsFile
  - Pipeline
date: '2020-01-09 09:27:16'
top: false
comments: true
---

# 重要

# 定义共享库

## 目录结构
```
(root)
+- src                     # Groovy source files
|   +- org
|       +- foo
|           +- Bar.groovy  # for org.foo.Bar class
+- vars
|   +- foo.groovy          # for global 'foo' variable
|   +- foo.txt             # help for 'foo' variable
+- resources               # resource files (external libraries only)
|   +- org
|       +- foo
|           +- bar.json    # static helper data for org.foo.Bar
```

> `src`目录: Java 源目录结构。当执行流水线时，该目录被添加到类路径下。
> `vars`目录: 定义Pipeline中使用的全局变量。 `*.groovy`文件名=`variable-name`, `*.txt`该变量说明文档，内容可以是 Markdown 等，但扩展名必须为txt)。
> `resources`目录: 目录允许从外部库中使用`libraryResource`加载有关的非 Groovy 文件

## jenkins配置

### 全局共享库
> 全局可用 需要 `Overall/RunScripts` 权限配置这些库，权限过大，不安全。
`Manage Jenkins` » `Configure System` » `Global Pipeline Libraries`

![jenkins-add-lib](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/D5xXyc.jpg)

![global-pipeline-library-modern-scm](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/MPbG10.jpg)


## JenkinsFile引用共享库
> 1. 勾选` Load implicitly`, 可直接引用共享库中变量方法；
> 2. 不勾选，则需要使用`@Library`显式引用。

![jenkins-global-pipeline-lib](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/5TNzoe.jpg)

```groovy
@Library('my-shared-library') _
/* Using a version specifier, such as branch, tag, etc */
@Library('my-shared-library@1.0') _
/* Accessing multiple libraries with one statement */
@Library(['my-shared-library', 'otherlib@abc1234']) _
```

## 编写Pipeline-lib
### steps
共享库：
```groovy
// src/org/foo/Zot.groovy
package org.foo;

def checkOutFrom(repo) {
  git url: "git@github.com:jenkinsci/${repo}"
}

return this
```

jenkinsFile中引用: 
```groovy
def z = new org.foo.Zot()
z.checkOutFrom(repo)
```

### vars

```groovy
vars/log.groovy
def info(message) {
    echo "INFO: ${message}"
}

def warning(message) {
    echo "WARNING: ${message}"
}
```

```groovy
Jenkinsfile
@Library('utils') _

log.info 'Starting'
log.warning 'Nothing to do!'
```

# Reference
[jenkins 共享库官方文档](https://jenkins.io/zh/doc/book/pipeline/shared-libraries/)