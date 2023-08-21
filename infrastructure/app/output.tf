output "app_url" {
  description = "The URL for Cloud Resume Challenge API Gateway."

  value = module.app.url
}

output "project" {
  description = "The project name."

  value = module.app.project
}
