provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# Prepare the build for S3 upload.
# This is need to specify the content-type for each object.
# See https://stackoverflow.com/a/46921393/6811810
module "web_build" {
  source   = "hashicorp/dir/template"
  base_dir = "${path.module}/../../../web/build"
}

# Setup the S3 bucket. Set it to static web hosting.
resource "aws_s3_bucket" "web" {
  bucket = "${var.project}-web"

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_s3_bucket_website_configuration" "web" {
  bucket = aws_s3_bucket.web.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "web" {
  bucket = aws_s3_bucket.web.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.web.id

  policy = templatefile("${path.module}/templates/s3-public-policy.json", { bucket = aws_s3_bucket.web.id })

  depends_on = [aws_s3_bucket_public_access_block.web]
}

resource "aws_s3_object" "web" {
  bucket = aws_s3_bucket.web.id

  for_each = module.web_build.files

  key = each.key

  # The template_files module guarantees that only one of these two attributes
  # will be set for each file, depending on whether it is an in-memory template
  # rendering result or a static file on disk.
  source       = each.value.source_path
  content      = each.value.content
  content_type = each.value.content_type

  # Unless the bucket has encryption enabled, the ETag of each object is an
  # MD5 hash of that object.
  etag = each.value.digests.md5
}

# Setup the CloudFront distribution.
resource "aws_cloudfront_distribution" "web" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.web.website_endpoint
    origin_id   = aws_s3_bucket_website_configuration.web.website_endpoint
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  enabled     = true
  price_class = "PriceClass_100"
  aliases = var.domain == null || var.domain == "" ? null : [var.domain]

  default_cache_behavior {
    # Using the CachingOptimized managed policy ID
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = aws_s3_bucket_website_configuration.web.website_endpoint

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # Set to true if not using a custom domain
    cloudfront_default_certificate = var.domain == null || var.domain == "" ? true : false
    
    # Set a certificate if using a custom domain
    acm_certificate_arn            = var.domain == null || var.domain == "" ? null : aws_acm_certificate.web[0].arn
    minimum_protocol_version       = var.domain == null || var.domain == "" ? null : "TLSv1.2_2021"
    ssl_support_method             = var.domain == null || var.domain == "" ? null : "sni-only"
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_acm_certificate" "web" {
  count = var.domain == null || var.domain == "" ? 0 : 1

  provider = aws.us-east-1

  domain_name       = var.domain
  validation_method = "DNS"

  tags = {
    Project     = var.project
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}
