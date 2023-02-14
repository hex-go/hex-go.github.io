---
title: jenkins集成LDAP
categories:
  - Devops
tags:
  - Devops
  - Jenkins
  - LDAP
date: '2020-01-06 10:52:28'
top: false
comments: true
---
# 重要
> 1. ldap创建两个group`jenkins-admin`和`jenkins-manager`。并分别将用户`admin`， `operator`各自分配到两个组下。（ldapadmin工具操作用户分配组: 在用户条目上右键`View\Edit Group Membership`，选择要加入的组。
> 2. 配置之前备份一下config.xml配置文件，方便出错恢复。文件地址`/var/lib/jenkins_home/config.xml`。
> 3. Jenkins一旦集成LDAP认证就无法使用本地认证。因此在保存ldap配置之前多测试下ldap连接，否则配置错误就无法登录jenkins，参考后面，`解决错误配置ldap，导致无法登录问题`。
> 4. Jenkins 的`root DN`和`User search base`需要重点注意。

# 配置jenkins-ldap

## 0. LDAP准备
添加jenkins相关的测试账户和组
1. 在group这个ou里面创建2个组，名为jenkins-admin,jenkins-manager。
2. 在ou=people下面创建4个账户，名为admin,test01,test02,test03,配置好邮箱和密码。
3. 在三个组上面添加对应的用户， jenkins-admin组添加admin， jenkins-manager组添加operator用户
最终组织图如下：

![ldap-group+user](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/HOvgyq.jpg)

## 1. jenkins插件安装
使用LDAP认证需要安装LDAP插件，安装插件有两种方法：

方法一：后台插件管理里直接安装
> + 优点：简单方便，不需要考虑插件依赖问题
> + 缺点：因为网络等各种问题安装不成功
安装方法：登录Jenkins --> 系统管理 --> 插件管理 --> 可选插件 --> 搜索LDAP --> 选中 --> 直接安装 --> 安装完成重启

![jenkins-ldap](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/QR6yLk.jpg)
如果安装失败，网上也有说在插件管理 --> 高级 --> 升级站点里替换URL为`https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json`，但替换了之后依然没有成功，最后还是使用方法二安装成功

方法二：官网下载安装文件后台上传
> + 优点：一定可以安装成功的
> + 缺点：麻烦，要去官网找插件并解决依赖
插件下载地址：https://updates.jenkins-ci.org/download/plugins/

安装方法：官网下载插件 --> 登录Jenkins --> 系统管理 --> 插件管理 --> 高级 --> 上传插件 --> 选择文件 --> 上传 --> 安装完成后重启
上传插件安装可能会失败，大部分都是提示你当前插件依赖某些插件，只需要下载全部依赖插件，按照顺序上传安装即可，LDAP插件安装完成后，所有依赖的插件如下：

![jenkins-ldap-install](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/ngCjc3.jpg)

## 2. 配置LDAP认证
登录Jenkins --> 系统管理 --> 全局安全配置

![jenkin-global-sec-config](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/AxzuTf.jpg)

访问控制选择“LDAP”，Server输入LDAP服务器地址，有其他配置可以点击“Advanced Server Configuration...”

![image](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/wzPeQa.jpg)

说明：
+ **root DN**：这里的`root DN只`是指搜索的根，并非LDAP服务器的`root dn`。由于LDAP数据库的数据组织结构类似一颗大树，而搜索是递归执行的，理论上，我们如果从子节点（而不是根节点）开始搜索，因为缩小了搜索范围那么就可以获得更高的性能。这里的`root DN`指的就是这个子节点的DN，当然也可以不填，表示从LDAP的根节点开始搜索
+ **User search base**：这个配置也是为了缩小LDAP搜索的范围，例如Jenkins系统只允许ou为Admin下的用户才能登陆，那么你这里可以填写`ou=Admin`，这是一个相对的值，相对于上边的root DN，例如你上边的root DN填写的是dc=domain,dc=com，那么user search base这里填写了ou=Admin，那么登陆用户去LDAP搜索时就只会搜索ou=Admin,dc=domain,dc=com下的用户
+ **User search filter**：这个配置定义登陆的“用户名”对应LDAP中的哪个字段，如果你想用LDAP中的uid作为用户名来登录，那么这里可以配置为uid={0}（{0}会自动的替换为用户提交的用户名），如果你想用LDAP中的mail作为用户名来登录，那么这里就需要改为mail={0}。在测试的时候如果提示你user xxx does not exist，而你确定密码输入正确时，就要考虑下输入的用户名是不是这里定义的这个值了
+ **Group search base**：参考上边User search base解释
+ **Group search filter**：这个配置允许你将过滤器限制为所需的objectClass来提高搜索性能，也就是说可以只搜索用户属性中包含某个objectClass的用户，这就要求你对你的LDAP足够了解，一般我们也不配置
+ **Group membership**：没配置，没有详细研究
+ **Manager DN**：这个配置在你的LDAP服务器不允许匿名访问的情况下用来做认证，通常DN为cn=admin,dc=domain,dc=com这样
+ **Manager Password**：上边配置dn的密码
+ **Display Name LDAP attribute**：配置用户的显示名称，一般为显示名称就配置为uid，如果你想显示其他字段属性也可以这里配置，例如mail
+ **Email Address LDAP attribute**：配置用户Email对应的字段属性，一般没有修改过的话都是mail，除非你用其他的字段属性来标识用户邮箱，这里可以配置
+ **Enable Cache**: 当你的LDAP数据量很大或者LDAP服务器性能较差时，可以开启缓存，配置缓存条数和过期时间，那么在过期时间内新请求优先查找本地缓存认证，认证通过则不会去LDAP服务器请求，以减轻LDAP服务器的压力。

配置完成后，不要立刻保存，点击``Test LDAP Settings`验证配置的准确性。

![jenkins-test-ldap](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/nyOtqt.jpg)

这里输入的用户名就是你上边配置的User search filter里定义的LDAP中的属性, 本文配置的是uid 密码就是LDAP的密码

![jekins-ldap-test](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/V82dsx.jpg)


## 3. 配置ldap分组认证
操作步骤: 选择 `jenkins` -> `系统管理`-> `全局安全设置` -> `访问控制` -> `ldap` -> `授权策略`，选择安全矩阵授权策略。

![image](https://hex-cdn.oss-cn-hangzhou.aliyuncs.com/old/JqIa3X.jpg)


# 备注
## 解决错误配置ldap，导致无法登录问题
为方便用户管理，想通过ldap集中式认证，接入harbor， Gogs， Gitlab， Jenkins，省去每个系统分别创建账号，并管理的问题。但Jenkins集成LDAP配置不当导致Jenkins无法登陆。下面是解决办法：

1. 首先在配置LDAP之前，可以先备份配置文件`/var/lib/jenkins_home/config.xml`， ldap的配置只会影响这个文件，可以在无法登录时，重新还原该文件，并重启jenkins服务.
2. 如果没有备份该文件，也可以手动修改已变化的部分。在config.xml配置文件中找到这段关于ldap认证的信息：
```xml
<securityRealm class="hudson.security.LDAPSecurityRealm" plugin="ldap@1.20">
    <disableMailAddrexxxesolver>false</disableMailAddrexxxesolver>
    <configurations>
      <jenkins.security.plugins.ldap.LDAPConfiguration>
        <server>ldap://XXXXXX.com:389</server>
        <rootDN>dc=XXXXXX,dc=com</rootDN>
        <inhibitInferRootDN>false</inhibitInferRootDN>
        <userSearchBase></userSearchBase>
        <userSearch>uid={0}</userSearch>
        <groupMembershipStrategy class="jenkins.security.plugins.ldap.FromGroupSearchLDAPGroupMembershipStrategy">
          <filter>cn=jenkins</filter>
        </groupMembershipStrategy>
        <managerDN>uid=jarry,ou=People,dc=XXXXXX,dc=com</managerDN>
        <managerPasswordSecret>{AQAAABAAAAAQWfZrb7qoIjeM=}</managerPasswordSecret>
        <displayNameAttributeName>uid</displayNameAttributeName>
        <mailAddressAttributeName>mail</mailAddressAttributeName>
        <ignoreIfUnavailable>false</ignoreIfUnavailable>
        <extraEnvVars class="linked-hash-map">
          <entry>
            <string></string>
            <string></string>
          </entry>
        </extraEnvVars>
      </jenkins.security.plugins.ldap.LDAPConfiguration>
    </configurations>
    <userIdStrategy class="jenkins.model.IdStrategy$CaseInsensitive"/>
    <groupIdStrategy class="jenkins.model.IdStrategy$CaseInsensitive"/>
    <disableRolePrefixing>true</disableRolePrefixing>
  </securityRealm>
```
上面的配置不当无法通过ldap认证，jenkins也无法正常登陆。可以把上面一段替换成以下内容：
```xml
   <securityRealm class="hudson.security.HudsonPrivateSecurityRealm">
     <disableSignup>false</disableSignup>
     <enableCaptcha>false</enableCaptcha>
   </securityRealm>
```

# Reference
[Jenkins ldap配置不当导致无法登录](https://www.58jb.com/html/jenkins_ldap_login_failure.html)
[运维吧-ldap4-Jenkins集成OpenLDAP认证](https://www.cnblogs.com/37Y37/p/9430272.html)
[ldap-jenkins](https://www.cnblogs.com/zhaojiedi1992/p/zhaojiedi_liunx_52_ldap_for_jenkins.html)

