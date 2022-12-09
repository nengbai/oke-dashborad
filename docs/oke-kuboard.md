# Kuboard 安装配置手册

## $1. 环境准备

### $1.1、选择3个OKE Worker增加role标识etcd

1、获取节点信息

    ```bash
    $ <copy> kubectl get nodes </copy>
    ```

2、标识节点为etcd

    ```bash
    $<copy> kubectl label nodes 10.0.10.12 k8s.hubbard.cn/role=etcd </copy>
    ```

### $1.2、Namespace准备

    ```bash
    $ <copy>kubectl create ns kuboard </copy>
    ```

### $1.3、Secret 准备

    为了能安全正常从OCI Docker Registry拉取容器镜像，需要使用该集群OCI账号和 auth token 在OKE集群中该Namespace中增加Secret Key。例如：为Namespace kuboard 增加 Secret Key。

    ```bash
    $ <copy>kubectl create secret docker-registry ocisecret --docker-server=icn.ocir.io --docker-username='<oci username>' --docker-password='<auth token>' --docker-email='<email address>' -n kuboard </copy>
    ```

### $1.4、Kuboard 和 etcd镜像准备

下面以OCI Docker Registry: icn.ocir.io为例演示。
1、 验证OCI Docker Registry登录

    ```bash
    $<copy> docker login icn.ocir.io -u '<tenacy/oci username>' </copy>
    ````
2、拉取kuoard 和 etcd镜像，并重命名OCI Docker Registry存储路径
   替换< icn.ocir.io/cnxcypamq98c/devops-repos > 为您的OCI Docker Registry镜像仓库路径。

    ```bash
    $ <copy> docker pull eipwork/kuboard:v3 </copy>
    $ <copy> docker tag docker.io/eipwork/kuboard:v3 icn.ocir.io/cnxcypamq98c/devops-repos/kuboard:v3 </copy>
    $ <copy> docker pull eipwork/etcd-host:3.4.16-2 </copy>
    $ <copy> docker tag docker.io/eipwork/etcd-host:3.4.16-2 icn.ocir.io/cnxcypamq98c/devops-repos/et3.4.16-2 </copy>
    ```
3、 上传Docker Registry存储
    替换< icn.ocir.io/cnxcypamq98c/devops-repos > 为您的OCI Docker Registry镜像仓库路径。

    ```bash
    $ <copy> docker push icn.ocir.io/cnxcypamq98c/devops-repos/kuboard:v3 </copy> 
    $ <copy> docker push icn.ocir.io/cnxcypamq98c/devops-repos/etcd-host:3.4.16-2 </copy> 
    ```

## $2. Kuboard安装

### $2.1、 下载kuboard

    ```bash
    $ <copy> curl -o kuboard-v3.yaml https://github.com/nengbai/oke-dashborad/blob/main/kuboard/kuboard-v3.yaml </copy> 
    $ <copy> curl -o kuboard-ingress.yaml https://github.com/nengbai/oke-dashborad/blob/main/kuboard/kuboard-ingress.yaml </copy>
    ```

### $2.2、 编辑调整 kuboard-v3.yaml 中kuboard和etcd章节containers下面参数

    注意：image项目替换成上面OCI Doctor Registry中镜像。imagePullSecrets对应的Name为上面生成Secret Key.

    ```text
    containers:
    - env:
      image: 'icn.ocir.io/cnxcypamq98c/devops-repos/etcd-host:3.4.16-2'
      imagePullPolicy: IfNotPresent
    imagePullSecrets:
      - name: ocisecret
    ```

### $2.3、安装Kuboard

1、执行kuboard-v3.yaml

    ```bash
    $ <copy> kubectl kuboard-v3.yaml</copy> 
    namespace/kuboard created
    co/kuboard-v3-config crea
    serviceaccount/kuboard-boostrap created
    clusterrolebinding.rbac.authorization.k8s.io/kuboard-boostrap-crb created
    daemonset.apps/kuboard-etcd created
    deployment.apps/kuboard-v3 created
    service/kuboard-v3 created
    ```

2、 检查kuboard安装状态

    ```bash
    $ <copy> kubectl -n kuboard get pod </copy> 
    NAME                          READY   STATUS    RESTARTS   AGE
    kutcd-hfsmb            1/1  g   0          40s
    kuboard-etcd-rn8q6            1/1     Running   0          39s
    kuboard-etcd-xgchj            1/1     Running   0          40s
    kuboard-v3-7b6698fc79-lrsxz   1/1     Running   0          40s
    ```

    ```bash
    $ <copy> kubectl -n kuboard get svc </copy> 
    NAME         TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                                        AGE
    ku3   NodePort   10.96.183.2e>        80:30080/TCP,10081:30081/TCP,10081:30081/UDP   2m56s
    ```

### $2.4、Kuboard增加Ingress

1、编辑kuboard-ingress.yaml,调整域名:example.com 为您拥有域名
2、执行kuboard-ingress.yaml

    ```bash
    $ <copy> kubectl apply -f kuboard-ingress.yaml </copy> 
    ingress.networking.k8s.io/oke-kuboard-ingress created
    ```
3、检查Ingress状态

    ```bash
    $ <copy> kubectl -n kuboard get ing </copy> 
    NAME                  CLASS   HOSTS                     ADDRESS          PORTS     AGE
    okrd-ingress   nginx   oke-kxample.com   141.147.172.67   80, 443   2m44s
    ```

## $3、验证

1、增加域名解释
长期使用建议使用dns服务解释，如果是临时测试，建议在本地hosts中增加，下面以mac中增加域名解释为例。

    ```bash
    $ <copy> sudo vi /etc/hosts</copy> 
    141.147.172.67  oke-kuboard.example.com
    ```
2、浏览器访问 Kuboard 验证
    在浏览器中打开链接<http://your-ingress>
    例如： <http://oke-kuboard.example.com>
    输入初始用户名和密码，并登录
        用户名： admin
        密码： Kuboard123
