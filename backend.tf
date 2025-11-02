terraform {

  backend "azurerm" {
    resource_group_name  = "rg-kolad-sch"
    subscription_id      = "18a54fef-d36d-4d1c-b7b4-c468a773149b"
    storage_account_name = "sttfwsslabsec001"
    container_name       = "tfstate"
    key                  = "loadbalancer.prod.tfstate"
    use_oidc             = true
  }
}