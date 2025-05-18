# --------------------------
# Create a single AWS IPAM - (us-west-2)
# --------------------------
resource "aws_vpc_ipam" "main_ipam" {
  provider    = aws.delegated_account_us-west-2
  description = "Global IPAM for managing CIDR blocks"

  dynamic "operating_regions" {
    for_each = toset(var.aws_regions)
    content {
      region_name = operating_regions.value
    }
  }
}

# --------------------------
# Create Top-Level IPAM Scope - (us-west-2)
# --------------------------
resource "aws_vpc_ipam_scope" "private_scope" {
  provider    = aws.delegated_account_us-west-2
  ipam_id     = aws_vpc_ipam.main_ipam.id
  description = "Private IPAM Scope"
}

# --------------------------
# Create Top-Level IPAM Pools for each Region - all managed from us-west-2
# --------------------------
# Region 1 pool (us-west-2)
resource "aws_vpc_ipam_pool" "regional_pool_region1" {
  provider       = aws.delegated_account_us-west-2
  ipam_scope_id  = aws_vpc_ipam_scope.private_scope.id
  locale         = var.aws_regions[0]
  address_family = "ipv4"
  description    = "Top-Level ${var.aws_regions[0]} /16 Pool"
}

# Region 2 pool (us-east-1) - still managed from us-west-2 but with locale of region2
resource "aws_vpc_ipam_pool" "regional_pool_region2" {
  provider       = aws.delegated_account_us-west-2
  ipam_scope_id  = aws_vpc_ipam_scope.private_scope.id
  locale         = var.aws_regions[1]
  address_family = "ipv4"
  description    = "Top-Level ${var.aws_regions[1]} /16 Pool"
}

# Create a map to reference the regional pools by region name
locals {
  regional_pools = {
    "${var.aws_regions[0]}" = aws_vpc_ipam_pool.regional_pool_region1
    "${var.aws_regions[1]}" = aws_vpc_ipam_pool.regional_pool_region2
  }
}

# Region 1 pool CIDR
resource "aws_vpc_ipam_pool_cidr" "regional_cidr_region1" {
  provider     = aws.delegated_account_us-west-2
  ipam_pool_id = aws_vpc_ipam_pool.regional_pool_region1.id
  cidr         = var.region_cidrs[var.aws_regions[0]]
}

# Region 2 pool CIDR
resource "aws_vpc_ipam_pool_cidr" "regional_cidr_region2" {
  provider     = aws.delegated_account_us-west-2
  ipam_pool_id = aws_vpc_ipam_pool.regional_pool_region2.id
  cidr         = var.region_cidrs[var.aws_regions[1]]
}

# --------------------------
# Create Environment Pools (Prod/Non-Prod) for each Region
# --------------------------
# Region 1 (us-west-2) environment pools
resource "aws_vpc_ipam_pool" "environment_pools_region1" {
  for_each = var.environments
  
  provider           = aws.delegated_account_us-west-2
  ipam_scope_id       = aws_vpc_ipam_scope.private_scope.id
  locale              = var.aws_regions[0]
  address_family      = "ipv4"
  description         = "${var.aws_regions[0]} ${each.value.description} Pool"
  source_ipam_pool_id = aws_vpc_ipam_pool.regional_pool_region1.id
}

# Region 2 (us-east-1) environment pools
resource "aws_vpc_ipam_pool" "environment_pools_region2" {
  for_each = var.environments
  
  provider           = aws.delegated_account_us-west-2
  ipam_scope_id       = aws_vpc_ipam_scope.private_scope.id
  locale              = var.aws_regions[1]
  address_family      = "ipv4"
  description         = "${var.aws_regions[1]} ${each.value.description} Pool"
  source_ipam_pool_id = aws_vpc_ipam_pool.regional_pool_region2.id
}

# Create map to reference environment pools by region and environment
locals {
  environment_pools = merge(
    { for env_name, env in var.environments : 
      "${var.aws_regions[0]}-${env_name}" => aws_vpc_ipam_pool.environment_pools_region1[env_name]
    },
    { for env_name, env in var.environments : 
      "${var.aws_regions[1]}-${env_name}" => aws_vpc_ipam_pool.environment_pools_region2[env_name]
    }
  )
}

# Region 1 (us-west-2) environment pool CIDRs
resource "aws_vpc_ipam_pool_cidr" "environment_cidrs_region1" {
  for_each = var.environments
  
  provider     = aws.delegated_account_us-west-2
  ipam_pool_id = aws_vpc_ipam_pool.environment_pools_region1[each.key].id
  cidr         = replace(var.region_cidrs[var.aws_regions[0]], "0.0/16", each.value.cidr_suffix)
  depends_on   = [aws_vpc_ipam_pool_cidr.regional_cidr_region1]
}

# Region 2 (us-east-1) environment pool CIDRs
resource "aws_vpc_ipam_pool_cidr" "environment_cidrs_region2" {
  for_each = var.environments
  
  provider     = aws.delegated_account_us-west-2
  ipam_pool_id = aws_vpc_ipam_pool.environment_pools_region2[each.key].id
  cidr         = replace(var.region_cidrs[var.aws_regions[1]], "0.0/16", each.value.cidr_suffix)
  depends_on   = [aws_vpc_ipam_pool_cidr.regional_cidr_region2]
}

# --------------------------
# Create Subnet Pools for each Environment in each Region
# --------------------------
# Region 1 (us-west-2) subnet pools
resource "aws_vpc_ipam_pool" "subnet_pools_region1" {
  for_each = {
    for pair in flatten([
      for env_name, env in var.environments : [
        for subnet_num in range(1, env.subnets + 1) : {
          key     = "${env_name}-subnet${subnet_num}"
          env     = env_name
          env_obj = env
          num     = subnet_num
        }
      ]
    ]) : pair.key => pair
  }
  
  provider           = aws.delegated_account_us-west-2
  ipam_scope_id       = aws_vpc_ipam_scope.private_scope.id
  locale              = var.aws_regions[0]
  address_family      = "ipv4"
  description         = "${var.aws_regions[0]} ${var.environments[each.value.env].description} Subnet ${each.value.num}"
  source_ipam_pool_id = aws_vpc_ipam_pool.environment_pools_region1[each.value.env].id
}

# Region 2 (us-east-1) subnet pools
resource "aws_vpc_ipam_pool" "subnet_pools_region2" {
  for_each = {
    for pair in flatten([
      for env_name, env in var.environments : [
        for subnet_num in range(1, env.subnets + 1) : {
          key     = "${env_name}-subnet${subnet_num}"
          env     = env_name
          env_obj = env
          num     = subnet_num
        }
      ]
    ]) : pair.key => pair
  }
  
  provider           = aws.delegated_account_us-west-2
  ipam_scope_id       = aws_vpc_ipam_scope.private_scope.id
  locale              = var.aws_regions[1]
  address_family      = "ipv4"
  description         = "${var.aws_regions[1]} ${var.environments[each.value.env].description} Subnet ${each.value.num}"
  source_ipam_pool_id = aws_vpc_ipam_pool.environment_pools_region2[each.value.env].id
}

# Create map to reference subnet pools by region, environment, and subnet number
locals {
  subnet_pools = merge(
    { for pair in flatten([
        for env_name, env in var.environments : [
          for subnet_num in range(1, env.subnets + 1) : {
            key = "${var.aws_regions[0]}-${env_name}-subnet${subnet_num}"
            env_key = "${env_name}-subnet${subnet_num}"
          }
        ]
      ]) : pair.key => aws_vpc_ipam_pool.subnet_pools_region1[pair.env_key]
    },
    { for pair in flatten([
        for env_name, env in var.environments : [
          for subnet_num in range(1, env.subnets + 1) : {
            key = "${var.aws_regions[1]}-${env_name}-subnet${subnet_num}"
            env_key = "${env_name}-subnet${subnet_num}"
          }
        ]
      ]) : pair.key => aws_vpc_ipam_pool.subnet_pools_region2[pair.env_key]
    }
  )
}

# Region 1 (us-west-2) subnet pool CIDRs
resource "aws_vpc_ipam_pool_cidr" "subnet_cidrs_region1" {
  for_each = {
    for pair in flatten([
      for env_name, env in var.environments : [
        for subnet_num in range(1, env.subnets + 1) : {
          key     = "${env_name}-subnet${subnet_num}"
          env     = env_name
          num     = subnet_num
        }
      ]
    ]) : pair.key => pair
  }
  
  provider       = aws.delegated_account_us-west-2
  ipam_pool_id   = aws_vpc_ipam_pool.subnet_pools_region1[each.key].id
  netmask_length = 21
  depends_on     = [aws_vpc_ipam_pool_cidr.environment_cidrs_region1]
}

# Region 2 (us-east-1) subnet pool CIDRs
resource "aws_vpc_ipam_pool_cidr" "subnet_cidrs_region2" {
  for_each = {
    for pair in flatten([
      for env_name, env in var.environments : [
        for subnet_num in range(1, env.subnets + 1) : {
          key     = "${env_name}-subnet${subnet_num}"
          env     = env_name
          num     = subnet_num
        }
      ]
    ]) : pair.key => pair
  }
  
  provider       = aws.delegated_account_us-west-2
  ipam_pool_id   = aws_vpc_ipam_pool.subnet_pools_region2[each.key].id
  netmask_length = 21
  depends_on     = [aws_vpc_ipam_pool_cidr.environment_cidrs_region2]
}