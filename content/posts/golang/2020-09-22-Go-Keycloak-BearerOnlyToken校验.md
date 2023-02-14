---
title: Go-Keycloak-BearerOnlyToken校验
categories:
  - Golang
tags:
  - Go
date: '2020-09-22 04:05:11'
top: false
comments: true
---

# 重要



**keycloak AccessToken验证过程**

1、解码 token（注意是解码，不是解密，因为token是不加密的，只是按照一定规则进行编码，并签名）。

2、取得配置的 publickey（含 kid），或根据配置的keycloak地址和realm信息，调用keycloak的Rest接口（ /realms/{realm-name}/protocol/openid-connect/certs）查询publicKey(含kid)。

3、从步骤2中得到的publicKey中，查找与步骤1中得到的kid匹配的publicKey。

4、如果找不到对应的publicKey，则报异常：Didn't find publicKey for specified kid。

5、使用publicKey验证签名

6、检查Token中的subject属性是否为空，为空则报异常：Subject missing in token

7、检查配置realm url 与 token中的issuer是否匹配，不匹配则报异常：Invalid token issuer. Expected {realm url}, but was {issuer}

7、检查token是否已过期，已过期，则报异常：Token is not active

token 中的内容

```json
{
  "exp": 1600417728,       							# Expiration time Token过期时间
  "iat": 1600417428,								# Issued at Token签发时间
  "jti": "541da01d-5fb8-4985-8ef7-9ebd6939c129",	# JWT ID
  "iss": "http://192.168.10.240:8082/auth/realms/icos",	# Issuer 签发者
  "aud": [
    "realm-management",
    "keycloakos",
    "account"
  ],
  "sub": "605b699b-65b9-4f63-87ae-fd1f14ff45a7",		# Subject 
  "typ": "Bearer",
  "azp": "icosdeploy",
  "session_state": "9b6c82bf-785a-4975-98bb-d5b1f7c04c03",
  "acr": "1",
  "realm_access": {
    "roles": [
      "admin"
    ]
  },
  "resource_access": {
    "realm-management": {
      "roles": [
        "query-groups"
      ]
    },
    "keycloakos": {
      "roles": [
        "admin"
      ]
    },
    "account": {
      "roles": [
        "view-profile"
      ]
    }
  },
  "scope": "openid profile email",
  "email_verified": false,
  "name": "a dmin",
  "groups": [],
  "preferred_username": "admin",							# 用户名
  "given_name": "a",
  "family_name": "dmin",
  "email": "admin@123.com"
}
```





# 环境说明

# 安装

# 使用

# Reference

[**Go 使用keycloak进行jwt认证**](https://vikaspogu.dev/posts/sso-jwt-golang/)

[**keycloak bearer-only clients: why do they exist?**](https://stackoverflow.com/questions/58911507/keycloak-bearer-only-clients-why-do-they-exist)

[在Keycloak中生成JWT令牌并获取公钥在第三方平台上验证JWT令牌](https://stackoverflow.com/questions/54884938/generate-jwt-token-in-keycloak-and-get-public-key-to-verify-the-jwt-token-on-a-t)

[Keycloak AccessToken 验证示例](https://www.janua.fr/keycloak-access-token-verification-example/)

[使用Keycloak和Spring Oauth2保护REST API](https://medium.com/@bcarunmail/securing-rest-api-using-keycloak-and-spring-oauth2-6ddf3a1efcc2)



[**golang使用jwt做身份验证**](https://auth0.com/blog/authentication-in-golang/#Authorization-with-Golang)



[OAuth 2.0授权框架](https://tools.ietf.org/html/rfc6749#section-4.4)

[Keycloak adaptor for golang application  (OIDC package)](https://stackoverflow.com/questions/48855122/keycloak-adaptor-for-golang-application)



[github OIDC Proxy](https://github.com/louketo/louketo-proxy/blob/master/docs/user-guide.md)

[github goth - 为编写身份验证提供了一种简单、干净和惯用的方法](https://github.com/markbates/goth)