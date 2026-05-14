# 1. Create the BigQuery Dataset (The "Folder")
resource "google_bigquery_dataset" "ev_telemetry_dataset" {
  dataset_id                  = "ev_fleet_analytics"
  friendly_name               = "EV Fleet Telemetry"
  description                 = "Dataset for storing EV battery and location telemetry"
  location                    = "australia-southeast1" # Keeps data in Sydney close to your AWS resources
  
  # Automatically delete data older than 365 days to save money
  default_table_expiration_ms = 31536000000 
}

# 2. Create the BigQuery Table (The "Spreadsheet")
resource "google_bigquery_table" "battery_health_table" {
  dataset_id = google_bigquery_dataset.ev_telemetry_dataset.dataset_id
  table_id   = "battery_health"

  # This JSON defines the exact columns for your EV data
  schema = <<EOF
[
  {
    "name": "vehicle_id",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Unique ID of the EV (e.g., EV-1042)"
  },
  {
    "name": "timestamp",
    "type": "TIMESTAMP",
    "mode": "REQUIRED",
    "description": "Exact time the reading was taken"
  },
  {
    "name": "battery_percentage",
    "type": "INTEGER",
    "mode": "NULLABLE",
    "description": "Current battery level (0-100)"
  },
  {
    "name": "battery_temperature_c",
    "type": "FLOAT",
    "mode": "NULLABLE",
    "description": "Battery core temperature in Celsius"
  },
  {
    "name": "is_charging",
    "type": "BOOLEAN",
    "mode": "NULLABLE",
    "description": "Is the vehicle currently plugged in?"
  }
]
EOF
}