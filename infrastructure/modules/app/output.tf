output "project" {
  description = "The project name."
  value       = var.project
}

output "url" {
  description = "The URL for Cloud Resume Challenge API Gateway."

  value = var.domain == null || var.domain == "" ? aws_apigatewayv2_stage.default.invoke_url : "https://${var.domain}/"
}