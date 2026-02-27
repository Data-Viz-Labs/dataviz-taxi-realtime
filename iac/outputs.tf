output "api_key" {
  description = "Generated API key (sensitive)"
  value       = random_password.api_key.result
  sensitive   = true
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "s3_bucket_name" {
  description = "S3 bucket name for data"
  value       = aws_s3_bucket.data.id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.app.dns_name
}

output "api_url" {
  description = "API URL (ALB endpoint)"
  value       = "http://${aws_lb.app.dns_name}"
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "valid_groups" {
  description = "Valid group names"
  value       = var.valid_groups
}
