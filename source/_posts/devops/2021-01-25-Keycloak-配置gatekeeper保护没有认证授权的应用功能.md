---
title: Keycloak-配置gatekeeper保护没有认证授权的应用功能
categories:
  - Devops
tags:
  - Devops
date: '2021-01-25 08:46:16'
top: false
comments: true
---

# 重要
虽然louketo-proxy停止开发，转向`oauth2proxy`。但由于`oauth2proxy`功能太弱。不适用此场景。继续选用louketo-proxy实现。

部署配置， 一共有三个组件（以nuclio举例）：
1. keycloak:    提供oauth2的认证源。在此处配置client、redirect_url、scope等
2. louketo-proxy: 作为proxy，代理所有走向`nuclio`的流量。与keycloak集成，没有权限的请求将被`proxy`拦截。
3. nuclio:        没有登录、授权的应用（一种faas平台）。

# 环境说明
keycloak:  10.0.2

louketo-proxy: v2.3.0

nuclio: 1.5.12

# 安装

> louketo-proxy启动的ingress地址对用户开放，名字应为proxy后面服务的真实地址，如代理proxy服务，则需设置为`faas.icos.city`。

## 1. 配置louketo-proxy

- `client-id`: 配置为keycloak服务中创建的`client-name`

- `client-secret`: 配置为keycloak服务中创建的`client`, 点击`credentials`获取。

- `discovery-url`: 注意修改keycloak地址和realm名。`<keycloak-address>/auth/realms/<realm-name>`

- `redirection-url`: 认证完成后，返回的访问地址，即`louketo-proxy`的ingress地址。注意，不带`oauth/callback`。

- `upstream-url`: louketo-proxy 后面的真实应用地址。

- `enable-refresh-tokens`: 允许refresh-token刷新token。
  
   > 用户访问应用，会重定向到Keycloak。 那里获得授权代码。 前端`louketo-proxy`将此授权代码交换为`access token`、`refresh token`，
   > 这些token放在前端的cookie中。 当使用过期的`access token`调用后端时，`refresh token`将被解密并用于获取新的`access token`。
   > `refresh token`可以过期或无效。 当返回401时，前端应刷新页面，以便将用户重定向到Keycloak。
   > 更安全的做法是将token存储在redis中, 而不是存储在前端Cookie中。

- `skip-upstream-tls-verify`: 跳过证书校验

- `skip-openid-provider-tls-verify`: 跳过证书校验

> proxy的chart  `value.yaml`如下：([proxy-chart文件](./images/charts/nuclio-proxy-1.0.0.tgz))

```yaml
#【----------------全局变量--------------------】
global:
  #  # 镜像仓库名称
  imageRepositoryName: reg.chebai.org

#【----------------镜像配置--------------------】
# 镜像
imageRepository: paas/louketo-proxy
  #版本要求3位数,不写默认从.Chart.appVersion拿
#imageTag: 5.6.10
  # 拉取镜像策略
imagePullPolicy: Always

#容器启动命令和参数
containersCommand: {}
containersArgs: '[
  "--client-id=<client-id>",
  "--client-secret=<client-secret>",
  "--discovery-url=<keycloak-address>/auth/realms/<realm-name>",
  "--enable-default-deny=true",
  "--secure-cookie=false",
  "--encryption-key=AgXa7xRcoClDEU0ZDSH4X0XhL5Qy2Z2j",
  "--enable-json-logging=true",
  "--enable-logging=true",
  "--enable-request-id=true",
  "--enable-security-filter=true",
  "--http-only-cookie=true",
  "--listen=0.0.0.0:8080",
  "--preserve-host=true",
  "--enable-logging",
  "--redirection-url=http://faas.example.com",
  "--upstream-url=http://nuclio-dashboard:8070",
  "--skip-openid-provider-tls-verify",
  "--skip-upstream-tls-verify",
  "--resources=uri=/*|methods=GET,POST,DELETE,PUT,HEAD|roles=nuclio:viewer"
  ]'

#【----------------服务配置--------------------】
#是否启动服务
serviceEnabled: true
  # 服务映射端口类型ClusterIP、NodePort
serviceType: NodePort
  # 服务
serviceName: nuclio-proxy
servicePorts:
# 容器内端口
- port: 8080
  protocol: "TCP"

ingressEnabled: true
ingressAnnotations:
  kubernetes.io/ingress.class: nginx

ingressAddns: false

ingressHosts:
- host: faas
  domain: example.com
  paths:
  - path: /
    servicePort: 8080

```

## 2. 配置keycloak

1. 配置client

    <img src="images/post-image/gatekeeper-keycloakclient-config.png" width="60%">

2. 配置Scope
   
    > 也可以直接通过Mappers配置audience,  ClientScope只是多封装了一层，好处是便于多个client共用。
    
    2.1 选择`icos`realm -- 点击`Client Scopes` -- 点击`Settings`
    
    - `name: ` 设置名字为`nuclio-service`
- `Protocol: ` 设置名字为`openid-connect`
    <img src="images/post-image/gatekeeper-ClientScope-1.png" width="60%">
    
    2.2 在`Client Scope`页面 -- 点击`Mappers`
    
    - `name: ` 设置名字为`nuclio-audience`
    - `Mapper Type: ` 设置为`Audience`
    - `Included Client: ` 输入`nuclio`，选择所要关联的client
    - `Add to access token: ` 将状态设置为`ON`
    
    <img src="images/post-image/gatekeeper-ClientScope-2.png" width="60%">
    
    2.3 返回`Clients`页面 -- 点击`nuclio` client -- 选择`Client Scopes`标签页 -- 选择`Setup`
    
    在`Available Client Scopes` 中选择刚创建的`nuclio-service` -- 点击`Add selected`
    

<img src="images/post-image/gatekeeper-ClientScope-3.png" width="60%">

   

3. 创建用户

并将



## 3. 部署nuclio

将`nuclio`的集群外部访问都删除，比如`ingress`、`nodeport`等，用户只能通过代理访问`nuclio-dashboard:8070`服务。


# 使用

# 遇到问题
1. `error redirect_url`报错： 

  > keycloak-client配置`redirect_url` 缺少`oauth/callback`,导致出现报错（keycloak端报错）

  - keycloak中需要设置为`http://<nuclio.acme.com>/oauth/callback`（也可以直接使用通配符，配置为`http://<nuclio.acme.com>/*`）
  - louketo-proxy启动时配置为`http://<nuclio.acme.com>/`。
2. 登录成功，但由于未配置`audience`字段aud，claim中的字段无法对应
导致如下报错(louketo-proxy 端报错)
```bash
 'aud' claim and 'client_id' do not match
```

3. 使用镜像supervisor启动，导致针对role的鉴权一直失败。

  换成`reg.chebai.org/paas/louketo-proxy:v1.0.0`之后一切正常。

4. keycloak服务端，注销session，需要重新无痕模式打开新的窗口生效。

  过期时间在生成accessToken时被服务端根据配置生成（服务端默认5分钟过期），并保存在cookie中。
  在无refreshToken干预的条件下，只有等过期时间（默认5分钟）结束才会过期，返回keycloak登录页面。

5. nuclio会在请求header中`x-nuclio-project-namespace: <namespace: eg. nuclio>`,来区分不同命名空间下的function, 后期可以结合`User Group`，来进行租户划分和授权管理。

  

# 后续
nuclio使用`louketo-proxy`进行鉴权，多租户管理。

# Reference

[gatekeeper git 仓库](https://github.com/louketo/louketo-proxy)

[gatekeeper 用户手册](https://github.com/louketo/louketo-proxy/blob/master/docs/user-guide.md)

[Keycloak-gatekeeper: 'aud' claim and 'client_id' do not match](https://stackoverflow.com/questions/53550321/keycloak-gatekeeper-aud-claim-and-client-id-do-not-match)

[Keycloak 文档 - Audience support](https://github.com/keycloak/keycloak-documentation/blob/master/server_admin/topics/clients/oidc/audience.adoc)

参考，理解类似gatekeepr、oauth2proxy这类工具的实现

[Open Policy Agent 文档](https://www.openpolicyagent.org/docs/latest/)

