---
title: Gogs + Drone 通过 Docker Compose 部署
categories:
  - Devops
tags:
  - DevOps
  - Docker
date: 2020-02-01 00:00:00
top: false
comments: true
---

# 重要

1. Drone 登录账号需要在 Gogs 中设为管理员，两者账密互通
2. Gogs 仓库自动同步到 Drone，需在 Drone 中激活该仓库
3. Drone 默认读取 `.drone.yml`，文件名不同时需在设置中修改

## 1. Gogs + Drone vs GitLab + Jenkins

| | Gogs + Drone | GitLab + Jenkins |
|------|-------------|------------------|
| 语言栈 | Go | Ruby + Java |
| 资源占用 | 低 | 高 |
| 复杂度 | 简单 | 功能强大但复杂 |

## 2. docker-compose 部署

```yaml
version: "2"
services:
  gogs:
    image: gogs/gogs:0.11.91
    ports:
      - 3000:3000
      - 10022:22
    volumes:
      - ./data/gogs/data:/data
    restart: always

  drone-server:
    image: drone/drone:1.6.1
    ports:
      - 8000:80
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data/drone/:/var/lib/drone
    environment:
      - DRONE_OPEN=true
      - DRONE_SERVER_HOST=drone-server:8000
      - DRONE_GOGS=true
      - DRONE_GOGS_SERVER=http://gogs:3000
      - DRONE_PROVIDER=gogs
      - DRONE_RPC_SECRET=7b4eb5caee376cf81a2fcf7181e66175
      - DRONE_USER_CREATE=username:admin,admin:true
    restart: always

  drone-agent:
    image: drone/agent:1.6.1
    depends_on:
      - drone-server
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DRONE_RPC_SERVER=drone-server:8000
      - DRONE_RPC_SECRET=7b4eb5caee376cf81a2fcf7181e66175
      - DRONE_RUNNER_CAPACITY=2
    restart: always
```

```bash
docker-compose up -d
```

Nginx 反向代理：

```nginx
server {
    listen 80;
    server_name drone.example.com;
    location / {
        proxy_pass http://drone-server:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

## 3. 流程

代码推送 → Gogs Webhook 通知 Drone → Drone 读取 `.drone.yml` → 执行 Pipeline。

## 参考

- [Drone 官方文档](https://drone.io/)
