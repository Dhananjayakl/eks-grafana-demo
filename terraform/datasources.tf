# -------------------------------------------------------
# Grafana Datasources — one per environment
# -------------------------------------------------------

resource "grafana_data_source" "prometheus_dev" {
  name       = "Prometheus-DEV"
  type       = "prometheus"
  url        = var.prometheus_url_dev
  is_default = false

  json_data_encoded = jsonencode({
    httpMethod     = "POST"
    prometheusType = "Prometheus"
    # Label to help Grafana filter by environment in queries
    customQueryParameters = "namespace=dev"
  })
}

resource "grafana_data_source" "prometheus_prod" {
  name       = "Prometheus-PROD"
  type       = "prometheus"
  url        = var.prometheus_url_prod
  is_default = false

  json_data_encoded = jsonencode({
    httpMethod            = "POST"
    prometheusType        = "Prometheus"
    customQueryParameters = "namespace=prod"
  })
}
