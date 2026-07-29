# ClickHouse on EKS

Single-node ClickHouse via the Bitnami helm chart.

## 1. Create the cluster

```sh
cd cluster.tf
terraform init
terraform plan
terraform apply
```

```sh
aws eks update-kubeconfig --region mx-central-1 --name prod-proj-cluster --profile prod-proj
```

## 2. Deploy ClickHouse

```sh
sh cluster.sh
```

This updates the kubeconfig, installs the `aws-ebs-csi-driver` addon and its IAM
role, applies the StorageClass and namespace, then helm-installs ClickHouse.
Safe to re-run.

## 3. Connect

```
clickhouse.clickhouse.svc.cluster.local:8123   # HTTP
clickhouse.clickhouse.svc.cluster.local:9000   # native
```

```sh
kubectl port-forward -n clickhouse svc/clickhouse 8123:8123
curl 'http://localhost:8123/?query=SELECT%20version()' -u default:<password>
```

## Notes

- `auth.password` is plaintext in `values.yml` - move it to a Secret before prod.
- One pod, no replication. Raise `replicaCount` and set `keeper.enabled: true` for HA.
- Pin `image.tag` and `--version` after `helm search repo bitnami/clickhouse --versions`.
