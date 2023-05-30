# Second Lab

## 개요

- 실습 내용
  - Terraform을 활용한 Amazon VPC, EKS 리소스 생성
  - AWS Load Balancer Controller 추가 기능 설치
  - Game 2048 배포
  - Game 2048 서비스 확인
- 실습 완료 후, 실습 리소스 삭제
  - Game 2048 삭제
  - AWS IAM - AWS Load Balancer Controller 관련 리소스 삭제
  - Terraform을 활용한 Amazon EKS 리소스 삭제

## 진행 절차

### 사전 환경 설정

1. EC2 인스턴스 생성 및 SSH 접속

2. Terraform 설치

```shell
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform
```

3. Clone Git Repository

```shell
git clone https://github.com/iskycloud/aws-eks-lab.git
```

### Amazone VPC, EKS 리소스 생성

1. 작업 디렉토리 이동

```shell
cd ./aws-eks-lab/second-lab/terraform/
```

2. Terraform 초기화

```shell
terraform init
```

3. Terraform dry run

```shell
terraform plan
```

- 출력 내용 확인

4. Terraform apply

```shell
terraform apply
```

- 출력 내용 확인
- yes 입력하고 엔터

### AWS Load Balancer Controller 추가 기능 설치

1. 작업 디렉토리 이동

```shell
cd ../aws-load-balancer-controller/
```

2. kubectl 설치

```shell
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.26.2/2023-03-17/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
kubectl version --short --client
```

```shell
eks_cluster_name="demo-eks"
aws eks update-kubeconfig --region us-east-1 --name $eks_cluster_name
```

3. AWS IAM - AWS Load Balancer Controller Role - Trust Policy 데이터 수정

```shell
oidc_id=$(aws eks describe-cluster --region us-east-1 --name demo-eks --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4
```

- 출력 내용 확인
- **공백일 경우 다음 단계 진행 불가하며 확인 필요**

```shell
sed -i.bak -e "s|your-oidc-id|${oidc_id}|" ./load-balancer-role-trust-policy.json
```

```shell
account_id=$(aws sts get-caller-identity --query 'Account' --output text)
```

```shell
sed -i.bak -e "s|your-account-id|${account_id}|" ./load-balancer-role-trust-policy.json
```

4. AWS IAM - AWS Load Balancer Controller Role 생성

```shell
aws iam create-role \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --assume-role-policy-document file://load-balancer-role-trust-policy.json
```

5. AWS IAM - AWS Load Balancer Controller Policy 생성

```shell
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

6. AWS IAM - AWS Load Balancer Controller Role - Policy 연결

```shell
account_id=$(aws sts get-caller-identity --query 'Account' --output text)
```

```shell
aws iam attach-role-policy \
  --policy-arn arn:aws:iam::${account_id}:policy/AWSLoadBalancerControllerIAMPolicy \
  --role-name AmazonEKSLoadBalancerControllerRole
```

7. Kubernetes ServiceAccount 데이터 수정

```shell
account_id=$(aws sts get-caller-identity --query 'Account' --output text)
```

```shell
sed -i.bak -e "s|your-account-id|${account_id}|" ./aws-load-balancer-controller-service-account.yaml
```

8. Kubernetes ServiceAccount 생성

```shell
kubectl apply -f ./aws-load-balancer-controller-service-account.yaml
```

9. cert-manager 설치

```shell
kubectl apply --validate=false -f ./cert-manager.yaml
```

10. Kubernetes AWS Load Balancer Controller 데이터 수정

```shell
sed -i.bak -e '561,569d' v2_4_7_full.yaml
```

```shell
eks_cluster_name="demo-eks"
```

```shell
sed -i.bak -e "s|your-cluster-name|${eks_cluster_name}|" ./v2_4_7_full.yaml
```

11. Kubernetes AWS Load Balancer Controller 생성

```shell
kubectl apply -f ./v2_4_7_full.yaml
```

12. Kubernetes AWS Load Balancer Controller IngressClass 생성

```shell
kubectl apply -f ./v2_4_7_ingclass.yaml
```

### Game 2048 배포

1. 작업 디렉토리 이동

```shell
cd ../game-2048/
```

1. Kubernetes - Game 2048 배포

```shell
kubectl apply -f ./2048_full.yaml
```

### Game 2048 삭제

1. Kubernetes - Game 2048 삭제

```shell
kubectl delete -f ./2048_full.yaml
```

### AWS IAM - AWS Load Balancer Controller 관련 리소스 삭제

1. AWS IAM - AWS Load Balancer Controller Role - Policy 연결 해제

```shell
account_id=$(aws sts get-caller-identity --query 'Account' --output text)
```

```shell
aws iam detach-role-policy \
  --policy-arn arn:aws:iam::${account_id}:policy/AWSLoadBalancerControllerIAMPolicy \
  --role-name AmazonEKSLoadBalancerControllerRole
```

2. AWS IAM - AWS Load Balancer Controller Policy 삭제

```shell
account_id=$(aws sts get-caller-identity --query 'Account' --output text)
```

```shell
aws iam delete-policy \
  --policy-arn arn:aws:iam::${account_id}:policy/AWSLoadBalancerControllerIAMPolicy
```

3. AWS IAM - AWS Load Balancer Controller Role 삭제

```shell
aws iam delete-role --role-name AmazonEKSLoadBalancerControllerRole
```

### Amazone VPC, EKS 리소스 삭제

1. 작업 디렉토리 이동

```shell
cd ../terraform/
```

2.  Terraform Destroy

```shell
terraform destroy
```

- 출력 내용 확인
- yes 입력하고 엔터

## Troubleshooting

### AWS IAM OIDC Provider 오류 발생 시 해결 방법

1. AWS CLI 인증 정보 디렉토리 생성

```shell
mkdir ~/.aws
```

2. AWS CLI 인증 정보 변경

```shell
vi ~/.aws/credentials
```
AWS CLI Credentials 저장

3. 작업 디렉토리 이동

```shell
cd ../troubleshooting/
```

4. AWS IAM - Policy 생성

```shell
aws iam create-policy \
    --policy-name CustomIAMFullAccess \
    --policy-document file://CustomIAMFullAccess.json
```

5. AWS IAM - LabRole Role - Policy 연결

```shell
account_id=$(aws sts get-caller-identity --query 'Account' --output text)
```

```shell
aws iam attach-role-policy \
  --policy-arn arn:aws:iam::${account_id}:policy/CustomIAMFullAccess \
  --role-name LabRole
```

6. AWS CLI 인증 정보 롤백

```shell
mv ~/.aws ~/.aws.bak
```

7. 추후, IAM Policy 롤백

```shell
account_id=$(aws sts get-caller-identity --query 'Account' --output text)
```

```shell
aws iam detach-role-policy \
  --policy-arn arn:aws:iam::${account_id}:policy/CustomIAMFullAccess \
  --role-name LabRole
```

```shell
account_id=$(aws sts get-caller-identity --query 'Account' --output text)
```

```shell
aws iam delete-policy \
  --policy-arn arn:aws:iam::${account_id}:policy/CustomIAMFullAccess
```

## 추가 프로그램

### k9s

1. 설치 방법

```shell
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | jq -r '.tag_name')
curl -sL https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz | sudo tar xfz - -C /usr/local/bin k9s
```
