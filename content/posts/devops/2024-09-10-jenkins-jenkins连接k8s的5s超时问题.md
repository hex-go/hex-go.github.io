---
title: Jenkins连接k8s的5s超时问题
categories:
  - Devops
tags:
  - Devops
  - Jenkins
date: '2024-09-10 09:16:33'
top: false
comments: true
---

## 问题

- k8s客户端请求排队等待

- 构建执行失败时出现网络套接字异常，例如

```bash
  Interrupted while waiting for websocket connection, you should increase the Max connections to Kubernetes API
```

```bash
Timed out waiting for websocket connection. You should increase the value of system property    
    org.csanchez.jenkins.plugins.kubernetes.pipeline.ContainerExecDecorator.websocketConnectionTimeout currently set at <currentTimeout> seconds
```

```bash
  io.fabric8.kubernetes.client.KubernetesClientException: not ready after <currentTimeout> MILLISECONDS
```

- 控制器线程转储显示了许多 OkHttp ConnectionPool 和/或 OkHttp WebSocket 线程


## 相关组件

[Jenkins LTS 变更记录](https://www.jenkins.io/changelog-stable/)

[Jenkins的Kubernetes插件](https://plugins.jenkins.io/kubernetes)

[Jenkins的DurableTask插件](https://plugins.jenkins.io/durable-task/)

[fabric8io/kubernetes-client](https://github.com/fabric8io/kubernetes-client)


## 相关Issue

- [JENKINS-58463](https://issues.jenkins.io/browse/JENKINS-58463)

- [JENKINS-58290](https://issues.jenkins.io/browse/JENKINS-58290)

- [JENKINS-67664](https://issues.jenkins.io/browse/JENKINS-67664)

## 说明

Kubernetes-plugin 管理  `Kubernetes APIServer` 通信的`Kubernetes client`实例。 一般来说，每个`Kubernetes集群`都有一个可用的`Kubernetes Client`实例。 

每个`kubernetes Client`都可以并发处理请求，为了防止 Jenkins 使`Kubernetes APIServer`超载，Kubernetes Client / Cloud 与 Kubernetes API 服务器的并发连接数有一个可配置的限制。 在 Kubernetes 云高级配置中，它被标为 Kubernetes API 的最大连接数，默认值为 32。 

`Kubernetes-plugin`需要向`Kubernetes APIServer`发送请求，以进行不同的操作，主要是管理`agent pod`，也包括`jnlp容器`内执行的`steps`。

实际上，每次在`非jnlp容器`中执行持久任务步骤或使用启动器的步骤时，都会调用 Kubernetes API。`Kubernetes-plugin`通过`WebSocket`连接的 `/exec API` 来执行这些步骤。对于持久任务步骤（如 `sh`、`bat`、`powershell` 步骤），连接只在步骤启动时打开，然后迅速关闭（即使步骤运行了几个小时）。 但是，在jnlp其他使用启动器的步骤，如某些发布者和使用某些 SCM（但不包括 Git 或 Subversion）的checkout，会在步骤持续期间保持打开 WebSocket 连接。

当达到`Kubernetes API`的最大连接数(默认，32)限制时，请求仍会提交给调度程序，但会被挂起，直到有调度程序线程可以处理。根据操作的不同，会有一个超时时间，等待连接最终被处理，然后才会失败。例如，`org.csanchez.jenkins.plugins.kubernetes.pipeline.websocketConnectionTimeout` 就是等待 WebSocket 连接成功以便在容器块内启动持久任务时应用的超时。 

当管道因该超时而失败时，可能意味着当前有太多并发请求，而该特定请求在超时期间一直处于客户端调度队列中。

自`Kubernetes-plugin`的 1.31.0 版本起，WebSocket 连接在更深的层次上以异步方式处理，相同错误的报告方式也不同。 错误信息一般为`io.fabric8.kubernetes.client.KubernetesClientException：not ready after <currentTimeout> MILLISECONDS`，而不是`you should increase the Max connections to Kubernetes API`，两种报错反应的是同一个问题。`kubernetes.websocket.timeout` 是在等待可用线程完成队列异步 websocket 连接时应用于更深层次的超时。 

最后，Jenkins的`container`步骤的当前实现很脆弱。 它依赖`Kubernetes /exec API `来发布命令，并在发布命令时使用`stdin  stderr stdout`流。 根据环境的不同，许多因素都会对功能产生影响。 

`Kubernetes-plugin`与`kube-apiserver`之间通过`/exec api`进行的通信，依赖于 kubernetes 节点（kubelet）的**响应速度**和**健康状况**，也依赖于维护连接的其他 kubernetes 特定行为。 Kubernetes 中可能会出现零星的连接问题，这些问题造成报错`java.net.ProtocolException: Expected HTTP 101 response but was '500 Internal Server Error'`。 `Pod eviction`、`kubelet 重启`、`容器运行时`无响应等问题都可能导致这种情况。

总结

- Jenkins中每一个k8s-cloud都对应一个k8s-client;
- 每个k8s-cloud都有最大连接数限制（默认，32），决定了k8s-client向kube-apiserver发出并发请求的最大连接；
- agent pod的声明周期、在`container{}`中执行流水线步骤，是需要连接 Kubernetes API 服务器的最常见操作;
- `container{}`中执行的构建脚本（`sh '' 或 bat '' 或 powershell ''`）都会打开一个`WebSocket`连接，以启动步骤并快速关闭(不会等待脚本结束);
- 其他使用launcher的步骤会在整个步骤期间保持连接。
- Kubernetes 插件超时（如 org.csanchez.jenkins.plugins.kubernetes.pipeline.websocketConnectionTimeout）可能会在达到限制时间过长时发生故障
- `container{}`中的步骤是使用`Kubernetes /exec API`启动的。 这种设计很脆弱，可能会受到偶现的服务器连接问题的影响。


因此，根据`controller`上的负载、`kube-apiserver`和`kubelet`的响应速度、流水线设计方式、steps的执行时间等因素，可能会很容易达到这个限制。临时的解决方案是提高上限，但代价是`kube-apiserver`、`kube-controller`、`kubelet`超载。


## KubernetesPlugin的持续优化

为了改进 Kubernetes API 调用的消费行为，可以采取以下措施：

- `KubernetesPlugin` 1.16.6 / `Durable Task`1.30：改进任务行为，使任务步骤执行不会在整个步骤执行过程中保持连接。 详情参考[JENKINS-58290](https://issues.jenkins.io/browse/JENKINS-58290)。
- `KubernetesPlugin` 1.27.1：移除对`kube-apiserver`的冗余调用，在每次容器中执行Launcher时,该冗余调用会检查所有容器是否都已就绪。 详见 [#826](https://github.com/jenkinsci/kubernetes-plugin/pull/826)。
- `KubernetesPlugin` 1.27.3：修复 Kubernetes API 的最大连接数限制为 64 的问题。详见[JENKINS-58463](https://issues.jenkins.io/browse/JENKINS-58463)
- `KubernetesPlugin` 1.28.1：有时会使用已过期（关闭）的客户端。 详见[#889](https://github.com/jenkinsci/kubernetes-plugin/pull/889)
- `KubernetesPlugin` 1.31.0：Kubernetes Client 升级至 5.10.1，连接问题现在会被`kubernetes plguin`报告为通用的`KubernetesClientException: not ready after <currentTimeout> MILLISECONDS`。
- `KubernetesPlugin` 3690.va_9ddf6635481：在`container{}`中启动步骤时引入重试机制，以缓解通过`Exec API`打开连接时出现的异常。详细见[JENKINS-67664](https://issues.jenkins.io/browse/JENKINS-67664)和[#1212](https://github.com/jenkinsci/kubernetes-plugin/pull/1212)。


## 解决方案

1. 安装**3690.va_9ddf6635481**或更高版本的`KubernetesPlugin`；
2. 增加 Kubernetes API 的最大连接数
3. 增加 `ContainerExecDecorator#websocketConnectionTimeout`
4. 增加 `Increase the kubernetes.websocket.timeout`(KubernetesPlugin 1.31.0 或更高版本)
5. 使用单一容器
6. 合并连续、小的构建步骤
7. AgentPod设置合理的资源限制

### 1. 增加最大连接数

最直接有效的方案

考虑增加与Kubernetes API的最大连接数，以便同时发出更多并发请求。

> 此方案虽然看起来简单粗暴，但这会增加`Kubernetes apiserver 和 controller`的负载，更多并发请求意味着需要更多资源。
> 采取此方案，需要逐渐增加此数值，根据kube-apiserver和controller的资源使用情况，找到一个合适的值。

### 2. 增大容器EXEC中的WebSocket超时时间


### 3. 增大连接k8s的WebSocket超时时间


### 4. 使用单一容器

在 jnlp 容器中运行步骤有助于大大减少调用 API 服务器的次数。 从而避免偶现的连接问题。 

因为这些执行使用的是远程通道，并不依赖 kubernetes API 来启动任务。 

使用单容器方法：构建一个 jnlp 镜像，其中包含能够在 jnlp 容器中运行脚本所需的所有构建工具，可参考[cloudbees-core-agent](https://hub.docker.com/r/cloudbees/cloudbees-core-agent)

> 虽然单一容器可以避免本文讨论的问题，但也带来了构建环境无法隔离，构建镜像维护困难的问题，并非最佳实践。


### 5.合并连续、小的构建步骤

建议将小的、连续的步骤合并成较大的步骤，来避免不必要的kube-api调用，提高稳定性和可扩展性。

例如，以下每个 sh 都需要连续调用几次 API：
```bash
  container('build') {
      sh "echo 'this'"
      sh "echo 'that'"
      sh "grep 'this' that | jq ."
  }
```
修改成以下内容，只需要调用一次`kube-api`
```bash
  container('notjnlp') {
      sh """
        echo 'this'
        echo 'that'
        grep 'this' that | jq .
      """
  }
```

### 6. AgentPod设置合理的资源限制

必须对运行在k8s集群中的`agent Pod`设置合理的资源限制（request、limit），以避免k8s集群的节点超载。 

如果k8s集群的节点压力过大或超载，会影响 Jenkins 控制器与 agent pod 之间的通信，增加服务器出错的可能性。

## 检查

为了更好地了解当前排队和正在运行的请求，可在`Manage Jenkins > Script Console`执行以下 groovy 脚本：

> Kubernetes Plugin 1.31.1 +
```groovy
def allRunningCount = 0
def allQueuedCount = 0

/**
 * Method that dumps information of a specific k8s client.
 */
def dumpClientConsumer = { k8sPluginClient ->
  def k8sClient = k8sPluginClient.client
  def okHttpClient = k8sClient.httpClient
  def httpClient = okHttpClient.httpClient
  def dispatcher = httpClient.dispatcher()

  allRunningCount += dispatcher.runningCallsCount()
  allQueuedCount += dispatcher.queuedCallsCount()

  println "(${k8sClient})"
  println "* STATE "
  println "  * validity " + k8sPluginClient.validity
  def runningCalls = dispatcher.runningCalls()
  println "* RUNNING " + runningCalls.size()
  runningCalls.each { call ->
    println "  * " + call.request()
  }
  def queuedCalls = dispatcher.queuedCalls()
  println "* QUEUED " + queuedCalls.size()
  queuedCalls.each { call ->
    println "  * " + call.request()
  }
  println "* SETTINGS "
  println "  * Connect Timeout (ms): " + httpClient.connectTimeoutMillis()
  println "  * Read Timeout (ms): " + httpClient.readTimeoutMillis()
  println "  * Write Timeout (ms): " + httpClient.writeTimeoutMillis()
  println "  * Ping Interval (ms): " + httpClient.pingIntervalMillis()
  println "  * Retry on failure " + httpClient.retryOnConnectionFailure()
  println "  * Max Concurrent Requests: " + dispatcher.getMaxRequests()
  println "  * Max Concurrent Requests per Host: " + dispatcher.getMaxRequestsPerHost()
  def connectionPool = httpClient.connectionPool()
  println "* CONNECTION POOL "
  println "  * Active Connection " + connectionPool.connectionCount()
  println "  * Idle Connection " + connectionPool.idleConnectionCount()
  println ""
}

println "Active K8s Clients\n----------"
org.csanchez.jenkins.plugins.kubernetes.KubernetesClientProvider.clients.asMap().values().forEach(dumpClientConsumer)

println ""
println "K8s Clients Summary\n----------"
println "* ${org.csanchez.jenkins.plugins.kubernetes.KubernetesClientProvider.clients.asMap().size()} active clients"
println "* ${allRunningCount} running calls"
println "* ${allQueuedCount} queued calls"

return
```


## Reference

https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-controllers/considerations-for-kubernetes-clients-connection-when-using-kubernetes-plugin
