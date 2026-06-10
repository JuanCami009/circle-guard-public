terraform {
  required_version = ">= 1.6.0"
  backend "s3" {
    bucket                      = "circleguard-tfstate"
    key                         = "envs/stage/terraform.tfstate"
    region                      = "us-east-1"
    dynamodb_table              = "circleguard-tflock"
    endpoints = {
      s3       = "http://host.docker.internal:4566"
      dynamodb = "http://host.docker.internal:4566"
    }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
    access_key                  = "test"
    secret_key                  = "test"
  }
}
