terraform {
  backend "azurerm" {
    resource_group_name  = "bradwillz-infra"
    storage_account_name = "bradwillztstate"
    container_name       = "tstate"
    key                  = "terraform.tfstate"
  }
}

variable "storage_account_key" {
  description = "The access key for the Azure Storage Account"
  type        = string
  sensitive   = true
}