variable "bucket_name" {
  description = "S3 bucket name for file-service uploads"
  type        = string
}

variable "force_destroy" {
  description = "Allow bucket to be destroyed even if non-empty"
  type        = bool
  default     = false
}

variable "versioning_status" {
  description = "Versioning status: Enabled or Suspended"
  type        = string
  default     = "Suspended"
  validation {
    condition     = contains(["Enabled", "Suspended"], var.versioning_status)
    error_message = "versioning_status must be Enabled or Suspended."
  }
}

variable "tags" {
  description = "Tags to apply to the bucket"
  type        = map(string)
  default     = {}
}
