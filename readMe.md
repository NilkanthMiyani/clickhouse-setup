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

The chart creates two Services, both ClusterIP (nothing is reachable from
outside the cluster - add an ingress or port-forward for that):

- `clickhouse` - load balances across pods, use this one
- `clickhouse-headless` - stable per-pod DNS, used by ClickHouse internally

```
clickhouse.clickhouse.svc.cluster.local:8123   # HTTP
clickhouse.clickhouse.svc.cluster.local:9000   # native
```

### Ports exposed by default

| Port | Protocol | Notes |
|------|----------|-------|
| 8123 | HTTP | REST / curl / most BI tools |
| 9000 | Native TCP | fastest, used by the Go and Python drivers |
| 9004 | MySQL wire | connect with a plain MySQL client, no ClickHouse driver needed |
| 9005 | PostgreSQL wire | same idea, with a Postgres client |
| 9009 | Inter-server | replication traffic between nodes, not for clients |

9004 and 9005 can be turned off with `exposeMysql` / `exposePostgresql` in
values.yml.

```sh
kubectl port-forward -n clickhouse svc/clickhouse 8123:8123
curl 'http://localhost:8123/?query=SELECT%20version()' -u default:<password>
```

Password comes from `./secrets/clickhouse.yml`.

## Notes

- Password lives in `./secrets/clickhouse.yml` (gitignored), wired in through
  `auth.existingSecret`. `./secrets-example/` holds the committable template.
- One pod, no replication. Raise `replicaCount` and set `keeper.enabled: true` for HA.
- Chart pinned to 9.4.4 (ClickHouse 25.7.5) in cluster.sh. The chart defaults to
  `shards: 2` / `replicaCount: 3`, so an unpinned upgrade could change the topology.
