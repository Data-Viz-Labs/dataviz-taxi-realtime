variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "porto-taxi"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-south-2"
}

variable "valid_groups" {
  description = "Comma-separated list of valid group names"
  type        = string
  default     = "group-alpha,group-beta,group-gamma"
}

variable "container_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 1024
}

variable "container_memory" {
  description = "Fargate task memory in MB"
  type        = number
  default     = 2048
}

variable "desired_count_normal" {
  description = "Number of normal Fargate tasks"
  type        = number
  default     = 1
}

variable "desired_count_spot" {
  description = "Number of Spot Fargate tasks"
  type        = number
  default     = 2
}
