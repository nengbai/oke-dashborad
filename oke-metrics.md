# Kubernetes核心指标监控——Metrics Server

## 1、概述

Kubernetes v1.8开始，使用Metrics API的形式获取，对资源监控。例如Pods CPU和内存使用率,通过使用kubectl top命令），或者由集群中的控制器（例如，Horizontal Pod Autoscaler）使用来进行决策，具体的组件为Metrics Server，用来替换之前的heapster，heapster从
v1.11开始逐渐被废弃。OKE 完全兼容Metrics Server，可以使用这个组件监控。

Metrics-Server是集群核心监控数据的聚合器。通俗地说，它存储了集群中各节点的监控数据，并且提供了API以供分析和使用。Metrics-Server作为一个 Deployment对象默认部署在Kubernetes集群中。不过准确地说，它是Deployment，Service，ClusterRole，ClusterRoleBinding，APIService，RoleBinding等资源对象的综合体。

项目地址：<https://github.com/kubernetes-sigs/metrics-server> ,目前稳定版本是v0.5.2。

metric-server主要用来通过aggregate api向其它组件（kube-scheduler、HorizontalPodAutoscaler、Kubernetes集群客户端等）提供集群中的pod和node的cpu和memory的监控指标，弹性伸缩中的podautoscaler就是通过调用这个接口来查看pod的当前资源使用量来进行pod的扩缩容的。
需要注意的是：
    metric-server提供的是实时的指标（实际是最近一次采集的数据，保存在内存中），并没有数据库来存储
    这些数据指标并非由metric-server本身采集，而是由每个节点上的cadvisor采集，metric-server只是发请求给cadvisor并将metric格式的数据转换成aggregate api
    由于需要通过aggregate api来提供接口，需要集群中的kube-apiserver开启该功能（开启方法可以参考官方社区的文档）

## 2、OKE Metrics Serve部署

### 2.1 下载并部署Metrics Server

下载部署清单：

wget <https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.5.2/components.yaml>

修改部署清单内容：

[root@master1 metrics-server]# cat components.yaml

```text
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
    rbac.authorization.k8s.io/aggregate-to-view: "true"
  name: system:aggregated-metrics-reader
rules:
- apiGroups:
  - metrics.k8s.io
  resources:
  - pods
  - nodes
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - nodes
  - nodes/stats
  - namespaces
  - configmaps
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server-auth-reader
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: extension-apiserver-authentication-reader
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server:system:auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:metrics-server
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  ports:
  - name: https
    port: 443
    protocol: TCP
    targetPort: https
  selector:
    k8s-app: metrics-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --kubelet-insecure-tls
        image: k8s.gcr.io/metrics-server/metrics-server:v0.5.2
        imagePullPolicy: IfNotPresent
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /livez
            port: https
            scheme: HTTPS
          periodSeconds: 10
        name: metrics-server
        ports:
        - containerPort: 4443
          name: https
          protocol: TCP
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /readyz
            port: https
            scheme: HTTPS
          periodSeconds: 10
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
        volumeMounts:
        - mountPath: /tmp
          name: tmp-dir
      nodeSelector:
        kubernetes.io/os: linux
      priorityClassName: system-cluster-critical
      serviceAccountName: metrics-server
      volumes:
      - emptyDir: {}
        name: tmp-dir
---
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  labels:
    k8s-app: metrics-server
  name: v1beta1.metrics.k8s.io
spec:
  group: metrics.k8s.io
  groupPriorityMinimum: 100
  insecureSkipTLSVerify: true
  service:
    name: metrics-server
    namespace: kube-system
  version: v1beta1
  versionPriority: 100
```

在deploy中，spec.template.containers.args字段中加上--kubelet-insecure-tls选项，表示不验证客户端证书；上述清单主要用deploy控制器将metrics server运行为一个pod，然后授权metrics-server用户能够对pod/node资源进行只读权限；然后把metrics.k8s.io/v1beta1注册到原生apiserver上，让其客户端访问metrics.k8s.io下的资源能够被路由至metrics-server这个服务上进行响应；

应用资源清单：

[root@master1 metrics-server]# kubectl apply -f components.yaml
serviceaccount/metrics-server created
clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
clusterrole.rbac.authorization.k8s.io/system:metrics-server created
rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader created
clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator created
clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server created
service/metrics-server created
deployment.apps/metrics-server created
apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io created

### 2.2 验证Metrics Server组件部署成功

（1）查看原生apiserver是否有metrics.k8s.io/v1beta1

[root@master1 metrics-server]# kubectl api-versions|grep metrics
metrics.k8s.io/v1beta1

可以看到metrics.k8s.io/v1beta1群组已经注册到原生apiserver上。

（2）查看metrics server pod是否运行正常

[root@master1 ~]# kubectl get pods -n=kube-system |grep metrics
metrics-server-855cc6b9d-g6xsf    1/1     Running   0          18h

可以看到对应pod已经正常运行，接着查看pod日志，只要metrics server pod没有出现错误日志，或者无法注册等信息，就表示pod里的容器运行正常。

（3）使用kubectl top 命令查看pod的cpu ，内存占比，看看对应命令是否可以正常执行，如果Metrics Server服务有异常的话会报Error from server (ServiceUnavailable): the server is currently unable to handle the request (get nodes.metrics.k8s.io)错误。

[root@master1 ~]# kubectl top nodes
NAME      CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
master1   272m         3%     4272Mi          29%
node1     384m         5%     9265Mi          30%
node2     421m         5%     14476Mi         48%

可以看到kubectl top命令可以正常执行，说明metrics server 部署成功没有问题。

## 3、原理

Metrics server定时从Kubelet的Summary API(类似/ap1/v1/nodes/nodename/stats/summary)采集指标信息，这些聚合过的数据将存储在内存中，且以metric-api的形式暴露出去。

Metrics server复用了api-server的库来实现自己的功能，比如鉴权、版本等，为了实现将数据存放在内存中吗，去掉了默认的etcd存储，引入了内存存储（即实现Storage interface)。

因为存放在内存中，因此监控数据是没有持久化的，可以通过第三方存储来拓展。

来看下Metrics-Server的架构：

metrics-server架构

从 Kubelet、cAdvisor 等获取度量数据，再由metrics-server提供给 Dashboard、HPA 控制器等使用。本质上metrics-server相当于做了一次数据的转换，把cadvisor格式的数据转换成了kubernetes的api的json格式。由此我们不难猜测，metrics-server的代码中必然存在这种先从metric中获取接口中的所有信息，再解析出其中的数据的过程。我们给metric-server发送请求时，metrics-server中已经定期从中cadvisor获取好数据了，当请求发过来时直接返回缓存中的数据。

## 4、如何获取监控数据

Metrics-Server通过kubelet获取监控数据。

在1.7版本之前，k8s在每个节点都安装了一个叫做cAdvisor的程序，负责获取节点和容器的CPU，内存等数据；而在1.7版本及之后，k8s将cAdvisor精简化内置于kubelet中，因此可直接从kubelet中获取数据。

## 5、如何提供监控数据

Metrics-Server通过metrics API提供监控数据。

先说下API聚合机制，API聚合机制是kubernetes 1.7版本引入的特性，能将用户扩展的API注册至API Server上。

API Server在此之前只提供kubernetes资源对象的API，包括资源对象的增删查改功能。有了API聚合机制之后，用户可以发布自己的API，而Metrics-Server用到的metrics API和custom metrics API均属于API聚合机制的应用。

用户可通过配置APIService资源对象以使用API聚合机制(API聚合机制详解请参考：Kubernetes APIService资源)，如下是metrics API的配置文件：

apiVersion: apiregistration.k8s.io/v1beta1
kind: APIService
metadata:
  name: v1beta1.metrics.k8s.io
spec:
  service:
    name: metrics-server
    namespace: kube-system
  group: metrics.k8s.io
  version: v1beta1
  insecureSkipTLSVerify: true
  groupPriorityMinimum: 100
  versionPriority: 100

如上，APIService提供了一个名为v1beta1.metrics.k8s.io的API，并绑定至一个名为metrics-server的Service资源对象。

可以通过kubectl get apiservices命令查询集群中的APIService。

因此，访问Metrics-Server的方式如下：

``` text
    /apis/metrics.k8s.io/v1beta1  --->   metrics-server.kube-system.svc  --->   x.x.x.x
```

``` text

+---------+       +-----------+                   +------------------------+        +-----------------------------+
| 发起请求 +----->+ API Server +----------------->+ Service：metrics-server +-------->+ Pod：metrics-server-xxx-xxx |
+---------+       +-----------+                   +------------------------+        +-----------------------------+
```

通过访问Metrics-Server的方式，HPA，kubectl top等对象就可以正常工作了。

## 6、总结

OKE的监控体系:metrics-server属于Core metrics(核心指标)，提供API metrics.k8s.io，仅提供Node和Pod的CPU和内存使用情况。而其他Custom Metrics(自定义指标)由Prometheus等组件来完成。
