---
title: golangci-lint常见报错说明及修复建议
categories:
  - Golang
tags:
  - Go
date: '2022-08-04 02:02:09'
top: false
comments: true
---

# 重要

# 环境说明

# 问题

## 1. Implicit memory aliasing in for loop
> 报错意思是：在循环中重复使用变量的地址     [参考链接](https://stackoverflow.com/questions/62446118/implicit-memory-aliasing-in-for-loop)
> 因为for语句中变量是被重用的，即变量内存地址不变，但值发生变化。当取消引用指针时，值可能发生改变，所以静态检查报错

### 1.1 错误写法
```go
for i, v := range versions {
    res := createWorkerFor(&v)
    ...
}
```
### 1.2 正确写法

- for循环中使用元素的实际地址i,而非迭代变量取值（**推荐**）

```go
for i := range versions {
    res := createWorkerFor(&versions[i])
}
```

- 在每次循环时重新初始化迭代变量

```go
for _, v := range versions {
    v := v
    res := createWorkerFor(&v) // this is now the address of the inner v
}
```

- 使用闭包

```
for _, v := range versions { 
    go func(arg ObjectDescription) {
        x := &arg // safe
    }(v)
}
```



## 2. commentFormatting: put a space between `//` and comment text

> 注释后面需要加空格

### 2.1 错误写法

```go
//UpdatePatch update patch - edit qlet`s information, and generate a new version patch
```

### 2.2 正确写法

```go
// UpdatePatch update patch - edit qlet`s information, and generate a new version patch
```

### 2.3 IDE配置

goland中，可以点击`File` - `Settings` - `Editor` - `Code Style` - `Go` -`Other`下，勾选`Add a leading space to comments`。可以实现注释代码时自动在`//`后加空格。



## 3. Consider preallocating (prealloc) lint

> 考虑 预先分配问题        [参考链接](https://stackoverflow.com/questions/59734706/how-to-resolve-consider-preallocating-prealloc-lint)
>
> 使用make预先分配合理的内存空间，能减少复制和扩展。

### 3.1 错误写法

```go
var to []string
for i := range s.To {
    to = append(to, s.To[i].String())
}
```

### 3.2 正确写法

```go
to := make([]string, 0, len(s.To))
for i := range s.To {
    to = append(to, s.To[i].String())
}
```

或者干脆使用append，直接对切片对象赋值

```go
to := make([]string, len(s.To))
for i, t := range s.To {
    to[i] = t.String()
}
```



## 4. should replace errors.New(fmt.Sprintf(…)) with fmt.Errorf(…)
> go 1.13之后，推荐使用fmt.Errof("%w",err)来生成error

### 4.1 错误写法
```go
errors.New(fmt.Sprintf("error is %s", err.Error()))
```

### 4.2 正确写法
```go
fmt.Errorf("error is %w", err)
```

## 5. error strings should not be capitalized or end with punctuation or a newline
> error 信息不应该:  以大写字母开头 或 以标点符号\换行结尾。

## 6. don’t use MixedCaps in package name
> 包的名称不能大小写混写，应全小写

### 6.1 错误写法
```
package fileUtils
```
### 6.2 正确写法
```
package fileutils
```

## 7. exported type T should have comment or be unexported
> 暴露出去的结构体或方法，应该加注释或不对外暴露。


## 8. comment on exported type U should be of the form "U .."
> 暴露出去的类型`U`的注释，应该为这种格式`// U xxx`。即以变量名开头

## 9. 使用errors.Is方法替代

> 使用errors.Is方法替换错误信息校验

###　9.1 错误写法

```go
if fieldErr, ok := err.(validator.ValidationErrors); ok {
    var tagErrorMsg []string
    for key, value := range fieldErr.Translate(validate.Trans) {
        tagErrorMsg = append(tagErrorMsg, fmt.Sprintf("%s: %s", key, value))
    }
    
    respErr := errors.New(strings.Join(tagErrorMsg, ","))
    return respErr
}
```

### 9.2 正确写法

```go
var fieldErr validator.ValidationErrors
if errors.Is(err, fieldErr) {
    var tagErrorMsg []string
    for key, value := range fieldErr.Translate(validate.Trans) {
        tagErrorMsg = append(tagErrorMsg, fmt.Sprintf("%s: %s", key, value))
    }
    
    respErr := errors.New(strings.Join(tagErrorMsg, ","))
    return respErr
}
```



# Reference

- [golint错误检查以及 min-confidence 不同等级的错误提示](https://blog.csdn.net/xiaocai_233/article/details/109527521)