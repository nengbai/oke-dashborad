# Kuboard 安装配置手册

## $1. Kuboard安装
node 网络策略打开： 2381/2379
1、 下载kuboard 
curl -o kuboard-v3.yaml https://addons.kuboard.cn/kuboard/kuboard-v3.yaml
kubectl label nodes 10.0.10.12 k8s.kuboard.cn/role=etcd

VE6l7a[.(CQD3J[26JLl
docker login icn.ocir.io -u 'cnxcypamq98c/haiyouyouit@outlook.com'
docker pull eipwork/kuboard:v3
docker tag docker.io/eipwork/kuboard:v3 icn.ocir.io/cnxcypamq98c/devops-repos/kuboard:v3
docker push icn.ocir.io/cnxcypamq98c/devops-repos/kuboard:v3
```text
The push refers to repository [icn.ocir.io/cnxcypamq98c/devops-repos/kuboard]
aeb3c5b5c924: Pushed 
b170317bee9c: Pushed 
e0928b0584bd: Pushed 
4d9f45858aeb: Pushed 
79b62eb03c2d: Pushed 
147d52b92748: Pushed 
a8462576927f: Pushed 
617fc375f023: Pushed 
22d9813f1d6a: Pushed 
2d8252e11370: Pushed 
c6326a520ea1: Pushed 
2c36b623e8a4: Pushed 
c115311979a3: Pushed 
26725f6b83a9: Pushed 
6f01486329d9: Pushed 
f45c2d82bd42: Pushed 
69250cb8a892: Pushed 
v3: digest: sha256:43d2256e0855b41bb98178bc39d03b7a298181b6432707c6e4c6678beb4b637a size: 4105

```
```
docker pull eipwork/etcd-host:3.4.16-2
3.4.16-2: Pulling from eipwork/etcd-host
39fafc05754f: Already exists 
6f4d54e2f543: Pull complete 
0304e75162bf: Pull complete 
96ddb7a539fb: Pull complete 
3dd1215212d5: Pull complete 
fd7b697039e2: Pull complete 
7ae28fe606ab: Pull complete 
1c5877a5de24: Pull complete 
b5c440a4eb47: Pull complete 
Digest: sha256:acae6ece3a09ef05280512825a5e5e6f3cfefd10a234a96f0f9189b986914ea4
Status: Downloaded newer image for eipwork/etcd-host:3.4.16-2
docker.io/eipwork/etcd-host:3.4.16-2


docker tag docker.io/eipwork/etcd-host:3.4.16-2 icn.ocir.io/cnxcypamq98c/devops-repos/etcd-host:3.4.16-2
docker push icn.ocir.io/cnxcypamq98c/devops-repos/etcd-host:3.4.16-2

```bash
kubectl create secret docker-registry ocisecret --docker-server=icn.ocir.io --docker-username='<oci username>' --docker-password='<auth token>' --docker-email='<email address>' -n kuboard
secret/ocirsecret created
```
```text
imagePullPolicy: IfNotPresent
imagePullSecrets:
        - name: ocirsecret
```
2、执行安装
```bash

kubectl kuboard-v3.yaml
```
``` text
namespace/kuboard created
configmap/kuboard-v3-config created
serviceaccount/kuboard-boostrap created
clusterrolebinding.rbac.authorization.k8s.io/kuboard-boostrap-crb created
daemonset.apps/kuboard-etcd created
deployment.apps/kuboard-v3 created
service/kuboard-v3 created

```
2、检查安装状态
    ```bash
        kubectl -n kuboard get pod
    ```
    ```text
      NAME                          READY   STATUS    RESTARTS   AGE
      kuboard-etcd-hfsmb            1/1     Running   0          40s
      kuboard-etcd-rn8q6            1/1     Running   0          39s
      kuboard-etcd-xgchj            1/1     Running   0          40s
      kuboard-v3-7b6698fc79-lrsxz   1/1     Running   0          40s
    ```
    $ kubectl -n kuboard get svc
    ```text
    NAME         TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                                        AGE
    kuboard-v3   NodePort   10.96.183.245   <none>        80:30080/TCP,10081:30081/TCP,10081:30081/UDP   2m56s
    ```


3、根据域名生成https证书

例如域名：example.com
bash create_cert.sh oke-admin  oke-kuboard example.com kuboard
```bash
Generating a 2048 bit RSA private key
..................................................+++
..+++
writing new private key to 'oke-kuboard.key'
-----
kuboard                Active   36m
[INFO] kuboard is already exists
secret/oke-admin created

```
4、增加Ingress

kubectl apply -f kuboard-ingress.yaml 
```text

ingress.networking.k8s.io/oke-kuboard-ingress created
```

5、检查Ingress状态

kubectl -n kuboard get ing

```text
NAME                  CLASS   HOSTS                     ADDRESS          PORTS     AGE
oke-kuboard-ingress   nginx   oke-kuboard.example.com   141.147.172.67   80, 443   2m44s
```

6、 验证
增加域名解释

在Firefox or chrome 打开：https://oke-kuboard.example.com

访问 Kuboard

    在浏览器中打开链接 http://your-node-ip-address:30080

    输入初始用户名和密码，并登录
        用户名： admin
        密码： Kuboard123

7、登陆后安装node agent
   替换成您集群的url: <https://oke-kuboard.example.com>
curl -iks 'https://oke-kuboard.example.com/kuboard-api/cluster/default/kind/KubernetesCluster/default/resource/installAgentToKubernetes?token=vgXFuAEgTSU0Uq9DFwCUOApyIyHxmGPO' > kuboard-agent.yaml

  执行kuboard-agent.yaml 
kubectl apply -f kuboard-agent.yaml 
