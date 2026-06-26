---
title: Jenkins 集成 LDAP 认证
categories:
  - Devops
tags:
  - DevOps
  - 安全
date: 2020-02-03 00:00:00
top: false
comments: true
---

# 重要

Jenkins 集成 LDAP 后本地认证失效。保存配置前务必测试 LDAP 连接，否则配置错误会导致无法登录。解决：备份 `config.xml`，或在 `<securityRealm>` 中恢复为本地认证。

## 1. LDAP 准备

创建测试组和账户：`jenkins-admin` 组添加 `admin`，`jenkins-manager` 组添加 `operator`。

## 2. 安装 LDAP 插件

| 方式 | 操作 |
|------|------|
| 在线安装 | Jenkins → 系统管理 → 插件管理 → 搜索 LDAP → 安装 |
| 离线安装 | 从 [官网](https://updates.jenkins-ci.org/download/plugins/) 下载 `.hpi`，上传安装 |

## 3. 配置 LDAP 认证

路径：`系统管理` → `全局安全配置` → 访问控制选择 `LDAP`。

关键配置项：

| 配置项 | 说明 |
|--------|------|
| Server | LDAP 服务器地址，如 `ldap://ldap.example.com:389` |
| root DN | 搜索根节点，缩小搜索范围提高性能 |
| User search base | 相对于 root DN 的搜索范围，如 `ou=People` |
| User search filter | 用户名对应 LDAP 属性，`uid={0}`（{0} 替换为用户输入的用户名） |
| Group search filter | 限制角色组搜索范围 |
| Manager DN | LDAP 不允许匿名访问时的认证 DN |
| Manager Password | 上面对应密码 |
| Display Name LDAP attribute | 显示名称，一般 `uid` |
| Email Address LDAP attribute | 邮箱属性，一般 `mail` |

配置完成后**不要立刻保存**，点击 `Test LDAP Settings` 验证配置正确性。

## 4. 配置分组授权

`全局安全设置` → `授权策略` → `安全矩阵`，为 LDAP 组分配 Jenkins 权限。

## 5. 误配置恢复

若 LDAP 配置错误导致无法登录，修改 `$JENKINS_HOME/config.xml`，将 `<securityRealm>` 替换为本地认证：

```xml
<securityRealm class="hudson.security.HudsonPrivateSecurityRealm">
  <disableSignup>false</disableSignup>
  <enableCaptcha>false</enableCaptcha>
</securityRealm>
```

重启 Jenkins 后使用本地账户登录。

## 参考

- [Jenkins LDAP 配置不当导致无法登录](https://www.58jb.com/html/jenkins_ldap_login_failure.html)
