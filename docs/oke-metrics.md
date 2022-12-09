# OKE Kubernetes核心指标监控——Metrics Server

## $1. Mestrics Server概述

Kubernetes v1.8开始，使用Metrics API的形式获取，对资源监控（例如Pods CPU和内存使用率)。集群中的控制器通过Metrics Server监控进行决策，实现弹性伸缩(例如，Horizontal Pod Autoscaler，)。OKE 完全兼容Metrics Server，可以使用这个组件监控。

项目地址：<https://github.com/kubernetes-sigs/metrics-server>
需要注意：

* metric-server提供实时指标.
* 每个节点实时数据是由该节点上的cadvisor采集，metric-server只是发请求给cadvisor并将metric格式的数据转换成。
* aggregate api
  aggregate api提供接口其它组件调用（kube-scheduler、HorizontalPodAutoscaler、Kubernetes集群客户端等），可获取集群监控数据。

## $2. OKE Metrics Serve部署

### $2.1 部署Metrics Server

1、下载对应的稳定版本，目前稳定版本是v0.5.2：
参照<https://github.com/kubernetes-sigs/metrics-server> 中Compatibility Matrix对应信息.

  ```bash
  wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.5.2/components.yaml
  ```

components.yaml 修改部署清单内容：

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

在deployment spec.template.containers.args字段中加上: --kubelet-insecure-tls 选项，表示不验证客户端证书；上述清单主要用deploy控制器将metrics server运行为一个pod，然后授权metrics-server用户能够对pod/node资源进行只读权限；然后把metrics.k8s.io/v1beta1注册到原生apiserver上，让其客户端访问metrics.k8s.io下的资源能够被路由至metrics-server这个服务上进行响应；

2、部署 Metrics Server

  ```bash
  kubectl apply -f components.yaml
  ```

  ```text
  serviceaccount/metrics-server created
  clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
  clusterrole.rbac.authorization.k8s.io/system:metrics-server created
  rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader created
  clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator created
  clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server created
  service/metrics-server created
  deployment.apps/metrics-server created
  apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io created
  ```

### $2.2 验证Metrics Server组件部署成功

1、检查 apiserver是否有 metrics.k8s.io/v1beta1

  ```bash
  kubectl api-versions|grep metrics
  ```

  如果可以看到：*metrics.k8s.io/v1beta1，群组已经注册到原生apiserver上。

2、查看metrics server pod是否运行正常

  ```bash
  kubectl get pods -n=kube-system |grep metrics
  ```

  ```text
   metrics-server-855cc6b9d-g6xsf    1/1     Running   0          18h
  ```

对应pod已经Running，说明正常运行。

3、检查监控数据
使用kubectl top 命令查看pod的cpu ，内存占比，如果Metrics Server服务有异常的话会报：
Error from server (ServiceUnavailable): the server is currently unable to handle the request (get nodes.metrics.k8s.io)

  ```bash
   [root@master1 ~]# kubectl top nodes
  ```

  ```text
    NAME      CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
    master1   272m         3%     4272Mi          29%
    node1     384m         5%     9265Mi          30%
    node2     421m         5%     14476Mi         48%
  ```

可以看到kubectl top命令可以正常执行，说明metrics server 部署成功没有问题。

## $3. Metrics Serve 原理

Metrics Serve从 Kubelet Summary API(类似/ap1/v1/nodes/nodename/stats/summary)采集指标信息，然后聚合，聚合数据将存储在内存中，且以metric-api的形式暴露对外提供访问。Metrics server复用api-server的库来实现自己的功能，比如鉴权、版本等。
因为存放在内存中，因此监控数据是没有持久化的，可以通过第三方存储来拓展。
Metrics-Server架构：
从Kubelet、cAdvisor获取度量数据，再由Metric Server提供给Dashboard、HPA控制器等使用. Metrics Server相当于做了一次数据的转换，把cadvisor格式的数据转换成了kubernetes的api的json格式.

## $4. Metrics Serve 如何获取监控数据

Metrics-Server通过kubelet获取监控数据。kubernetes 1.7版本之前，在每个节点都安装了一个叫做cAdvisor的程序，负责获取节点和容器的CPU，内存等数据; 1.7版本及之后，将cAdvisor精简化内置于kubelet中，可直接从kubelet中获取数据。

通过访问Metrics-Server的方式，HPA，kubectl top等对象就可以正常工作了。

## $5. 总结

OKE的监控体系:Metrics-server属于Core metrics(核心指标)，提供API metrics.k8s.io，仅提供Node和Pod的CPU和内存使用情况。而其他Custom Metrics(自定义指标)由Prometheus等组件来完成。
