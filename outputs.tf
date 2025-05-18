output "ipam_id" {
  description = "ID of the created IPAM"
  value       = aws_vpc_ipam.main_ipam.id
}

output "private_scope_id" {
  description = "ID of the private IPAM scope"
  value       = aws_vpc_ipam_scope.private_scope.id
}

output "regional_pool_ids" {
  description = "IDs of regional pools"
  value       = {
    "${var.aws_regions[0]}" = aws_vpc_ipam_pool.regional_pool_region1.id
    "${var.aws_regions[1]}" = aws_vpc_ipam_pool.regional_pool_region2.id
  }
}

output "environment_pool_ids" {
  description = "IDs of environment pools"
  value       = {
    for k, v in local.environment_pools : k => v.id
  }
}

output "subnet_pool_ids" {
  description = "IDs of subnet pools"
  value       = {
    for k, v in local.subnet_pools : k => v.id
  }
}