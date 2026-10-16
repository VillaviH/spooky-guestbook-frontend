# CloudFront_Distribution (tarea 21.1): distribuye Frontend_Application,
# sirviendo desde S3_Bucket via Origin Access Control (OAC, no el OAI legacy)
# (Requisitos 3.1, 3.2, 3.3, 3.4).
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "spooky-guestbook-frontend-oac"
  description                       = "OAC para que CloudFront_Distribution acceda a S3_Bucket de Frontend_Application."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "Spooky Guestbook - Frontend_Application"

  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id                = "S3_Bucket-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3_Bucket-frontend"
    viewer_protocol_policy = "redirect-to-https" # fuerza HTTPS (Requisito 3.6/8.1)

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # Enrutamiento interno de la SPA (Requisito 3.5): cualquier ruta que no
  # exista como objeto en S3_Bucket devuelve 403 o 404 (segun la politica de
  # bucket); en ambos casos se sirve /index.html con codigo 200 para que el
  # router del lado del cliente resuelva la ruta.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Certificado default de CloudFront (*.cloudfront.net): suficiente para el
  # alcance de un hackathon de 3 dias, evita el aprovisionamiento de un
  # certificado ACM y dominio propio fuera del scope de este proyecto.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
