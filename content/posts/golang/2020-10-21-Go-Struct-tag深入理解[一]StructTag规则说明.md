---
title: Go Struct Tag 深入理解 — Tag 规则说明
categories:
  - Golang
tags:
  - Go
date: 2020-09-01 00:00:00
top: false
comments: true
---

# 重要

Go 的 Struct Tag 是通过 `reflect.StructTag.Get(key)` 读取的 `key:"value"` 字符串。json 序列化、gorm ORM 映射、yaml 解析等底层都依赖 Tag。

## 1. Tag 书写规则

Tag 是一串以空格分隔的 `key:"value"` 对：

| 规则 | 说明 |
|------|------|
| key | 非空字符串，不含控制字符、空格、引号、冒号 |
| value | 双引号包裹的字符串 |
| 分隔符 | `:` 分隔 key 和 value，冒号前后不能有空格 |

```go
type Server struct {
    ServerName string `json:"server_name" gorm:"serverName" default:"example"`
    ServerIP   string `json:"server_ip"`
}
```

## 2. 通过 reflect 获取 Tag

```go
import "reflect"

s := Server{}
st := reflect.TypeOf(s)

fieldServerName := st.Field(0)
fmt.Println(fieldServerName.Tag.Get("json"))     // server_name
fmt.Println(fieldServerName.Tag.Get("default"))  // example
```

程序输出：

```text
TAG-key=>json     TAG-value=>server_name
TAG-key=>default  TAG-value=>example
TAG-key=>json     TAG-value=>server_ip
```

## 3. 常见 Tag 规则速查

| 包 | 常用 Tag | 示例 |
|----|----------|------|
| `encoding/json` | `json` | `json:"my_name,omitempty"` — 指定字段名 + 空值省略 |
| `gopkg.in/yaml.v2` | `yaml` | `yaml:"my_name"` |
| `encoding/xml` | `xml` | `xml:"my_name,attr"` |
| `github.com/jinzhu/gorm` | `gorm` | `gorm:"column:user_name;type:varchar(100)"` |
| `github.com/creasty/defaults` | `default` | `default:"example"` |

## 4. Tag 的作用

Tag 本身只是字符串，真正赋予它意义的是运行时通过 reflect 读取 Tag 的库。json 的 `Marshal`/`Unmarshal`、gorm 的表结构映射，都是基于同一个机制：`StructField.Tag.Get(key)`。

## 参考

- [Go struct tag 深入理解](https://my.oschina.net/renhc/blog/2045683)
- [Well known struct tags (golang wiki)](https://github.com/golang/go/wiki/Well-known-struct-tags)
