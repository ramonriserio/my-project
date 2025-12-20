terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "=6.27.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}