terraform {
  required_version = ">= 1.5"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 2.0"
    }
  }

  # Store state remotelyy
  backend "s3" {
    bucket = "dhan-eks-demo-2026"
    key    = "grafana-dashboards/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_api_key
}