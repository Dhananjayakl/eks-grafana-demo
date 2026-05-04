# EKS + Grafana Monitoring Demo
## Prometheus + Node Exporter + Terraform + GitHub Actions

---

## Architecture

```
GitHub Actions ──► Terraform ──► Grafana (EC2)
                                     │
                         ┌───────────┴───────────┐
                  Datasource: DEV         Datasource: PROD
                         │                       │
               EKS Namespace: dev       EKS Namespace: prod
               ┌─────────────────┐     ┌─────────────────┐
               │  sample-app     │     │  sample-app      │
               │  (nginx x2)     │     │  (nginx x3)      │
               └────────┬────────┘     └────────┬─────────┘
                        │                       │
               EKS Namespace: monitoring (Helm)
               ┌──────────────────────────────────────────┐
               │  kube-prometheus-stack                    │
               │  ├── Prometheus (LoadBalancer)            │
               │  ├── Alertmanager                         │
               │  ├── Node Exporter (DaemonSet)            │
               │  └── kube-state-metrics                   │
               └──────────────────────────────────────────┘
```

---

## Part 1 — Manual EKS Setup

### Step 1: Start Grafana on EC2

```bash
# SSH into EC2
ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>

# Install Docker + Docker Compose
sudo yum update -y
sudo yum install docker -y
sudo systemctl start docker
sudo usermod -aG docker ec2-user

sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone your repo and start Grafana
git clone <your-repo>
cd eks-grafana-demo
GRAFANA_ADMIN_PASSWORD=YourStrongPassword docker-compose up -d

# Grafana is now at http://<EC2_IP>:3000
```

Make sure EC2 Security Group allows:
- Inbound port 3000 (Grafana)
- Outbound to EKS LoadBalancer on port 9090

### Step 2: Deploy EKS Workloads

```bash
# Point kubectl at your cluster
aws eks update-kubeconfig --name <CLUSTER_NAME> --region <REGION>

# Deploy sample apps
kubectl apply -f k8s/dev/workload.yaml
kubectl apply -f k8s/prod/workload.yaml

# Verify
kubectl get pods -n dev
kubectl get pods -n prod
```

### Step 3: Install kube-prometheus-stack via Helm

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values k8s/monitoring/values.yaml \
  --wait

# Get the Prometheus external address
kubectl get svc -n monitoring kube-prometheus-stack-prometheus
# Note the EXTERNAL-IP — this is your PROMETHEUS_URL
```

### Step 4: Verify Prometheus is scraping

Open `http://<PROMETHEUS_EXTERNAL_IP>:9090` in browser and check:
- Status → Targets — you should see dev and prod pods listed
- Try query: `kube_pod_status_phase{namespace="dev"}`

---

## Part 2 — Terraform + GitHub Actions Setup

### Step 5: Create Grafana API Key

```
1. Open Grafana at http://<EC2_IP>:3000
2. Login as admin
3. Go to: Administration → Service Accounts → Add service account
4. Name: terraform-deployer, Role: Editor
5. Add token → copy the token
```

### Step 6: Set GitHub Secrets

In your GitHub repo → Settings → Secrets → Actions, add:

| Secret Name          | Value                                      |
|---------------------|--------------------------------------------|
| `AWS_ACCESS_KEY_ID` | IAM key with S3 access (for TF state)      |
| `AWS_SECRET_ACCESS_KEY` | IAM secret                             |
| `AWS_REGION`        | e.g. `us-east-1`                           |
| `GRAFANA_URL`       | `http://<EC2_PUBLIC_IP>:3000`              |
| `GRAFANA_API_KEY`   | Grafana service account token              |
| `PROMETHEUS_URL_DEV` | `http://<PROMETHEUS_LB_IP>:9090`          |
| `PROMETHEUS_URL_PROD` | `http://<PROMETHEUS_LB_IP>:9090`         |

> Note: For this demo both dev and prod use the same Prometheus (same cluster).
> The namespace label filters in PromQL separate the environments.

### Step 7: Update Terraform S3 backend

Edit `terraform/main.tf` and update the backend block:
```hcl
backend "s3" {
  bucket = "your-actual-state-bucket"
  key    = "grafana-dashboards/terraform.tfstate"
  region = "us-east-1"
}
```

### Step 8: Push and trigger GitHub Actions

```bash
git add .
git commit -m "feat: add EKS Grafana monitoring setup"
git push origin main
```

The workflow will:
1. `terraform plan` on every PR
2. `terraform apply` on merge to main
3. Creates two Grafana datasources (DEV + PROD)
4. Creates two Grafana folders + dashboards

### Step 9: View your dashboards

Open Grafana → Dashboards:
- **EKS - DEV** → CPU, memory, pod status for dev namespace
- **EKS - PROD** → CPU, memory, pod restarts, pod status for prod namespace

---

## File Structure

```
eks-grafana-demo/
├── docker-compose.yml              # Grafana on EC2
├── k8s/
│   ├── dev/workload.yaml           # Dev namespace + nginx deployment
│   ├── prod/workload.yaml          # Prod namespace + nginx deployment
│   └── monitoring/
│       ├── values.yaml             # kube-prometheus-stack Helm values
│       └── install.sh              # One-shot install script
├── terraform/
│   ├── main.tf                     # Provider + backend config
│   ├── variables.tf                # Input variables
│   ├── datasources.tf              # Grafana datasource resources
│   ├── dashboards.tf               # Grafana folder + dashboard resources
│   ├── outputs.tf                  # Dashboard URLs
│   └── dashboards/
│       ├── eks-dev.json            # DEV dashboard definition
│       └── eks-prod.json           # PROD dashboard definition
└── .github/workflows/
    └── grafana-dashboards.yml      # CI/CD pipeline
```

---

## Troubleshooting

**Prometheus not scraping pods?**
```bash
kubectl get servicemonitor -n monitoring
kubectl describe prometheusrule -n monitoring
```

**Grafana can't reach Prometheus?**
- Check EC2 security group allows outbound to EKS node security group on port 9090
- Check EKS node security group allows inbound from EC2 security group on port 9090
- Test from EC2: `curl http://<PROMETHEUS_IP>:9090/-/healthy`

**Terraform apply fails with auth error?**
- Verify `GRAFANA_API_KEY` secret is set correctly
- Make sure the service account has Editor role in Grafana

**No metrics showing in dashboard?**
- Wait 2–3 minutes for Prometheus to start scraping
- Check Prometheus targets: `http://<PROMETHEUS_IP>:9090/targets`
- Verify namespace labels: query `kube_pod_info{namespace="dev"}` in Prometheus UI
