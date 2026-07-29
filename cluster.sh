#!/bin/bash
set -e


echo "Updating kubeconfig..."
aws eks update-kubeconfig --region mx-central-1 --name prod-proj-cluster --profile prod-proj --alias prod-proj


echo "Associating IAM OIDC provider..."
eksctl utils associate-iam-oidc-provider --region=mx-central-1 --cluster=prod-proj-cluster --profile prod-proj --approve

eksctl create iamserviceaccount --name ebs-csi-controller-sa --namespace kube-system --cluster prod-proj-cluster --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --approve --role-only --role-name AmazonEKS_EBS_CSI_DriverRole --region=mx-central-1 --profile prod-proj || true

echo "Installing aws-ebs-csi-driver addon..."
# account id read from the caller instead of hardcoded into the arn
eksctl create addon --name aws-ebs-csi-driver --cluster prod-proj-cluster --service-account-role-arn "arn:aws:iam::$(aws sts get-caller-identity --profile prod-proj --query Account --output text):role/AmazonEKS_EBS_CSI_DriverRole" --force --region=mx-central-1 --profile prod-proj

echo "Waiting for the EBS CSI controller..."
kubectl wait --for=condition=Available deployment/ebs-csi-controller -n kube-system --timeout=300s

# StorageClass + namespace
echo "Applying StorageClass..."
kubectl apply -f ./storage-service/storage-class.yml

echo "Applying namespace..."
kubectl apply -f ./services-deployment/clickhouse/name.yml

echo "Applying secrets..."
# must run before helm, values.yml points auth.existingSecret at clickhouse-auth
kubectl apply -f ./secrets

# ClickHouse
echo "Installing ClickHouse..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update bitnami

helm upgrade --install clickhouse bitnami/clickhouse \
  --version 9.4.4 \
  -f ./services-deployment/clickhouse/values.yml \
  --namespace clickhouse

echo "Waiting for ClickHouse..."
kubectl rollout status statefulset/clickhouse-shard0 -n clickhouse --timeout=600s

# -------------------------
# Status
# -------------------------
echo "Done!"
kubectl get pods -n clickhouse
kubectl get svc -n clickhouse
kubectl get pvc -n clickhouse
