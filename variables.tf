variable "aws_region" {
  type        = string
  description = "Region de AWS donde se desplegara la infraestructura de Frontend_Repository (S3_Bucket, CloudFront_Distribution)."
  default     = "us-east-1"
}

variable "backend_api_base_url" {
  type        = string
  description = <<-EOT
    URL base de Backend_API (API_Gateway) que consumira Frontend_Application.
    Equivalente al parametro BackendApiBaseUrl que existia en el template.yaml de SAM.
    Se documenta su configuracion en el README (tarea 24.1).
  EOT
  default     = ""
}
