# CNI / Flannel 学习笔记（私有）

## 用途

该文件记录 K8s 网络系列打磨过程中概念模糊、理解修正、面试复述版本等内容。

该文件不是博客正文，不用于发布。

---

## Flannel UDP 模式（2026-08-27）

### 问题1：目的主机上「flannel0 → cni0 → 容器」靠什么

**原始疑惑：**
- keypoint「剥离外层得原始报文 → flannel0（用户→内核）→ 宿主机路由 → cni0，封装 L2 头」哪里不严谨
- 接收侧是不是靠 `/16 dev flannel0` 路由进入 flannel0

**解释后理解：**
- 接收侧没有「路由到 flannel0」这一步：`flanneld` 直接把 L3 包写进 `flannel0`（TUN 与该进程绑定，用户→内核），内核当成「从 flannel0 口收到」
- 路由查找只发生**一次**：目的 IP 是本机子网，最长前缀直接命中 `/24 dev cni0`，不会碰 `/16`
- `/16 dev flannel0` 是**发送侧**路由：源节点去远端子网才用

**完整接收路径：**
```
① 内核剥外层 L2/L3/L4 → UDP 负载（原始 L3 报文）交给 flanneld
② flanneld 写回 flannel0（用户→内核）
③ 内核从 flannel0 口收到 L3 包
④ 路由查找命中 /24 dev cni0
⑤ 出设备是 L2 网桥 → 内核 ARP 封 L2 头（dst=容器 MAC，src=cni0 MAC）
⑥ cni0 CAM 转发 → veth → 容器
```

**理解状态：** ✅ 清晰

---

### 问题2：ARP 时查的是 cni0 的 CAM 吗

**原始疑惑：**
- 因为目标 dev 是 cni0，目标 MAC 是从 cni0 的 CAM 中查找？没有就广播 ARP？

**解释后理解（关键订正）：**
- 不是。ARP 时查的是**内核邻居表**（`ip neigh` / ARP 缓存），映射 **IP → MAC**
- cni0 的 **CAM/FDB** 是另一张表：**MAC → 端口**，网桥转发时才用

| 表 | 映射 | 谁用 | 何时用 |
|----|------|------|--------|
| 内核邻居表 | IP → MAC | 内核网络栈 | 封 L2 头之前 |
| cni0 CAM/FDB | MAC → 端口 | cni0 网桥 | 收到完整帧之后 |

**完整流程：**
```
① 内核要发 10.244.2.3 → 查邻居表（IP→MAC）
② 没有 → 广播 ARP 请求（dst=FF:FF:FF:FF:FF:FF）
③ cni0 把广播帧 flood 到所有端口 → 只有 10.244.2.3 回复
④ 目标容器单播回 ARP reply（src=容器 MAC，dst=cni0 MAC）
⑤ 内核写邻居表：10.244.2.3 → 容器 MAC（下次直接查表，不再广播）
⑥ 顺带：ARP reply 过 cni0 时，网桥从 src MAC 学到「容器 MAC → 端口」，写进 CAM
⑦ 内核封 L2 头（dst=容器 MAC，src=cni0 MAC）→ 交给 cni0
⑧ cni0 查 CAM → 转发到对应 veth → 容器
```

**一句话：ARP 是内核（邻居表）的事，CAM 是网桥（MAC→端口）的事；一次广播让两张表各自学习到自己的条目。**

**面试可复述版本：**
"跨节点包到达目的节点后，目的 Pod IP 的路由命中本机子网直连路由 `/24 dev cni0`。由于 cni0 是二层网桥，内核要先封以太网帧：查邻居表（ARP 缓存）拿目的容器 MAC，没有就广播 ARP 请求——网桥把广播 flood 到所有端口，目标容器回复，内核把结果写进邻居表；网桥则从 ARP reply 的源 MAC 学到 MAC→端口映射（CAM）。内核封好帧（dst=容器 MAC、src=cni0 MAC）交给 cni0，cni0 查 CAM 转发到对应 veth 进入容器。"

**理解状态：** ✅ 清晰

---

### 问题3：宿主机怎么知道 ARP 往哪发？（路由决定接口）

**原始疑惑：**
- 宿主机和容器不在同一个二层网络，宿主机 ARP 表没有目标容器 IP 时，直接广播 ARP 吗？
- 宿主机怎么知道往哪个子网 / 接口发 ARP？

**解释后理解（核心：ARP 跟路由走）：**
- ARP 不是全局广播，是**按接口广播**：内核查完路由表，得出「出接口 + 是否 on-link」，只在那个接口的广播域内发 ARP
- 两类路由决定「ARP 谁、在哪发」：
  - **直连路由**（`scope link`，如 `10.244.2.0/24 dev cni0`）→ ARP **目的 IP 本身**，在 cni0 上发
  - **网关路由**（`via`，如 `default via 192.168.1.254 dev eth0`）→ ARP **网关 IP**，在 eth0 上发
- 直连路由哪来：**接口配 IP 时内核自动生成**（cni0=10.244.2.1/24 → 自动建 `10.244.2.0/24 dev cni0 proto kernel scope link src 10.244.2.1`）。所以内核「知道」容器子网走 cni0，是配置出来的，不是主动感知
- 为什么不会发错子网：目的 IP 10.244.2.3 只匹配 cni0 的直连路由（不匹配 eth0 的 192.168.1.0/24），**最长前缀匹配**精确命中
- ARP 请求范围：只覆盖 cni0 这个网桥二层域（广播帧 flood 到所有 veth 端口 = 所有容器），不会跑到 eth0 的外网

**关键认识：宿主机其实维护着其上容器的 ARP 记录**
- 宿主机邻居表（`ip neigh`）里就存着「Pod IP → Pod MAC」——同一节点的容器，宿主机内核通过 cni0 上的 ARP 学到并维护这些记录
- 这正是「同节点容器互访也要过宿主机」的本质：veth 对端挂在 cni0，容器 eth0 的 MAC 对宿主机内核可见、可学、可维护（对称地，容器也维护「网关 cni0 IP → cni0 MAC」的记录）

**一句话：路由表说 on-link → 在该接口 ARP 目的 IP；说 via 网关 → 在该接口 ARP 网关 IP。ARP 永远跟路由表的出接口走，范围只在该接口的广播域内。**

**理解状态：** ✅ 清晰

---

### 问题4：路由的 via（下一跳）行为

**原始疑惑（认知盲区）：**
- Host-GW 跨节点走路由，路由的 `via` 会替换目的 IP 吗？
- 还是根据 via 的 IP 拿目的 MAC、不改 L3 头？

**解释后理解：**
- via **不替换目的 IP**，只决定「本跳把包交给谁」
- 处理流程：
  1. 最长前缀匹配 → 出接口 + 下一跳（via）
  2. 有 via → 发给 via IP；无 via（直连）→ 发给目的 IP 本身
  3. ARP 拿「发给谁」的 MAC
  4. 封 L2 帧：dst MAC = 下一跳 MAC，src MAC = 出接口 MAC
  5. **L3 头原封不动**（dst IP 始终是目的 Pod IP）
- 直连 vs via：

| 路由类型 | 下一跳 = 谁 | ARP 谁 |
|---------|------------|--------|
| 直连（无 via） | 目的 IP 本身 | 目的 IP |
| via 路由 | via IP | via IP |

- 核心原则：**IP 路由 = 每跳重封 L2 帧，IP 头永不动；改 IP 只发生在 NAT（SNAT/DNAT），纯路由从不改 IP**
- 下一跳思想的本质：路由器只需知道下一跳，不需要完整路径 → IP 网络可扩展的根源
- 特例：VXLAN 的 `via 10.244.2.0 dev flannel.1 onlink` 用占位 IP + onlink + proxy ARP，ARP 得到的是远端 VTEP MAC，但「ARP 下一跳、不改 IP」原则一致

**理解状态：** ✅ 清晰

**面试可复述版本：**
"路由的 via 是下一跳，不替换目的 IP。内核匹配路由后，如果路由有 via，就 ARP 下一跳的 MAC 并封装 L2 帧发给它；如果是直连路由，就 ARP 目的 IP 本身。整个转发过程 IP 头从不变，变的只有每跳 L2 帧的 MAC。只有 NAT 才会改写 IP。"

---

## 本次会话沉淀的关键事实

### IPIP 封装开销（订正）
- IPIP 开销 = **20B（外层 IP 头）**，不是 ~4B。4 是 IP 协议号（IP-in-IP = 4），不是字节数
- UDP 28B（IP 20 + UDP 8）/ VXLAN 50B（内层 MAC 14 + VXLAN 8 + UDP 8 + 外层 IP 20）/ IPIP 20B（外层 IP）

### 分层分类
- UDP = L3 over L4（用户态，仅演示）
- VXLAN = L2 over L4（内核态，生产通用）
- IPIP = L3 over L3（内核态，无 socket，走 IP 协议号 4 分发）

### VXLAN 两级查表
- ARP：VTEP IP → VTEP MAC（内层目的 MAC）
- FDB：VTEP MAC → 宿主机 IP（外层目的 IP）
- 均由 flanneld 从 etcd/K8S 预置，非运行时广播学习

### Calico 与 Flannel 关键区别
- Calico 所有模式不用网桥（VXLAN 用 per-pod 路由 + `vxlan.calico` VTEP）
- Flannel 所有模式保留 cni0 网桥

### 术语（全系列统一，勿回退）
- 数据平面 / 控制平面 / 转发方式 / 转发路径

---

## 待补

- Underlay：Flannel Host-GW（下一跳 = 目标节点 IP，要求 on-link / 同 L2 广播域）、Calico BGP
- Cilium：eBPF 数据平面
