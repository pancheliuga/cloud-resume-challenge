variable "project" {
  type        = string
  default     = ""
  description = "The name of the project. This is use for resource naming and tagging."
}

variable "domain" {
  type        = string
  default     = null
  description = "The domain for the app."
  nullable    = true
}

variable "environment" {
  type        = string
  default     = "preview"
  description = "The type of environment where this project is deployed. This is use for resource tagging."
}

variable "alarm_email" {
  type        = string
  default     = null
  description = "The email address to send alarm notifications to."
  nullable    = true
}
