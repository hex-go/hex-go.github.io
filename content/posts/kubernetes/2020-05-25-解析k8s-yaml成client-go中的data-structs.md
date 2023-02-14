---
title: 解析k8s-yaml成client-go中的data-structs
categories:
  - Kubernetes
tags:
  - Kubernetes
  - Go
date: '2020-05-25 03:35:11'
top: false
comments: true
---

# 重要
开发过程中，需要解析helm-manifest获取到的各种资源的yaml。每个都写映射
# 环境说明

+ helm 3
+ kubernetes-v1.15.6

# 安装

无

# 使用

注意:

k8s版本不同。，资源所在的api接口会有变化。

```go
package k8s

import (
	"fmt"
	"heroku/pkg/api/log"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/kubernetes/scheme"
	"regexp"
	"strings"
)

func ParseK8sYaml(fileR []byte) []runtime.Object {

	acceptedK8sTypes := regexp.MustCompile(`(Role|ClusterRole|RoleBinding|ClusterRoleBinding|ServiceAccount|Deployment|StatefulSet|Service|Ingress|HorizontalPodAutoscaler)`)
	fileAsString := string(fileR[:])
	sepYamlfiles := strings.Split(fileAsString, "---")
	retVal := make([]runtime.Object, 0, len(sepYamlfiles))

	for _, f := range sepYamlfiles {
		if f == "\n" || f == "" {
			// ignore empty cases
			continue
		}

		checkList := strings.Split(f, "#")
		if len(checkList) > 10 {
			// ignore annotation resource
			log.Warn(fmt.Sprintf("ignore annotation resource: %s", f[:10]))

			continue
		}

		decode := scheme.Codecs.UniversalDeserializer().Decode
		obj, groupVersionKind, err := decode([]byte(f), nil, nil)

		if err != nil {
			log.Warn(fmt.Sprintf("Error while decoding YAML object. Err was: %s", err))
			continue
		}
		log.Debug(fmt.Sprintf("Helm-Manitest:--:%s", groupVersionKind))

		if !acceptedK8sTypes.MatchString(groupVersionKind.Kind) {
			log.Info(fmt.Sprintf("The custom-roles configMap contained K8s object types which are not supported! Skipping object with type: %s", groupVersionKind.Kind))
		} else {
			retVal = append(retVal, obj)
		}

	}
	return retVal
}

func stringToFile(outDir string, aut model.Aut) (configFile string, err error) {
	filename := filepath.Join(outDir, "config")

	var data = []byte(aut.K8sConf)
	err = ioutil.WriteFile(filename, data, 0666)
	if err != nil {
		return "", errors.New(fmt.Sprintf("k8s-config load to tmp Error : %s", err.Error()))
	}
	return filename, nil
}

func Show(helmRelease string, aut model.Aut) (instances []runtime.Object, err error) {
	tmp, err := ioutil.TempDir("", "curator-")
	if err != nil {
		return nil, errors.Wrapf(err, "Error while preparing temp Dir")
	}

	defer os.RemoveAll(tmp) // clean up

	configPath, err := stringToFile(tmp, aut)
	if err != nil {
		return nil, err
	}

	log.Info("Started Helm-show:")

	args := []string{
		"--kubeconfig", configPath,
		"get",
		"manifest",
		helmRelease,
		"-n", aut.Namespace,
	}

	stdout, err := utils.ExecCMD("helm", args)
	if err != nil {
		return nil, err
	}

	instances = k8s.ParseK8sYaml(stdout)
	return instances, err
}

```



# Reference

[Support for parsing K8s yaml spec into client-go data structures](https://github.com/kubernetes/client-go/issues/193#issuecomment-343138889)