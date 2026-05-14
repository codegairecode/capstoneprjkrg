# 1. Create a Resource Group (The Azure "Folder" for your website)
resource "azurerm_resource_group" "ev_fleet_frontend" {
  name     = "EV-Fleet-UI-RG"
  location = "Australia East" # Keeps it geographically close to AWS/GCP servers
}

# 2. Create the Storage Account and turn it into a Web Server
resource "azurerm_storage_account" "dashboard_storage" {
  name                     = "evfleetkrgkiwiev"
  resource_group_name      = azurerm_resource_group.ev_fleet_frontend.name
  location                 = azurerm_resource_group.ev_fleet_frontend.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # This specific block tells Azure to serve this as a public website
  static_website {
    index_document     = "index.html"
    error_404_document = "404.html"
  }
}

# 3. Print the live Website URL to your terminal
output "ev_dashboard_url" {
  value = azurerm_storage_account.dashboard_storage.primary_web_endpoint
}
# 4. Upload the HTML file to the Azure Web Server
resource "azurerm_storage_blob" "index_html" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.dashboard_storage.name
  storage_container_name = "$web" # The hidden folder Azure uses for websites
  type                   = "Block"
  content_type           = "text/html" # Tells the browser to render it as a webpage
  source                 = "index.html" # The file you just created
}