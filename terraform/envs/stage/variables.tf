variable "env" {
  type    = string
  default = "stage"
}

variable "namespace" {
  type    = string
  default = "circleguard-stage"
}

variable "image_tag" {
  type    = string
  default = "stage"
}

variable "nodeport_base" {
  type    = number
  default = 32000
}

variable "replicas" {
  type    = number
  default = 1
}
