terraform {
  backend "s3" {
    bucket = "crc-terraform-backend"
    key    = "tfstate"
    region = "eu-west-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.63.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = "~> 1.2"
}

provider "aws" {
  region = "eu-west-1"
}

resource "random_pet" "project" {
  length = 2
}

module "web" {
  source = "../modules/web"

  # Use a random name when the project variable is not set.
  project = coalesce(var.project, "crc-${random_pet.project.id}")
  domain = var.domain

  environment = var.environment
}
