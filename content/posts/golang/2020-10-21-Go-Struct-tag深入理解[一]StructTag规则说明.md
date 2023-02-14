---
title: Go-Struct-tag深入理解[一]StructTag规则说明
categories:
  - Golang
tags:
  - Go
date: '2020-10-21 09:07:42'
top: false
comments: true
---

# 前言

Go 语言中`Struct`声明包含三部分: `field_name`, `field_type`, `field_tag`.

`field_tag`的作用:

+ 可以作为字段后额外的注释或者说明

+ 在反射场景下, `reflect`包中提供了操作`tag`的方法, `tag`的写法需要遵循一定规则.



# 使用

### Tag 书写规则

`tag`是一串字符串, 以空格分隔的`key:"value"`对.

+ `key`: 为非空字符串, 字符串不含控制字符\空格\引号\冒号.
+ `value`: 以双引号标记的字符串.
+ 以`:`分隔,并且冒号前后不能有空格.

```go
type Server struct {
    ServerName string `json: "server_name" gorm:"serverName" default:"example"`
    ServerIP   string `json: "server_ip"`
}
```



### reflect获取Tag值

`StructTag`提供了`Get(key string) string`方法来获取`Tag`，示例如下：

```go
package main

import (
    "reflect"
    "fmt"
)

type Server struct {
    ServerName string `json: "server_name" gorm:"serverName" default:"example"`
    ServerIP   string `json: "server_ip"`
}

func main() {
    s := Server{}
    st := reflect.TypeOf(s)

    fieldServerName := st.Field(0)
    fmt.Printf("TAG-key=>json     TAG-value=>%v\n", fieldServerName.Tag.Get("json"))
    fmt.Printf("TAG-key=>default  TAG-value=>%v\n", fieldServerName.Tag.Get("default"))

    fieldServerIp := st.Field(1)
    fmt.Printf("TAG-key=>json     TAG-value=>%v\n", fieldServerIp.Tag.Get("json"))
}
```

程序输出如下：

```go
TAG-key=>json     TAG-value=>server_name
TAG-key=>default  TAG-value=>example
TAG-key=>json     TAG-value=>server_ip
```



### Tag的作用

使用反射可以动态的给结构体成员赋值，正是因为有tag，在赋值前可以使用tag来决定赋值的动作。 比如，官方的`encoding/json`包，可以将一个JSON数据`Unmarshal`进一个结构体，此过程中就使用了Tag. 该包定义一些规则，只要参考该规则设置tag就可以将不同的JSON数据转换成结构体。

总之：正是基于struct的tag特性，才有了诸如json数据解析、orm映射等等的应用。理解这个关系是至关重要的。或许，你可以定义另一种tag规则，来处理你特有的数据。



### Tag使用举例

| 包      | 包中关于tag的规则                         | full example                                                 |
| ------- | ----------------------------------------- | ------------------------------------------------------------ |
| json    | https://godoc.org/encoding/json#Marshal   | "my_name,omitempty" 声明名字+可省略<br>",omitempty" 值为空则省略此字段<br>"my_name"  在json中此字段的键<br>"-"  字段始终省略 |
| default | https://github.com/creasty/defaults#usage |                                                              |
| gorm    | https://godoc.org/github.com/jinzhu/gorm  | https://www.cnblogs.com/zisefeizhu/p/12788017.html#%E7%BB%93%E6%9E%84%E4%BD%93%E6%A0%87%E8%AE%B0tags |
| yaml    | https://godoc.org/gopkg.in/yaml.v2        |                                                              |
| xml     | https://godoc.org/encoding/xml            |                                                              |





# Reference

[Go struct tag深入理解(华为)](https://my.oschina.net/renhc/blog/2045683)

[Go语言中的struct tag(知乎)](https://zhuanlan.zhihu.com/p/32279896)

[Well known struct tags(golang wiki)](https://github.com/golang/go/wiki/Well-known-struct-tags)

[gorm 结构体的相关标记](https://www.cnblogs.com/zisefeizhu/p/12788017.html#%E7%BB%93%E6%9E%84%E4%BD%93%E6%A0%87%E8%AE%B0tags)

