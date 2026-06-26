---
title: GC 扩展篇——Java 分代回收与 Python 引用计数
categories:
  - Golang
tags:
  - GC
  - Go
  - Python
date: 2024-08-23 00:00:00
top: false
comments: true
series:
  - Go GC
---

# 重要

Java 的 GC 是"分代假设"的代表——认为大部分对象短命，按新生代/老年代分层回收。Python 则以引用计数为主力、标记清除为辅助、分代回收为优化。Go 走的是第三条路——逃逸分析把短命对象留在栈上，堆上不分代，直接并发标记清理。

## 1. Java 分代回收

### 1.1 为什么分代

Java 对象全在堆上。运行时收集到的数据显示：**大部分对象在年轻时死亡**（分代假设）。将堆分为新生代和老年代，可以对两个区域使用不同的回收策略。

```text
堆内存
├── 新生代（Young Generation）
│   ├── Eden 区        ← 新对象分配在此
│   ├── Survivor 0     ← 熬过 GC 的对象复制到此处
│   └── Survivor 1     ← 交替使用
└── 老年代（Old Generation） ← 熬过多轮 GC 的对象晋升至此
```

### 1.2 Minor GC 流程

新生代满时触发 Minor GC：

```text
Eden + Survivor From 中存活对象 → 复制到 Survivor To
对象年龄 + 1，年龄达到阈值 → 晋升到老年代
Eden + Survivor From 清空
Survivor To 和 Survivor From 角色交换
```

| 特性 | 新生代 | 老年代 |
|------|--------|--------|
| GC 类型 | Minor GC | Major / Full GC |
| 回收算法 | 复制算法 | 标记-清除 / 标记-整理 |
| 触发频率 | 高 | 低 |
| STW 时长 | 短（毫秒级） | 长（可达秒级） |
| 内存利用率 | 50%（复制算法需要两倍空间） | 高 |

### 1.3 常见收集器

| 收集器 | 目标 | 新生代算法 | 老年代算法 |
|--------|------|-----------|-----------|
| Serial | 单线程，客户端 | 复制 | 标记-整理 |
| Parallel | 吞吐量优先 | 并行复制 | 并行标记-整理 |
| CMS | 低延迟 | 并行复制 | 并发标记-清除 |
| G1 | 平衡延迟与吞吐 | 复制 | 标记-整理（Region 化） |

### 1.4 分代法的代价

| 代价 | 说明 |
|------|------|
| 跨代引用 | 老年代引用新生代对象时，新生代 GC 必须扫描老年代——引入**卡表（Card Table）**记录跨代引用 |
| 写屏障 | 维护卡表需要额外的写屏障 |
| 内存碎片 | CMS 标记-清除产生碎片，需要额外的整理阶段 |
| 晋升失败 | Survivor 空间不足或老年代满时触发 Full GC，STW 时间数倍于 Minor GC |

## 2. Python 引用计数 + 分代

### 2.1 引用计数——主力机制

Python 每个对象头部有一个 `ob_refcnt` 字段记录被引用次数。

```python
import sys
a = []
print(sys.getrefcount(a))  # 2：a 自身 + getrefcount 参数
b = a
print(sys.getrefcount(a))  # 3：a + b + getrefcount
del b
print(sys.getrefcount(a))  # 2
```

| 引用计数变化 | 触发操作 |
|-------------|----------|
| 对象创建 | refcnt = 1 |
| 赋值 / 传参 / 放入容器 | refcnt + 1 |
| 离开作用域 / `del` / 容器元素变更 | refcnt - 1 |
| refcnt = 0 | **立即回收** |

优点：实时回收，内存不会堆积。缺点也来自这里——每次引用变更都要更新计数。

### 2.2 循环引用——引用计数的死穴

```python
a = []
b = []
a.append(b)
b.append(a)
del a, b  # 两个对象的 refcnt 均为 1（互相引用），永远不会归零 → 内存泄漏
```

两个对象互相引用，形成引用环，`refcnt` 永远 ≥ 1——引用计数无法回收。

### 2.3 标记-清除——辅助机制

Python 的 `gc` 模块负责处理循环引用：

1. 收集所有容器对象（`list`、`dict`、`set` 等，不含 `int`、`str`）
2. 对每个对象，将 `refcnt` 减去其内部其他容器对象的引用数
3. 如果减法后 `refcnt = 0`，说明该对象只被容器内部引用——是循环引用的孤岛
4. 回收这些对象

### 2.4 分代——优化机制

Python 将对象分为 3 代：

| 代 | 对象特征 | GC 频率 |
|----|----------|---------|
| 0 代 | 新对象 | 最高 |
| 1 代 | 熬过 0 代 GC | 中等 |
| 2 代 | 长期存活 | 最低（长生命周期对象大概率不会变成垃圾） |

每一代的 GC 阈值可配置：

```python
import gc
print(gc.get_threshold())  # (700, 10, 10)
# 0代对象数 - 0代已删除数 > 700 时触发0代GC
# 每10次0代GC触发1次1代GC
# 每10次1代GC触发1次2代GC
```

### 2.5 GIL 与 GC

CPython 的 GIL 使得引用计数的增减天然线程安全——不需要原子操作或锁。但 GIL 也是 Python 多线程性能的瓶颈。

## 3. Go vs Java vs Python

| | Go | Java | Python (CPython) |
|------|-----|------|------|
| 主力回收机制 | 并发标记-清除 + 辅助清扫 | 分代复制/标记-整理 | 引用计数 |
| 辅助机制 | 混合写屏障 | 卡表写屏障 | 标记-清除（循环引用）+ 分代 |
| STW 时长 | < 100μs | ms ~ s 级 | 增量，几乎无全局 STW |
| 内存碎片 | 低（TCMalloc 分配器） | CMS 有碎片 | 引用计数回收粒度细 |
| 逃逸分析 | 编译期，栈上分配 | JIT 逃逸分析 | 无（全在堆） |
| 调优参数 | `GOGC`、`GOMEMLIMIT` | `-Xmx`、`-Xms`、收集器选择 | `gc.set_threshold()` |

三条路线的本质差异：

| 语言 | 设计哲学 | 为什么选这条路 |
|------|----------|---------------|
| Java | 堆上全分配 → 按年龄分层 | 对象全在堆上，分代假设自然成立 |
| Python | 引用计数为主力 + 标记清除兜底 | 简单直观，实时释放；循环引用用 GC 补 |
| Go | 逃逸分析削峰 + 并发标记清除 | 短命对象在栈上消失，堆上新生代不多 → 分代收益小 |

{{< keypoint >}}
Go 不做分代回收不是因为技术做不到，而是逃逸分析已经削掉了分代法的收益空间——短命对象根本不在堆上。
{{< /keypoint >}}

## 4. 总结

1. Java 分代回收基于"大部分对象短命"的假说，按年龄分层使用不同算法；
2. Python 引用计数实时回收，标记清除解决循环引用，分代优化 GC 频率；
3. Go 的逃逸分析使分代假说失效——短命对象在栈上，堆上对象生命周期偏长，不分代反而高效。

## 5. 参考

- [Java Garbage Collection Basics](https://www.oracle.com/webfolder/technetwork/tutorials/obe/java/gc01/index.html)
- [Python gc module](https://docs.python.org/3/library/gc.html)
- [Go GC Guide](https://tip.golang.org/doc/gc-guide)
