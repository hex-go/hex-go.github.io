---
title: DevOps-trivy-镜像扫描汇总
categories:
  - Devops
tags:
  - Devops
  - 安全
  - 镜像扫描
  - Trivy
date: '2020-11-06 06:26:40'
pinned: true
top: false
comments: true
---

# 重要

trivy 用于扫描容器镜像的安全漏洞。

生产环境建议将漏洞库离线部署——将漏洞库打包进 Server 端镜像，内网独立运行。安全人员根据扫描结果升级基础镜像或 buildpack stack，将漏洞修复变成可计划、分期实施的过程。

在线库的缺点是：漏洞库随时更新，无法固定基线，不能采取"存在漏洞即阻断"的策略。

# 环境说明

- Trivy：v0.4.4

## 1.简介

trivy 是 Aqua Security 开源的容器镜像漏洞扫描工具，特点：

- 单二进制文件，安装简单
- 扫描速度快，秒级完成
- 支持多种 OS 包管理器和语言依赖
- 支持 Server-Client 模式，适合内网离线部署
- 可集成到 CI 流水线中

## 2.说明

### 2.1 安装

容器方式，无需安装二进制：

```bash
docker pull aquasec/trivy:0.4.4
alias trivy='docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $HOME/.cache/:/root/.cache/ \
  aquasec/trivy:0.4.4'
```

也可以直接下载二进制：

```bash
wget https://github.com/aquasecurity/trivy/releases/download/v0.4.4/trivy_0.4.4_Linux-64bit.deb
sudo dpkg -i trivy_0.4.4_Linux-64bit.deb
```

### 2.2 直接扫描（standalone 模式）

适用于开发机、CI 流水线。

```bash
trivy centos:centos7.8.2003
```

带参数扫描：

```bash
trivy --severity CRITICAL \
      --vuln-type os \
      --format json \
      --output /tmp/scan-report.json \
      centos:centos7.8.2003
```

| 参数 | 说明 |
|------|------|
| `--severity` | 过滤漏洞级别：UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL |
| `--vuln-type` | 漏洞类型：`os`（系统包）、`library`（语言依赖） |
| `--format` | 输出格式：`table`（默认）、`json`、`template` |
| `--output` | 结果输出到文件，不指定则输出到 stdout |
| `--ignore-unfixed` | 忽略暂未修复的漏洞 |
| `--cache-dir` | 漏洞库缓存路径 |

### 2.3 Server-Client 模式（离线场景）

内网环境无法直接访问 GitHub 更新漏洞库时，使用 Server-Client 模式。

{{< diagram >}}
[Trivy Server]                    [Trivy Client]
  内嵌离线漏洞库  <---- HTTP ---->   扫描指定镜像
  监听 0.0.0.0:4954                  --token 认证
{{< /diagram >}}

步骤：

获取离线漏洞库：

```bash
trivy --download-db-only
```

或者从 Release 页面下载：

- [trivy-db releases](https://github.com/aquasecurity/trivy-db/releases)
- [参考 issue](https://github.com/aquasecurity/trivy/issues/423)

启动 Server：

```bash
trivy server -d --listen 0.0.0.0:4954 --skip-update --token mail2Uyu
```

| 参数 | 说明 |
|------|------|
| `--listen` | 监听地址和端口 |
| `--skip-update` | 跳过漏洞库在线更新，使用已有离线库 |
| `--token` | 客户端连接时的认证令牌 |
| `-d` | 开启 debug 日志 |

Client 端扫描：

```bash
trivy client --remote http://trivy-server.svc.com:4954 \
             --token mail2Uyu \
             --cache-dir /root/.cache/trivy \
             --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL \
             --vuln-type os \
             --ignore-unfixed \
             --format json \
             --output /root/.cache/reports/scan_report.json \
             ubuntu:20.04
```

Client 端额外参数：

| 参数 | 说明 |
|------|------|
| `--remote` | Server 端地址 |
| `--token` | 与 Server 端保持一致 |

### 2.4 CI 流水线集成示例

Jenkins Pipeline：

```groovy
stage('Image Scan') {
    steps {
        sh '''
            docker pull ${IMAGE_NAME}
            docker run --rm \
              -v /var/run/docker.sock:/var/run/docker.sock \
              aquasec/trivy:0.4.4 \
              --severity HIGH,CRITICAL \
              --exit-code 1 \
              --format json \
              --output /tmp/trivy-report.json \
              ${IMAGE_NAME}
        '''
    }
}
```

`--exit-code 1` 表示发现 HIGH 或 CRITICAL 级别漏洞时返回非 0 退出码，Jenkins 据此判定流水线失败。

### 2.5 忽略误报漏洞

在 trivy 命令执行的同级目录下创建 `.trivyignore` 文件：

```text
# Accept the risk
CVE-2018-14618

# No impact in our settings
CVE-2019-1543
```

每行一个 CVE 编号，支持 `#` 注释。

### 2.6 与官方 Registry 集成（push 后自动扫描）

Docker 官方 Registry（`registry:2`）支持通过环境变量配置通知端点。镜像 push 后，Registry 向指定的 webhook 发送事件，可以借此触发 trivy 扫描。

启动 Registry 时配置通知：

```bash
docker run -d -p 5000:5000 --name registry \
  -e REGISTRY_NOTIFICATIONS_ENDPOINTS="
    {
      \"name\": \"trivy-scanner\",
      \"url\": \"http://trivy-hook.svc:8080/scan\",
      \"timeout\": \"60s\",
      \"threshold\": 5,
      \"backoff\": \"10s\",
      \"ignore\": {
        \"actions\": [\"pull\"]
      }
    }" \
  registry:2
```

| 字段 | 说明 |
|------|------|
| `name` | 通知端点名称 |
| `url` | webhook 接收地址（由 trivy 扫描服务监听） |
| `timeout` | 单次通知超时 |
| `threshold` | 失败重试上限 |
| `backoff` | 重试间隔 |
| `ignore.actions` | `pull`：仅 push 时触发，忽略 pull 事件 |

Registry 发出的 webhook JSON：

```json
{
  "events": [
    {
      "action": "push",
      "target": {
        "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
        "repository": "backend",
        "tag": "v1.2.3",
        "url": "http://registry:5000/v2/backend/manifests/v1.2.3"
      }
    }
  ]
}
```

webhook 接收端从 JSON 中提取 `repository` 和 `tag`，组装成镜像地址后调用 trivy：

```text
Registry push → webhook JSON → 提取 image:tag → trivy image registry:5000/<image>:<tag>
```

{{< keypoint >}}
官方 Registry 的通知机制不关心 webhook 接收端是什么——trivy 扫描、签名验签、合规检查都可以串在 `url` 后面。关键是 Registry 端只配 `push` 事件，避免 `pull` 事件触发无效扫描。
{{< /keypoint >}}

## 3.总结

1. 生产环境建议离线部署 Server-Client 模式，固定漏洞库版本基线；
2. 在线库随时变化，不适合作为门禁阻断条件；
3. CI 流水线中建议用 `--exit-code` 控制流水线成败；
4. 误报漏洞通过 `.trivyignore` 文件白名单处理。

## 4.参考

- [trivy GitHub](https://github.com/aquasecurity/trivy)
- [获取 trivy 漏洞库](https://github.com/aquasecurity/trivy/issues/423)
- [忽略特定的漏洞](https://github.com/aquasecurity/trivy#ignore-the-specified-vulnerabilities)
- [trivy 支持的 OS](https://github.com/aquasecurity/trivy#os-packages)
- [bug-使用厂商提供的危险等级](https://github.com/aquasecurity/trivy/issues/310)
- [issue-不能使用非官方源装包](https://github.com/aquasecurity/trivy/issues/403)
