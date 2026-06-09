terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5"
    }
    kind = {
      source  = "kreuzwerker/kind"
      version = "~> 0.6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
  endpoints {
    s3             = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}

provider "kind" {}

provider "kubernetes" {
  host                   = module.cluster.endpoint
  client_certificate     = base64decode(module.cluster.client_certificate)
  client_key             = base64decode(module.cluster.client_key)
  cluster_ca_certificate = base64decode(module.cluster.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.endpoint
    client_certificate     = base64decode(module.cluster.client_certificate)
    client_key             = base64decode(module.cluster.client_key)
    cluster_ca_certificate = base64decode(module.cluster.cluster_ca_certificate)
  }
}
