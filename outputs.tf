output "cloudfront_domain_name" {
  description = "Dominio publico de CloudFront_Distribution a traves del cual se accede a Frontend_Application."
  value       = aws_cloudfront_distribution.frontend_distribution.domain_name
}

# Agregados en la tarea 23.1: Frontend_Pipeline necesita el nombre del
# S3_Bucket (para `aws s3 sync`) y el id de CloudFront_Distribution (para
# `aws cloudfront create-invalidation`) sin tener que hardcodear ninguno de
# los dos en el workflow.
output "s3_bucket_name" {
  description = "Nombre de S3_Bucket, usado por Frontend_Pipeline para sincronizar los archivos estaticos (aws s3 sync)."
  value       = aws_s3_bucket.frontend_bucket.bucket
}

output "cloudfront_distribution_id" {
  description = "Id de CloudFront_Distribution, usado por Frontend_Pipeline para invalidar la cache (aws cloudfront create-invalidation)."
  value       = aws_cloudfront_distribution.frontend_distribution.id
}
