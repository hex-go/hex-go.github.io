---
title: Go Module 实现插件机制
categories:
  - Golang
tags:
  - Go
  - 设计模式
date: 2020-05-10 00:00:00
top: false
comments: true
---

# 重要

利用 Go 的 `init()` 函数 + 匿名导入（`_ "pkg"`）实现编译期插件注册。新增插件只需写一个包并在入口处 `import`。

# 环境说明

- Go 1.20

项目结构：

```text
src/
└── example/
    ├── main.go
    └── adaptor/
        ├── init.go          ← 接口定义 + 注册表
        ├── standard/
        │   └── imports.go   ← 统一导入所有插件
        ├── cls1/
        │   └── base.go      ← 插件 1
        └── cls2/
            └── base.go      ← 插件 2
```

[完整代码](https://github.com/hex-go/example-adaptor)

## 1. 定义接口和注册表

`adaptor/init.go`：

```go
package adaptor

type Adaptors interface {
    CreateUser(user string) (bool, error)
    DeleteUser(user string) (bool, error)
    Policies() (bool, error)
}

var FactoryByName = make(map[string]func() Adaptors)

func Register(name string, factory func() Adaptors) {
    FactoryByName[name] = factory
}
```

## 2. 编写插件

`adaptor/cls1/base.go`：

```go
package cls1

import "example/adaptor"

type Cls1 struct{ Name string }

func (g *Cls1) CreateUser(user string) (bool, error) {
    return true, nil
}
func (g *Cls1) DeleteUser(user string) (bool, error) {
    return true, nil
}
func (g *Cls1) Policies() (bool, error) {
    return true, nil
}

// init() 在包被导入时自动执行，将插件注册到全局表
func init() {
    adaptor.Register("Cls1", func() adaptor.Adaptors {
        return new(Cls1)
    })
}
```

## 3. 统一导入

`adaptor/standard/imports.go`：

```go
package standard

import (
    _ "example/adaptor/cls1"
    _ "example/adaptor/cls2"
)
```

## 4. 入口文件

```go
package main

import (
    _ "example/adaptor/standard" // 触发所有插件的 init()
)

func main() {
    // FactoryByName 中已有 cls1、cls2
    plugin := adaptor.FactoryByName["Cls1"]()
    plugin.CreateUser("test")
}
```

## 5. 新增插件

1. 创建 `adaptor/cls-new/base.go`——实现接口 + `init()` 注册
2. 在 `adaptor/standard/imports.go` 中增加 `_ "example/adaptor/cls-new"`

无需修改 `main.go` 或 `init.go`。

## 参考

- [Go 语言工厂模式自动注册](http://c.biancheng.net/view/92.html)
- [借鉴 Caddy 插件机制](https://mritd.me/2018/10/23/golang-code-plugin/)
