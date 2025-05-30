# Define locals for organization and clarity
locals {
  ipam_pools = merge(
    # Regional pools
    {
      region1 = {
        arn = aws_vpc_ipam_pool.regional_pool_region1.arn
      }
      region2 = {
        arn = aws_vpc_ipam_pool.regional_pool_region2.arn
      }
    },
    # Environment pools
    {
      for k, v in local.environment_pools : k => {
        arn = v.arn
      }
    },
    # All subnet pools dynamically
    {
      for k, v in local.subnet_pools : k => {
        arn = v.arn
      }
    }
  )

}

# Share IPAM with the account
resource "aws_ram_resource_share" "ipam_share" {
  provider                  = aws.delegated_account_us-west-2
  name                      = "ipam-resource-share"
  allow_external_principals = true
  
  tags = {
    Name        = "ipam-resource-share"
    Environment = "shared"
    ManagedBy   = "terraform"
  }
}

# Associate all IPAM pools using for_each
resource "aws_ram_resource_association" "ipam_pool_associations" {
  for_each           = local.ipam_pools
  provider           = aws.delegated_account_us-west-2
  resource_arn       = each.value.arn
  resource_share_arn = aws_ram_resource_share.ipam_share.arn
}

# Share with the specified account
resource "aws_ram_principal_association" "ipam_account_principal" {
  provider           = aws.delegated_account_us-west-2
  principal          = var.share_with_account_id
  resource_share_arn = aws_ram_resource_share.ipam_share.arn
}
