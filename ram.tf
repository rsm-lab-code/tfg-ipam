# Define locals for organization and clarity
locals {
  ipam_pools = {
    # Region 1 pools
    region1 = {
      arn = aws_vpc_ipam_pool.regional_pool_region1.arn
    }
    region1_prod = {
      arn = aws_vpc_ipam_pool.environment_pools_region1["prod"].arn
    }
    region1_nonprod = {
      arn = aws_vpc_ipam_pool.environment_pools_region1["nonprod"].arn
    }
    # Region 1 subnet pools - prod
    region1_prod_subnet1 = {
      arn = aws_vpc_ipam_pool.subnet_pools_region1["prod-subnet1"].arn
    }
    region1_prod_subnet2 = {
      arn = aws_vpc_ipam_pool.subnet_pools_region1["prod-subnet2"].arn
    }
    # Region 1 subnet pools - nonprod
    region1_nonprod_subnet1 = {
      arn = aws_vpc_ipam_pool.subnet_pools_region1["nonprod-subnet1"].arn
    }
    region1_nonprod_subnet2 = {
      arn = aws_vpc_ipam_pool.subnet_pools_region1["nonprod-subnet2"].arn
    }
    
    # Region 2 pools
    region2 = {
      arn = aws_vpc_ipam_pool.regional_pool_region2.arn
    }
    region2_prod = {
      arn = aws_vpc_ipam_pool.environment_pools_region2["prod"].arn
    }
    region2_nonprod = {
      arn = aws_vpc_ipam_pool.environment_pools_region2["nonprod"].arn
    }
    # Region 2 subnet pools - prod
    region2_prod_subnet1 = {
      arn = aws_vpc_ipam_pool.subnet_pools_region2["prod-subnet1"].arn
    }
    region2_prod_subnet2 = {
      arn = aws_vpc_ipam_pool.subnet_pools_region2["prod-subnet2"].arn
    }
    # Region 2 subnet pools - nonprod
    region2_nonprod_subnet1 = {
      arn = aws_vpc_ipam_pool.subnet_pools_region2["nonprod-subnet1"].arn
    }
    region2_nonprod_subnet2 = {
      arn = aws_vpc_ipam_pool.subnet_pools_region2["nonprod-subnet2"].arn
    }
  }
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
