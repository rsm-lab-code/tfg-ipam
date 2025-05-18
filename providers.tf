# In modules/ipam/providers.tf
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [
        aws.delegated_account_us-west-2,
        aws.delegated_account_us-east-1
      ]
    }
  }
}
