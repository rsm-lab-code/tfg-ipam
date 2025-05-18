variable "aws_regions" {
  type        = list(string)
  description = "List of AWS regions for IPAM operation"
  default     = ["us-west-2", "us-east-1"]
}
variable "delegated_account_id" {
  description = "AWS Account ID for delegated account where IPAM is created"
  type        = string
}

variable "region_cidrs" {
  description = "CIDR blocks for each region"
  type        = map(string)
  default = {
    "us-west-2" = "10.0.0.0/16"
    "us-east-1" = "10.1.0.0/16"
  }
}

variable "environments" {
  description = "Configuration for different environments"
  type = map(object({
    cidr_suffix = string
    description = string
    subnets     = number
  }))
  default = {
    "prod" = {
      cidr_suffix = "0.0/17"
      description = "Production Environment"
      subnets     = 2
    }
    "nonprod" = {
      cidr_suffix = "128.0/17"
      description = "Non-Production Environment"
      subnets     = 2
    }
  }
}
variable "create_in_region" {
  description = "Only create resources in this region"
  type        = string
  default     = ""
}

variable "ipam_id" {
  description = "Existing IPAM ID to use"
  type        = string
  default     = ""
}

variable "private_scope_id" {
  description = "Existing private scope ID to use"
  type        = string
  default     = ""
}

variable "share_with_account_id" {
  description = "AWS Account ID to share IPAM resources with"
  type        = string
  default     = ""
}