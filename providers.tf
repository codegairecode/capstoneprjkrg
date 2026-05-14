terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
  profile = "default"
}

provider "google" {
  project = "project-84688eb1-71c1-4536-858"
  region  = "australia-southeast1"
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
  subscription_id = "2b1972a1-5bf2-4917-9409-3011e3d26eb6" # Replace with your Sub ID
}

provider "azuread" {
  # Authenticates using your 'az login' session
}