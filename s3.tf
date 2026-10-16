# S3_Bucket (tarea 21.1): origen de archivos estaticos de Frontend_Application.
#
# Los nombres de bucket S3 son unicos a nivel global de AWS, por lo que un
# nombre fijo (p. ej. "spooky-guestbook-frontend") colisionaria entre
# distintos despliegues (otros participantes del hackathon, otros entornos).
# Se agrega un sufijo aleatorio corto via random_id para evitar esa colision
# sin requerir que el usuario elija un nombre manualmente.
resource "random_id" "frontend_bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "spooky-guestbook-frontend-${random_id.frontend_bucket_suffix.hex}"
}

# Bloqueo total de acceso publico: S3_Bucket solo debe ser alcanzable a
# traves del Origin Access Control (OAC) de CloudFront_Distribution
# (Requisito 3.1).
resource "aws_s3_bucket_public_access_block" "frontend_bucket" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Politica de bucket: solo el servicio cloudfront.amazonaws.com, actuando en
# nombre de CloudFront_Distribution (condicion AWS:SourceArn = ARN exacto de
# la distribucion), puede leer objetos. Cualquier otro acceso directo a
# S3_Bucket (incluido el publico) queda denegado implicitamente (Requisito 3.1).
data "aws_iam_policy_document" "frontend_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend_bucket.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_bucket" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = data.aws_iam_policy_document.frontend_bucket_policy.json
}
