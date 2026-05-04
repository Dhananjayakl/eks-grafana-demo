variable "grafana_url" {
  description = "URL of your Grafana instance on EC2 (e.g. http://1.2.3.4:3000)"
  type        = string
}

variable "grafana_api_key" {
  description = "Grafana API key or 'user:password' for basic auth"
  type        = string
  sensitive   = true
}

variable "prometheus_url_dev" {
  description = "External URL of Prometheus scraping the dev namespace"
  type        = string
  # Example: http://<LoadBalancer-hostname>:9090
}

variable "prometheus_url_prod" {
  description = "External URL of Prometheus scraping the prod namespace"
  type        = string
}
