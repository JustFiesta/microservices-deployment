#
# Global / common
#
variable "project_name" {
  type        = string
  description = "Name of the project resources are used for"
}

variable "tags" {
  type        = map(string)
  description = "Common AWS tags"
  default     = {}
}

#
# VPC
#
variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

#
# EKS – IAM roles
#
variable "cluster_role_name" {
  type        = string
  description = "IAM role name for EKS control plane"
}

variable "node_role_name" {
  type        = string
  description = "IAM role name for worker nodes"
}

#
# EKS cluster config
#
variable "public_endpoint" {
  type        = bool
  description = "Enable or disable public API endpoint"
  default     = false
}

variable "k8s_version" {
  type        = string
  description = "Kubernetes version for EKS cluster"
}

#
# VPC outputs passed into EKS module
#
variable "vpc_id" {
  type        = string
  description = "ID of the VPC created by vpc module"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets for node groups"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets"
}
