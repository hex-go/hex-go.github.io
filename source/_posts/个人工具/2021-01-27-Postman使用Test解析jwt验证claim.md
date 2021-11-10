---
title: Postman使用Test解析jwt验证claim
categories:
  - 个人工具
tags:
  - 个人工具
  - postman
date: '2021-01-27 02:02:13'
top: false
comments: true
---

# 重要
最重要的事: 通过postman的`tests`模块解析jwt，从而在Console查看claim的值。

# 配置

在请求access-token的请求中，添加Tests脚本。请求示例如下
```bash
curl --location --request POST 'https://sso.icos.city/auth/realms/icos/protocol/openid-connect/token' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode 'grant_type=password' \
--data-urlencode 'username=hexiang' \
--data-urlencode 'password=xxxxxx' \
--data-urlencode 'client_id=<client-id>' \
--data-urlencode 'client_secret=<client-secret>'
```

<img src="/images/post-image/postman-tests-decode-jwt-2.png" width="60%">

增加的Test脚本如下
```javascript 1.8
let jsonData = pm.response.json();
// use whatever key in the response contains the jwt you want to look into.  This example is using access_token
let jwtContents = jwt_decode(jsonData.access_token);

// Now you can set a postman variable with the value of a claim in the JWT
pm.variable.set("someClaim", jwtContents.payload.someClaim);

function jwt_decode(jwt) {
    var parts = jwt.split('.'); // header, payload, signature
    let tokenContents={};
    tokenContents.header = JSON.parse(atob(parts[0]));
    tokenContents.payload = JSON.parse(atob(parts[1]));
    tokenContents.signature = atob(parts[2]);

    // this just lets you see the jwt contents in the postman console.
    console.log("Token Contents:\n" + JSON.stringify(tokenContents, null, 2));

    return tokenContents;
}
```

<img src="/images/post-image/postman-tests-decode-jwt-2.png" width="60%">


# Reference
[Issue - 在Tests中解析jwt并显示claim](https://github.com/postmanlabs/postman-app-support/issues/1044)

[Stack Overflow - 在Tests中解析jwt并修改claim值](https://stackoverflow.com/questions/52607165/how-to-open-a-jwt-token-on-postman-to-put-one-of-the-claims-value-on-a-variable)

[Stack Exchange - decoding-jwt-and-testing-results-in-postman](https://sqa.stackexchange.com/questions/41674/decoding-jwt-and-testing-results-in-postman)

[Postman 文档 - Write Tests](https://learning.postman.com/docs/writing-scripts/test-scripts/)


