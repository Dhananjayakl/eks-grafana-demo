# -------------------------------------------------------
# Grafana Folders
# -------------------------------------------------------

resource "grafana_folder" "eks_dev" {
  title = "EKS - DEV"
}

resource "grafana_folder" "eks_prod" {
  title = "EKS - PROD"
}

# -------------------------------------------------------
# Grafana Dashboards
# -------------------------------------------------------

resource "grafana_dashboard" "eks_dev" {
  folder = grafana_folder.eks_dev.id
  config_json = templatefile("${path.module}/dashboards/eks-dev.json", {
    datasource_uid = grafana_data_source.prometheus_dev.uid
    environment    = "dev"
  })
}

resource "grafana_dashboard" "eks_prod" {
  folder = grafana_folder.eks_prod.id
  config_json = templatefile("${path.module}/dashboards/eks-prod.json", {
    datasource_uid = grafana_data_source.prometheus_prod.uid
    environment    = "prod"
  })
}