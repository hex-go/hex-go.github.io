---
title: Postman Test 脚本解析 JWT 验证 Claim
categories:
  - 个人工具
tags:
date: 2020-08-05 00:00:00
top: false
comments: true
---

# 重要

Postman 的 Tests 模块可以解析 JWT Token，在 Console 中查看 payload 内容，并将 claim 值设为环境变量供后续请求使用。

## 1.简介

测试 OAuth2 / OpenID Connect 接口时，需要验证返回的 JWT 中是否包含预期的 claim（如 `sub`、`iss`、`roles`），以及将 access_token 自动传递给后续请求。

## 2.说明

### 2.1 请求 Token

```bash
curl -X POST 'https://sso.example.com/auth/realms/app/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=password' \
  -d 'username=user' \
  -d 'password=xxx' \
  -d 'client_id=<client-id>' \
  -d 'client_secret=<client-secret>'
```

### 2.2 Tests 脚本

在 Postman 请求的 Tests 标签中添加：

```javascript
let jsonData = pm.response.json();
let jwtContents = jwt_decode(jsonData.access_token);

pm.environment.set("accessToken", jsonData.access_token);
pm.environment.set("userId", jwtContents.payload.sub);

console.log("Token Contents:\n" + JSON.stringify(jwtContents, null, 2));

function jwt_decode(jwt) {
    var parts = jwt.split('.'); // header, payload, signature
    return {
        header: JSON.parse(atob(parts[0])),
        payload: JSON.parse(atob(parts[1])),
        signature: atob(parts[2])
    };
}
```

| 方法 | 作用 |
|------|------|
| `pm.response.json()` | 解析响应体为 JSON |
| `jwt.split('.')` | JWT 由三部分 base64 组成：header.payload.signature |
| `atob()` | 浏览器内置方法，Base64 → 字符串 |
| `pm.environment.set()` | 设置 Postman 环境变量，后续请求通过 `{{accessToken}}` 引用 |

### 2.3 调试

脚本中的 `console.log` 输出到 Postman Console（`View` → `Show Postman Console` 或 `Ctrl+Alt+C`）。

## 3.参考

- [Postman Issue - 解析 JWT 并显示 claim](https://github.com/postmanlabs/postman-app-support/issues/1044)
- [Postman 官方文档 - Write Tests](https://learning.postman.com/docs/writing-scripts/test-scripts/)
