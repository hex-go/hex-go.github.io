---
title: 解析 K8s YAML 为 client-go 中的 data structs
categories:
  - Kubernetes
tags:
  - Go
  - Kubernetes
date: 2020-05-05 00:00:00
top: false
comments: true
---

# 重要

client-go 的 `scheme.Codecs.UniversalDeserializer().Decode` 可以将 YAML 字符串解码为 `runtime.Object`。结合 `---` 分割多文档 YAML，就能一次性解析 `helm get manifest` 的输出。

# 环境说明

- Helm 3
- Kubernetes v1.15.6

## 1. 核心函数

YAML → `runtime.Object` 的关键行：

```go
decode := scheme.Codecs.UniversalDeserializer().Decode
obj, groupVersionKind, err := decode([]byte(yamlContent), nil, nil)
```

`Decode` 内置了 K8s 资源到 Go 结构体的映射表，返回的 `obj` 可以直接断言为具体类型。

## 2. 完整示例

从 `helm get manifest` 输出中批量解析 K8s 资源：

```go
import (
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/client-go/kubernetes/scheme"
    "regexp"
    "strings"
)

func ParseK8sYaml(yamlContent []byte) []runtime.Object {
    acceptedTypes := regexp.MustCompile(
        `(Deployment|StatefulSet|Service|Ingress|Role|ClusterRole|
          RoleBinding|ClusterRoleBinding|ServiceAccount|HorizontalPodAutoscaler)`,
    )

    sepYamlfiles := strings.Split(string(yamlContent), "---")
    retVal := make([]runtime.Object, 0, len(sepYamlfiles))

    for _, f := range sepYamlfiles {
        if f == "\n" || f == "" {
            continue
        }

        decode := scheme.Codecs.UniversalDeserializer().Decode
        obj, groupVersionKind, err := decode([]byte(f), nil, nil)
        if err != nil {
            continue
        }

        if acceptedTypes.MatchString(groupVersionKind.Kind) {
            retVal = append(retVal, obj)
        }
    }
    return retVal
}
```

调用端——从 Helm Release 获取所有资源：

```go
func GetResources(helmRelease, namespace, kubeconfig string) ([]runtime.Object, error) {
    args := []string{
        "--kubeconfig", kubeconfig,
        "get", "manifest", helmRelease,
        "-n", namespace,
    }
    stdout, err := execCmd("helm", args)
    if err != nil {
        return nil, err
    }
    return ParseK8sYaml(stdout), nil
}
```

## 3. 注意

| 注意点 | 说明 |
|--------|------|
| `---` 分割 | Helm manifest 是多文档 YAML，`---` 分隔 |
| 版本差异 | K8s 版本不同，资源的 API Group 可能变化 |
| 白名单过滤 | 仅解析支持的资源类型，忽略 ConfigMap 等 |
| 注释行干扰 | `#` 开头的内容可能导致解码失败，需过滤 |

## 参考

- [Support for parsing K8s yaml spec into client-go data structures](https://github.com/kubernetes/client-go/issues/193#issuecomment-343138889)
