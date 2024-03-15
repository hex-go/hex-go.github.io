---
title: Kubernetes-CertManager解决ingress-tls证书问题
categories:
  - Kubernetes
tags:
  - Kubernetes
  - CertManager
date: '2020-11-05 03:55:15'
top: false
comments: true
series:
  - PKI相关
---

# 重要
由于需要配置`ingress-grpc`,nginx-ingress要求tls加密。实现的方式有两种：一种在ingress注解`grpcs`,之后在pod控制证书；另一种在ingress配置`tls`。
生产环境证书都是运维统一维护，舍弃第一种。所以调研cert-manager用来维护证书。

此处`cert-manager`用来使用已给的`ca`为需要证书的服务生成证书、并使用.

# 环境说明
K8S：1.15.6
CertManager: 1.0.4

# 部署cert-manager
两种方式： 
一种资源清单部署（[install with regular manifests](https://cert-manager.io/docs/installation/kubernetes/#installing-with-regular-manifests)）
另一种是helm-chart部署（[install with helm](https://cert-manager.io/docs/installation/kubernetes/#installing-with-helm)）

注意, 默认配置在`certificate`删除时,它所创建的`secret`不会被删除; 如果想要`Secret`同步被删除,需要在部署时指定参数`--enable-certificate-owner-ref=true`.

## 1. 资源清单部署
> 由于工作环境使用的k8s环境版本为1.15.6，<1.16.
```bash
# Kubernetes <1.16
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.4/cert-manager-legacy.yaml
```

## 2. helm-chart部署
1. 创建CRD资源
> 由于工作环境使用的k8s环境版本为1.15.6，创建crd时使用最新版本.
```bash
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.4/cert-manager.crds.yaml
```

2. 获取chart部署
```bash
# 添加 chart-repo
helm repo add jetstack https://charts.jetstack.io
# 拉取 v1.0.4 版本chart
# 建议拉取chart,而不是在线安装
helm pull jetstack/cert-manager --version=v1.0.4

# helm install 
helm install --name cert-manager --namespace cert-manager cert-manager-v1.0.4.tgz
```

# 检查安装
```bash
$ kubectl get pods --namespace cert-manager

NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-5c6866597-zw7kh               1/1     Running   0          2m
cert-manager-cainjector-577f6d9fd7-tr77l   1/1     Running   0          2m
cert-manager-webhook-787858fcdb-nlzsq      1/1     Running   0          2m
```


# 使用
cert-manager 可以从各种证书颁发机构获取证书，包括Let's Encrypt、HashiCorp Vault、Venafi 和 私人PKI。

由于服务不需要暴露公网，此处选用自签发`CA`(即私人PKI)方式签发证书：

## 1. 创建ca并保存进集群，Secret:cert-manager:ca-key-pair
> 此处配置的是自签发证书，如果环境中需要更换成合法证书，需要运维在第二步时，根据真实证书创建Secret。 

+ 生成自签发证书(ca.crt)和key(ca.key)
```bash
# Generate a CA private key
openssl genrsa -out ca.key 2048
    
# Create a self signed Certificate, valid for 10yrs with the 'signing' option set
openssl req -x509 -new -nodes -key ca.key -subj "/CN=ICOS.CITY" -days 3650 -reqexts v3_req -extensions v3_ca -out ca.crt
```

+ 创建`Secret`保存证书(命名空间: cert-manager; 资源类型: secret; 资源名称: ca-key-pair.)。
> 如果使用cluster-issuer，则需要将此secret保存至`cert-manager`命名空间；
> 如果使用issuer,则需要在每个issuer所在命名空间创建此secret.

此处以 `cluster-issuer` 配置
```bash
kubectl create secret tls ca-key-pair --cert=ca.crt --key=ca.key --namespace=cert-manager
```

## 2. 创建 `cluster-issuer`, 内容如下(cluster-issuer.yaml)：
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-clusterissuer
spec:
  ca:
    secretName: ca-key-pair
```
执行下面命令创建
```bash
kubectl create -f cluster-issuer.yaml
```

## 3. 创建`certificate`测试，内容如下(example-ca.yaml)：
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-ca
  namespace: mars
spec:
  # 创建名为`example-secret`的secret,保存`ca`与签发的证书.
  secretName: example-secret
  issuerRef:
    name: ca-clusterissuer
    kind: ClusterIssuer
  # 此处放的是服务集群内部访问地址，
  commonName: example.mars
  organization:
  - Example CA
  dnsNames:
  # 同namespace访问的服务地址
  - example
  # 集群外部访问地址
  - example.mars.icos.city
```
执行命令`kubectl create -f example-ca.yaml`
查看证书和Secret

```bash
$ kubectl -n mars get certificate
# 证书的状态 READY 为 True。
NAME           READY   SECRET             AGE
example-ca     True    example-secret     5d20h

$ kubectl -n mars get secrets example-secret -o yaml
# 回显的secret的 data.ca.crt, data.tls.crt, data.tls.key 都有证书或秘钥base64值。
apiVersion: v1
data:
  ca.crt: LS0tLS1C...EUtLS0tLQo=
  tls.crt: LS0tLS1C...RFLS0tLS0K
  tls.key: LS0tLS1C...0tLS0tCg==
kind: Secret
metadata:
  annotations:
    cert-manager.io/alt-names: test-cert.mars,test-cert.icos.city
    cert-manager.io/certificate-name: test-cert-ca
    cert-manager.io/common-name: icos.city
    cert-manager.io/issuer-kind: ClusterIssuer
    cert-manager.io/issuer-name: ca-clusterissuer
  # 在certificate中指定的 `spec.secretName`
  name: example-secret
  namespace: mars
type: kubernetes.io/tls
``` 
## 4. 容器使用
集群中使用证书的场景有以下几个诉求：
1. 非https容器访问https容器，需要信任此自签证书。所以需要将`ca.crt`挂载到非https容器内部；
2. 储存各个服务自身证书的secret中包含三部分，`ca.crt`,`tls.crt`,`tls.key`。
3. 统一的平台部署应用到多个k8s集群，需要每个集群均部署`cert-manager`,并使用同一个`ca`。

所以采取以下实现。
1. 为每个服务均生成证书，至少包含`同一集群内部访问`和`同一Namespace访问`的证书。并挂载在`/opt/tls/`目录下。
2. 如果服务有对外暴露，多加一个dnsName 为`集群外部访问地址`。
3. 每个服务在固定的容器目录下，均有`ca.crt`,`tls.crt`,`tls.key`文件，只是访问https服务，则只使用`ca.crt`文件。
4. `ca.crt`是公用、一致的； `tls.crt`,`tls.key`是根据每个服务的服务名、ingress签发的。

```yaml
# Source: icossense-icosgrpc-service-xadit-001/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-001
  labels:
    app: example-001
    chart: example-001-1.0.0
    release: "RELEASE-NAME"
    heritage: "Helm"
spec:
  selector:
    matchLabels:
      app: example-001
  replicas: 1
  template:
    metadata:
      name: example-001
      labels:
        app: example-001
        release: "RELEASE-NAME"
    spec:
      containers:
      - name: example-001
        image: "hexpy/example-grpc:latest9"
        imagePullPolicy: "Always"
        securityContext:
          allowPrivilegeEscalation: true
          runAsNonRoot: true
          capabilities:
            drop: ["NET_ADMIN", "SYS_TIME","CHOWN","SYS_ADMIN"]
        ports:
        - name: containerport-0
          protocol: "TCP"
          containerPort: 7070
        volumeMounts:
        - name: example-secret-mount
          mountPath: "/etc/tls"
          readOnly: true
      volumes:
      # 在此`deployment`中, `volumeMounts`中的`name`一致
      - name: example-secret-mount
        secret:
          # 在`certificate`中`spec.secretName`设置的.
          secretName: example-secret
```

# Reference
[官方文档](https://cert-manager.io/docs/)
[chart](https://artifacthub.io/packages/helm/jetstack/cert-manager/1.0.4)
[github](https://github.com/jetstack/cert-manager)
[当证书被删除，Secret会被留下](https://github.com/jetstack/cert-manager/issues/2993)
[当证书被删除，Secret会被留下2](https://github.com/jetstack/cert-manager/issues/296)

[github-示例项目](https://github.com/hex-go/cert-manager-example.git)
[Automatic TLS certificates with cert-manager and ingress-nginx](https://atelierhsn.com/2020/07/cert-manager-ingress/)
