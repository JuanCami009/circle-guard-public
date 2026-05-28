terraform {
  required_version = ">= 1.6.0"
  required_providers {
    kind = {
      source  = "kreuzwerker/kind"
      version = "~> 0.6"
    }
  }
}
