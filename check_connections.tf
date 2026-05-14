# This asks GCP: "Who am I and what project am I in?"
data "google_client_config" "current" {}

# This asks Azure: "What is my Client ID and Subscription?"
data "azurerm_client_config" "current" {}

# These will print the results to your terminal
output "gcp_project_connection" {
  value = data.google_client_config.current.project
}

output "azure_subscription_connection" {
  value = data.azurerm_client_config.current.subscription_id
}