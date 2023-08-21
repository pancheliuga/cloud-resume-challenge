variable "project" {
  type = string
  default = ""
  description = "The name of the project. This is used for resource naming and tagging."
}

variable "domain" {
  type        = string
  default     = null
  description = "The domain for the web."
  nullable    = true
}

variable "environment" {
  type = string
  default = "development"
  description = "The type of environment where this Cloud Resume Challenge is deployed. This is used for resource tagging."
}