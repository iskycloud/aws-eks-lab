# Third Lab


## 개요

- 실습 리소스 생성
  - EC2 (실습 목적)
    - Default VPC
    - AWS Management Console
  - EC2 내 도구
    - EC2 SSH Shell
  - EKS VPC
  - EKS Clsuter 및 Worker Node
    - terraform
  - AWS Load Balancer Controller
    - eksctl
    - Helm
  - Game 2048
    - kubectl
  - Helm Chart Application
    - Helm
    - kubectl

- 실습 리소스 삭제
  - Helm Chart Application
    - kubectl
    - Helm
  - Game 2048
    - kubectl
  - AWS Load Balancer Controller
    - eksctl
  - EKS VPC
  - EKS Clsuter 및 Worker Node
    - terraform
  - EC2 (실습 목적)
    - terraform destroy 완료 후
    - AWS Management Console


## 실습 시작

### EC2 (실습 목적)
- 자세한 내용은 강의자료 PPT 참고
- Default VPC
- AWS Management Console 에서 인스턴스 생성

### EC2 내 도구

### AWS CLI

- 현재 EC2가 있는 Region으로 AWS CLI Default Region 설정

```shell
region_name=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')

aws configure set region $region_name
```

- AWS CLI Default Region 확인
```shell
aws configure get region
```

#### Terraform

- Terraform 설치

```shell
sudo yum install -y yum-utils

sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

sudo yum -y install terraform
```

- Terraform 설치 버전 확인

```shell
terraform version
```

#### kubectl

- kubectl 설치

```shell
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.26.4/2023-05-11/bin/linux/amd64/kubectl

chmod +x ./kubectl

mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH

echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
```

- kubectl 설치 버전 확인

```shell
kubectl version --short --client
```

#### eksctl

- eksctl 설치

```shell
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

sudo mv /tmp/eksctl /usr/local/bin
```

- eksctl 설치 버전 확인

```shell
eksctl version
```

#### Helm

- Helm 설치

```shell
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

- Helm 설치 버전 확인

```shell
helm version
```

### EKS VPC
### EKS Clsuter 및 Worker Node

- Terraform

- Terraform 초기 설정

```shell
terraform init
```

- Terraform 계획

```shell
terraform plan
```

- Terraform 실행

```shell
terraform apply
```

- kubeconfig 업데이트

```shell
region_name=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
```

```shell
cluster_name=
```

```shell
aws eks update-kubeconfig --region $region_name --name $cluster_name
```

- kubeconfig 확인

```shell
kubectl cluster-info
```

### AWS Load Balancer Controller
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/aws-load-balancer-controller.html

- IAM 역할 생성. AWS Load Balancer Controller의 kube-system 네임스페이스에 aws-load-balancer-controller라는 Kubernetes 서비스 계정을 생성하고 IAM 역할의 이름으로 Kubernetes 서비스 계정에 주석을 답니다.
- my-cluster를 사용자 클러스터 이름으로 바꾸고 111122223333을 계정 ID로 바꾼 다음 명령을 실행합니다.

```shell
cluster_name=
```

```shell
role_name=Custom_EKS_LBC_Role-$cluster_name
```

```shell
account_id=$(aws sts get-caller-identity --query 'Account' --output text)
```

```shell
eksctl create iamserviceaccount \
  --cluster=${cluster_name} \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name ${role_name} \
  --attach-policy-arn=arn:aws:iam::${account_id}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve
```

- Helm Repository 추가

```shell
helm repo add eks https://aws.github.io/eks-charts
```

- Helm Local Repository 업데이트

```shell
helm repo update
```

- Helm Chart 설치
```shell
cluster_name=
```

```shell
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${cluster_name} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller 
```

### Game 2048
- kubectl
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/alb-ingress.html

- Game 2048을 샘플 애플리케이션으로 배포하여 AWS Load Balancer Controller가 인그레스 대상의 결과로 AWS ALB를 생성하는지 확인합니다.

```shell
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/examples/2048/2048_full.yaml
```

- 몇 분후, 인그레스 리소스가 다음 명령으로 생성되었는지 확인합니다.

```shell
kubectl get ingress/ingress-2048 -n game-2048
```

### Helm Chart Application

- https://docs.vmware.com/en/VMware-Application-Catalog/services/tutorials/GUID-create-first-helm-chart-index.html

- 실습용 Namespace 생성

- Helm Chart 생성

```shell
helm create mychart
```

- Helm Chart 설치 계획

```shell
helm install mychart --dry-run --debug ./mychart
```

- Helm Chart 설치

```shell
helm install example ./mychart --set service.type=NodePort
```

- Ingress 별도 설치

```shell
cat >ingress-mychart.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-mychart
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: example-mychart
              port:
                number: 80
EOF
```

```shell
kubectl apply -f ingress-mychart.yaml
```
- 오버라이드할 설정 값 파일 생성

```shell
cat >exmaple-values.yaml <<EOF
image:
  repository: prydonius/todo
  tag: 1.0.0
  pullPolicy: IfNotPresent
service:
  type: NodePort
EOF
```

- Helm Chart 및 설정 값 업그레이드

```shell
helm upgrade example ./mychart -f exmaple-values.yaml
```

- Helm Release History 조회

```shell
helm history example
```

- Helm Release Rollback

```shell
helm rollback example 1
```

## 실습 종료

### Helm Chart Application

- kubectl delete

```shell
kubectl delete -f ingress-mychart.yaml
```

- helm uninstall

```shell
helm uninstall example
```

### Game 2048

- 샘플 애플리케이션에 대한 실험이 끝나면 다음 명령 중 하나를 실행하여 이를 삭제합니다.

```shell
kubectl delete -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/examples/2048/2048_full.yaml
```

### AWS Load Balancer Controller

- Helm uninstall

```shell
helm uninstall aws-load-balancer-controller \
  -n kube-system
```

- eksctl delete

```shell
cluster_name=
```

```shell
eksctl delete iamserviceaccount \
  --cluster=${cluster_name} \
  --namespace=kube-system \
  --name=aws-load-balancer-controller
```

### EKS VPC
### EKS Clsuter 및 Worker Node
- terraform destory

```
terraform destroy
```

### EC2 (실습 목적)
- terraform destroy 완료 후
- AWS Management Console 에서 인스턴스 종료


## Appendix

### EKS IAM Role

#### Cluster IAM Role
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/service_IAM_role.html
- 
```shell
cat >cluster-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name CustomAmazonEKSClusterRole \
  --assume-role-policy-document file://cluster-trust-policy.json

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
  --role-name CustomAmazonEKSClusterRole
```

#### Node IAM Role
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/create-node-role.html
- 
```shell
cat >node-role-trust-relationship.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name CustomAmazonEKSNodeRole \
  --assume-role-policy-document file://node-role-trust-relationship.json

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy \
  --role-name CustomAmazonEKSNodeRole

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly \
  --role-name CustomAmazonEKSNodeRole

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy \
  --role-name CustomAmazonEKSNodeRole
```

#### Fargate Profile IAM Role
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/pod-execution-role.html

```shell
cat >pod-execution-role-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks-fargate-pods.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name CustomAmazonEKSFargatePodExecutionRole \
  --assume-role-policy-document file://pod-execution-role-trust-policy.json

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy \
  --role-name CustomAmazonEKSFargatePodExecutionRole
```

#### AWS Load Balancer Controller IAM Policy

- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/aws-load-balancer-controller.html

- 사용자 대신 AWS API를 호출할 수 있는 AWS Load Balancer Controller의 IAM 정책을 다운로드합니다.

```shell
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json
```

- 이전 단계에서 다운로드한 정책을 사용하여 IAM 정책을 만듭니다.

```shell
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json
```

### K9s

- K9s 설치

```shell
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | jq -r '.tag_name')
curl -sL https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz | sudo tar xfz - -C /usr/local/bin k9s
```
