---
title: k8S-使用client-go操作集群
categories:
  - Kubernetes
tags:
  - Kubernetes
  - Client-go
  - Go

date: '2020-05-28 11:16:44'
top: false
comments: true
---

# 重要

# 环境说明

# 安装

# 使用

### 0. 校验kubeconfig可用性

```go
import (
	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

## 解析kubeConfig文件， 校验
func (k *K8S) ParseConf(kubeConfig []byte) (Conf clientcmdapi.Config, err error) {
	var (
		restConf clientcmd.ClientConfig
	)
	if restConf, err = clientcmd.NewClientConfigFromBytes(kubeConfig); err != nil {
		log.Error(fmt.Sprintf("Could not load kube Config : %s", err.Error()))
		return
	}
	Conf, _ = restConf.RawConfig()
	return
}
```



## 1. 初始化客户端clientSet

### 1.1 集群内初始化ClientSet

[官方Example](https://github.com/kubernetes/client-go/blob/v0.19.0/examples/in-cluster-client-configuration/main.go)


### 1.2 集群外初始化ClientSet

[官方Example](https://github.com/kubernetes/client-go/blob/v0.19.0/examples/out-of-cluster-client-configuration/main.go)

### 1.3 从字节流创建ClientSet

```go
package k8s

import (
	"k8s.io/client-go/rest"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

type K8S struct {
	clientSet *kubernetes.Clientset
}

// Connect - 初始化k8s客户端
func (k *K8S) Connect(kubeConfig []byte) (err error) {
	var (
		restConf *rest.Config
	)

	if restConf, err = clientcmd.RESTConfigFromKubeConfig(kubeConfig); err != nil {
		log.Error(fmt.Sprintf("Could not load kube Config : %s", err.Error()))
		return
	}
	// 生成client-set配置
	if k.clientSet, err = kubernetes.NewForConfig(restConf); err != nil {
		log.Error(fmt.Sprintf("Could not connect k8s : %s", err.Error()))
		return
	}

	log.Info("Successfully connected to k8s")
	return
}
```



### 1.4 创建Dynamic ClientSet

```go
package fleet

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

type Crd struct {
	Client dynamic.Interface
}

// Connect 初始化Fleet客户端
func (i *Crd) Connect(kubeConfig []byte) (err error) {
	var (
		restConf *rest.Config
	)
	if restConf, err = clientcmd.RESTConfigFromKubeConfig(kubeConfig); err != nil {
		log.Error(fmt.Sprintf("Could not load kube Config : %s", err.Error()))
		return
	}

	if i.Client, err = dynamic.NewForConfig(restConf); err != nil {
		log.Error(fmt.Sprintf("Could not connect FleetCrd-k8s : %s", err.Error()))
		return
	}

	log.Info("Successfully connected to FleetCrd")
	return
}
```






## 3. 根据Deployment|StatefulSet获取Pods

```go
import (
	"k8s.io/api/apps/v1"
	coreV1 "k8s.io/api/core/v1"
	metaV1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
)


func (k *K8S) PodGetByStatefulSet(namespace string, statefulSet v1.StatefulSet) ([]*coreV1.Pod, error) {
	var podList []*coreV1.Pod
	labelsMap := statefulSet.ObjectMeta.GetLabels()

	log.DebugF("[Middleware-K8s] StatefulSet:Labels: 	%#v", labelsMap)
	labelSets := labels.SelectorFromSet(labelsMap)
	options := metaV1.ListOptions{
		LabelSelector: labelSets.String(),
	}

	podsClient := k.clientSet.CoreV1().Pods(namespace)
	pods, err := podsClient.List(context.TODO(), options)
	if err != nil {
		return nil, err
	}
	for _, pod := range pods.Items {
		log.DebugF("[Middleware-K8s] Pod:Labels: 		%#v, pod_name=%s", pod.ObjectMeta.GetLabels(), pod.ObjectMeta.Name)
		podList = append(podList, &pod)

	}
	return podList, err

}
```



## 4. 根据Job获取Pods

```go
import (
	batchV1 "k8s.io/api/batch/v1"
	coreV1 "k8s.io/api/core/v1"
	metaV1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
)

func (k *K8S) PodGetByJob(namespace string, job batchV1.Job) ([]*coreV1.Pod, error) {
	var podList []*coreV1.Pod

	labelsMap := map[string]string{
		"job-name":       job.ObjectMeta.Name,
		"controller-uid": string(job.ObjectMeta.UID),
	}
	log.DebugF("[Middleware-K8s] Jobs:Labels: 	%#v", labelsMap)
	labelSets := labels.SelectorFromSet(labelsMap)
	options := metaV1.ListOptions{
		LabelSelector: labelSets.String(),
	}

	podsClient := k.clientSet.CoreV1().Pods(namespace)
	pods, err := podsClient.List(context.TODO(), options)
	if err != nil {
		return nil, err
	}
	for _, pod := range pods.Items {
		log.DebugF("[Middleware-K8s] Pod:Labels: 	%#v, pod_name=%s", 
			pod.ObjectMeta.GetLabels(), 
			pod.ObjectMeta.Name)
		podList = append(podList, &pod)
	}
	return podList, err

}
```



## 5. Dynamic-client-go操作CRD资源

以rancher fleet项目的CRD `clusters.fleet.cattle.io`举例

> 完整的包引用

```go
package fleet

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	fleet "github.com/rancher/fleet/pkg/apis/fleet.cattle.io/v1alpha1"
	"icosdeploy/pkg/api/log"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/runtime/serializer/yaml"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)
```

### 5.1 初始化ClientSet

```go
package fleet

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

type Crd struct {
	Client dynamic.Interface
}

// Connect 初始化Fleet客户端
func (i *Crd) Connect(kubeConfig []byte) (err error) {
	var (
		restConf *rest.Config
	)
	if restConf, err = clientcmd.RESTConfigFromKubeConfig(kubeConfig); err != nil {
		log.Error(fmt.Sprintf("Could not load kube Config : %s", err.Error()))
		return
	}

	if i.Client, err = dynamic.NewForConfig(restConf); err != nil {
		log.Error(fmt.Sprintf("Could not connect FleetCrd-k8s : %s", err.Error()))
		return
	}

	log.Info("Successfully connected to FleetCrd")
	return
}
```



### 5.2 Cluster CRD的查询、删除操作

资源定义

```go
var clusterCRD = schema.GroupVersionResource{
	Group:    "fleet.cattle.io",
	Version:  "v1alpha1",
	Resource: "clusters",
}
```

上面的值在CRD``中获取

```yaml
spec:
  # group name to use for REST API: /apis/<group>/<version>
  # 对应 Group 字段的值
  group: fleet.cattle.io
  # list of versions supported by this CustomResourceDefinition
  versions:
    # 对应 Version 字段的可选值
    - name: v1alpha1
  # ...
names:
  # plural name to be used in the URL: /apis/<group>/<version>/<plural>
  # 对应 Resource 字段的值
  plural: clusters
```

#### 5.2.1 List查询资源

> 如果资源对象不是Namespace隔离的，则不指定Namespace:  `i.Client.Resource(xxxCRD).List(context.TODO(), metav1.ListOptions{})`

```go
func (i *Crd) ListClusters(namespace string) (clusters *fleet.ClusterList, err error) {
	list, err := i.Client.Resource(clusterCRD).Namespace(namespace).List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		return nil, err
	}
	data, err := list.MarshalJSON()
	if err != nil {
		return nil, err
	}

	if err := json.Unmarshal(data, &clusters); err != nil {
		return nil, err
	}
	return clusters, nil
}
```



#### 5.2.2 Get查询资源详情

```go
func (i *Crd) GetCluster(namespace string, name string) (cluster *fleet.Cluster, err error) {
	list, err := i.Client.Resource(clusterCRD).
		Namespace(namespace).Get(context.TODO(), name, metav1.GetOptions{})
	if err != nil {
		return nil, err
	}
	data, err := list.MarshalJSON()
	if err != nil {
		return nil, err
	}

	if err := json.Unmarshal(data, &cluster); err != nil {
		return nil, err
	}
	return cluster, nil
}
```



#### 5.2.3 删除资源

```go
func (i *Crd) DelCluster(namespace string, name string) (err error) {
	deletePolicy := metav1.DeletePropagationForeground

	cluster, err := i.GetCluster(namespace, name)
	if err != nil {
		log.Error(err.Error())
		return err
	}
	if cluster == nil {
		err = errors.New(fmt.Sprintf("Cluster -- %s not exists", name))
		log.Error(err.Error())
		return
	}

	err = i.Client.Resource(clusterCRD).
		Namespace(namespace).Delete(context.TODO(), name, metav1.DeleteOptions{PropagationPolicy: &deletePolicy})
	if err != nil {
		return
	}
	return
}
```



### 5.3 Token CRD的创建操作

资源定义

```go
var tokenCRD = schema.GroupVersionResource{
	Group:    "fleet.cattle.io",
	Version:  "v1alpha1",
	Resource: "clusterregistrationtokens",
}
```



#### 5.3.1 List查询资源

```go
func (i *Crd) ListToken(namespace string) (tokenList *fleet.ClusterRegistrationTokenList, err error) {
	list, err := i.Client.Resource(tokenCRD).Namespace(namespace).List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		return nil, err
	}
	data, err := list.MarshalJSON()
	if err != nil {
		return nil, err
	}

	if err = json.Unmarshal(data, &tokenList); err != nil {
		return nil, err
	}
	return tokenList, nil
}
```



#### 5.3.2 Get查询资源详情

```go

func (i *Crd) GetToken(namespace string, name string) (token *fleet.ClusterRegistrationToken, err error) {
	list, err := i.Client.Resource(tokenCRD).Namespace(namespace).Get(context.TODO(), name, metav1.GetOptions{})
	if err != nil {
		return nil, err
	}
	data, err := list.MarshalJSON()
	if err != nil {
		return nil, err
	}

	if err = json.Unmarshal(data, &token); err != nil {
		return nil, err
	}
	return token, nil
}
```



#### 5.3.3 创建资源
> 注意: `yaml`包一定要用 `"k8s.io/apimachinery/pkg/runtime/serializer/yaml"`， 否则想资源部分数据解析会报错
```go
var CreateData = `
kind: ClusterRegistrationToken
apiVersion: "fleet.cattle.io/v1alpha1"
metadata:
    name: new-token
    namespace: fleet-local
spec:
    ttl: 240h
`

func (i *Crd) CreateToken(namespace string) (token *fleet.ClusterRegistrationToken, err error) {
	decoder := yaml.NewDecodingSerializer(unstructured.UnstructuredJSONScheme)
	obj := &unstructured.Unstructured{}
	gvk := schema.GroupVersionKind{
		Group:   "fleet.cattle.io",
		Version: "v1alpha1",
		Kind:    "ClusterRegistrationToken",
	}
	if _, _, err := decoder.Decode([]byte(CreateData), &gvk, obj); err != nil {
		return nil, err
	}

	one, err := i.Client.Resource(tokenCRD).Namespace(namespace).Create(context.TODO(), obj, metav1.CreateOptions{})
	if err != nil {
		return nil, err
	}
	data, err := one.MarshalJSON()
	if err != nil {
		return nil, err
	}
	if err = json.Unmarshal(data, &token); err != nil {
		return nil, err
	}

	return token, nil
}
```



### 5.4 GitRepo CRD的操作

资源定义

```go
var gitRepoCRD = schema.GroupVersionResource{
	Group:    "fleet.cattle.io",
	Version:  "v1alpha1",
	Resource: "gitrepos",
}
```



#### 5.4.1 List查询资源

```go


func (i *Crd) ListGitRepo(namespace string) (repoList *fleet.GitRepoList, err error) {
	list, err := i.Client.Resource(gitRepoCRD).Namespace(namespace).List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		return nil, err
	}
	data, err := list.MarshalJSON()
	if err != nil {
		return nil, err
	}

	if err := json.Unmarshal(data, &repoList); err != nil {
		return nil, err
	}
	return repoList, nil
}

```



## 6. 查看容器日志

```go
// PodLogs - pod  logs
func (k *K8S) PodLogs(namespace string, name string) (string, error) {
	podLogOpts := coreV1.PodLogOptions{}

	jobsClient := k.clientSet.CoreV1().Pods(namespace)
	result := jobsClient.GetLogs(name, &podLogOpts)

	podLogs, err := result.Stream(context.TODO())
	if err != nil {
		log.ErrorF("error in opening stream:  %v", err)
		return "", err
	}
	defer podLogs.Close()
	buf := new(bytes.Buffer)
	_, err = io.Copy(buf, podLogs)
	if err != nil {
		log.ErrorF("error in copy information from podLogs to buf:  %v", err)
		return "", err
	}
	logs := buf.String()

	return logs, err
}

```





# Reference

**[第一参考 client-go简介](https://www.huweihuang.com/kubernetes-notes/develop/client-go.html)**

**[client-go官方实例--集群内client配置](https://github.com/kubernetes/client-go/blob/master/examples/in-cluster-client-configuration/main.go)**

[client-go针对crd资源，代码生成器](https://stackoverflow.com/questions/49953980/watch-customresourcedefinitions-crd-with-client-go)

**[Unit test kubernetes client in Go](https://gianarb.it/blog/unit-testing-kubernetes-client-in-go)**

[Dynamic-client-go操作CRD资源](https://mozillazg.com/2020/07/k8s-kubernetes-client-go-list-get-create-update-patch-delete-crd-resource-without-generate-client-code-update-or-create-via-yaml.html#hidcreate)

[基于Dynamic-client, 开发第三方资源Informer和Controller](https://mp.weixin.qq.com/s/eMDyXfPbeQmOOwTtLNsaOA)
