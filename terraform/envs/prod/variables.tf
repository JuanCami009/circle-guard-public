variable "env" {
  type    = string
  default = "prod"
}

variable "namespace" {
  type    = string
  default = "circleguard"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "nodeport_base" {
  type    = number
  default = 30000
}

variable "replicas" {
  type    = number
  default = 1
}
