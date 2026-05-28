variable "env" {
  type    = string
  default = "dev"
}

variable "namespace" {
  type    = string
  default = "circleguard-dev"
}

variable "image_tag" {
  type    = string
  default = "dev"
}

variable "nodeport_base" {
  type    = number
  default = 31000
}

variable "replicas" {
  type    = number
  default = 1
}
