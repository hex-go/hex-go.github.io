---
title: Go-Module实现go语言的插件机制
categories:
  - Golang
tags:
  - Go
date: '2020-07-23 07:43:17'
top: false
comments: true
---

# 重要
最近由于工作需求，需要统一调用各个系统的相同逻辑。并不想每集成一个服务就修改调用的代码，而是想实现插件机制。

利用go包的init特性，将示例插件注册，并在主程序中调用。
# 环境说明
代码结构如下：
```
└── src
    └── test
        ├── main.go
        └── adaptor
            ├── init.go
            └── standard
                └── imports.go
            └── cls1
                └── base.go
            └── cls2
                └── base.go
```
> [项目代码](https://github.com/hex-go/example-adaptor)
# 使用
## 类工厂 
> 具体文件: ./example-adaptor/adaptor/init.go
```go
package adaptor

// 定义接口
type Adaptors interface {
	CreateUser(user string) (status bool, err error)
	DeleteUser(user string) (status bool, err error)
	Policies() (status bool, err error)
}

var (
	// 插件字典
	FactoryByName = make(map[string]func() Adaptors)
)

// 注册插件
func Register(name string, factory func() Adaptors) {
	FactoryByName[name] = factory
}
```

## 插件类 `cls1` `cls2` 
> 具体文件： `adaptor/cls1/base.go` 和 `adaptor/cls2/base.go`
> 以cls1举例
```go
package cls1

import (
	"example/adaptor"
	"fmt"
)

// 定义 Cls1
type Cls1 struct {
	Name string
}

// 实现Class接口， 分别为 CreateUser DeleteUser Policies
func (g *Cls1) CreateUser(user string) (status bool, err error) {
	fmt.Println("Cls1 - create user: ", user)

	return true, nil
}

func (g *Cls1) DeleteUser(user string) (status bool, err error) {
	fmt.Println("Cls1 - Delete user: ", user)

	return true, nil
}

func (g *Cls1) Policies() (status bool, err error) {
	fmt.Println("Cls1 - get policies")

	return true, nil
}

// 导入时注册插件的方法
func init() {
	// 导入包时 注册 cls1
	adaptor.Register("Cls1", func() adaptor.Adaptors {
		return new(Cls1)
	})
}
```


## 导入包,实现插件自动注册到 Struct `FactoryByName` 
> 具体文件： ./example-adaptor/adaptor/standard/imports.go
```go
package standard

import (
	// 统一导入， 触发init() 实现自动注册
	_ "example/adaptor/cls1" // 匿名引用cls1包, 自动注册
	_ "example/adaptor/cls2" // 匿名引用cls2包, 自动注册
)
```

然后在项目入口文件处，导入`adaptor/standard`包即可
```go
package main

import (
	_ "example/adaptor/standard" // 统一导入，实现插件注册
	"example/api"
)

func main() {
	engine := api.Routers()
	_ = engine.Run(":8887")
}
```
# 

# 写新的插件
1. 创建插件类
创建包`cls-new`，并在包内做到这几件事：
+ 创建 struct `Cls-new`
+ 实现在adaptor中interface的方法
+ 在init方法中注册

2. 在`adaptor/standard`包处进行导入
> 文件路径: `adaptor/standard/imports.go`
```go
package standard

import (
	// 统一导入， 触发init() 实现自动注册
	_ "example/adaptor/cls1"
	_ "example/adaptor/cls2"
    _ "example/adaptor/cls-new"
)
```

# Reference

Useful [Go语言工厂模式自动注册](http://c.biancheng.net/view/92.html)
[借鉴caddy插件机制博客](https://mritd.me/2018/10/23/golang-code-plugin/)
[Go-Plugin机制说明、简单示例](https://www.jianshu.com/p/ad19dbc25e6c)
