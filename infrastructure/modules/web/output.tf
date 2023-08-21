output "web_url" {
  description = "The domain URL for Cloud Resume Challenge CloudFront distribution."

  value = var.domain == null || var.domain == "" ? "https://${aws_cloudfront_distribution.web.domain_name}/" : "https://${var.domain}/"
}
