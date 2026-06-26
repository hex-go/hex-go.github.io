# 个人简历

## 基本信息

- **姓名**：Hex
- **求职意向**：基础平台研发工程师（容器方向）
- **地点**：西安 → 北京
- **邮箱**：hex-py@gmail.com
- **GitHub**：github.com/hex-go

## 技术能力

| 方向 | 技能 |
|------|------|
| 编程语言 | Go（主力，3 年+）、Python（3 年+） |
| Kubernetes | CRD / Operator 开发、client-go 二次开发、CNI 网络（Flannel/Calico/Cilium）、CSI 存储、Device Plugin、Scheduler Framework、PodSecurityPolicy |
| 容器 | Dockerfile 最佳实践、多阶段构建、非 root 运行、镜像安全扫描（trivy）、私有 Registry 部署 |
| 可观测性 | Prometheus + Grafana、日志采集（Filebeat Sidecar）、故障排查排障体系 |
| CI/CD | Jenkins Pipeline、GitLab CI、Drone、Tekton、Helm 部署 |
| 基础组件 | Etcd、Nginx（Ingress Controller）、CoreDNS、cert-manager、Keycloak |
| 计算机基础 | HTTPS / RSA / PKI / TCP、操作系统（Linux 启动流程、systemd、FHS、特殊权限） |

## 工作经历

### 某公司 — 云原生工程师（2022.01 ~ 至今）

**K8s 集群管理与定制**

- 负责多套 K8s 集群（rke/kubeadm）的部署、升级、节点维护，包括 RKE 定制化部署（非标 SSH 密钥、Docker 版本兼容处理、节点清理脚本）
- 解决 Flannel VXLAN 在 Linux 5.15 内核下 checksum offload 导致的跨节点 Pod 通信故障（抓包定位 bad udp cksum → ethtool 关闭 offload）
- 处理 ExternalDNS 高可用场景下 TCP/UDP 53 端口策略导致的 5 分钟超时问题（抓包分析 DNS 512 字节截断 → 修复安全组规则）
- 编写 CRD + Operator 实现自定义资源管理；基于 client-go 开发 Helm manifest 解析工具，将 K8s YAML 反序列化为 runtime.Object

**可观测性平台建设**

- 搭建 Prometheus + Grafana 监控体系，覆盖集群资源、Pod 状态、Ingress 流量等关键指标
- 设计 Sidecar 日志采集方案（Filebeat + emptyDir），解决业务自定义路径日志的集中采集问题
- 建立故障排查流程：防火墙 → iptables → 路由 → CNI → 抓包，覆盖网络、存储、调度全链路

**DevOps 平台开发**

- 基于 Jenkins Pipeline 共享库构建统一的 CI/CD 模板，支持代码拉取 → 构建 → Docker 镜像 → Helm 部署全流程，项目 Jenkinsfile 仅需声明 5 个参数
- 集成 trivy 镜像安全扫描到 CI 流水线中，使用 `--exit-code` 控制门禁阻断
- 维护私有 Registry + cert-manager 证书体系，支持 Harbor 镜像仓库的自动证书签发与更新

### 某公司 — SRE / DevOps 工程师（2018.01 ~ 2021.12）

**K8s 基础设施运维**

- 从零搭建公司 K8s 集群，完成 etcd 集群、CoreDNS、Ingress Controller 等核心组件部署与高可用配置
- 编写 PodSecurityPolicy 安全策略，结合 RBAC 实现命名空间级别的权限隔离
- 基于 Helm 管理应用生命周期，编写 Chart 模板支持多环境差异化部署

**CI/CD 流程建设**

- 搭建 Gogs + Drone 轻量 CI/CD 平台，替代 GitLab + Jenkins，降低资源占用约 60%
- 编写 Dockerfile 最佳实践文档（多阶段构建、非 root 运行、Alpine 选型分析）
- 集成 LDAP 统一认证到 Jenkins、Gogs、Grafana，实现单点登录和权限管理

**Python 安全平台开发（早期）**

- 开发 LDAP Python 操作库（ldap3），封装 OU/用户/组的 CRUD 操作和递归删除能力
- 基于 Flask + Flask-RestPlus + Swagger 开发 REST API 安全管理平台

## 开源项目 / 技术博客

- **技术博客**（hex-go.github.io）：系统梳理 K8s 网络 CNI 系列（概念/Flannel/Calico/Cilium）、K8s 存储 CSI 系列、Go GC 原理系列、PKI 证书链完整流程、RSA 算法原理等，累计 60+ 篇技术文章
- **Go 语言深度实践**：Module 插件机制、GMP 调度模型、内存逃逸分析、GC 三色标记与混合写屏障
- **GitHub**：cert-manager 集成示例、Go 工厂模式插件示例、LDAP Python 操作库

## 教育背景

- 本科 · 计算机相关专业
