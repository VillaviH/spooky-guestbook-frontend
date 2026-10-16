#!/usr/bin/env bash
#
# integration-test-s3-direct-access-forbidden.sh
#
# Prueba de INTEGRACIÓN real (tarea 27.6) para el Requisito 3.1:
#
#   "THE Infrastructure_as_Code SHALL configurar S3_Bucket para que el
#   acceso directo a sus objetos esté restringido, permitiendo únicamente
#   el acceso a través de CloudFront_Distribution mediante Origin Access
#   Control (OAC)."
#
# NATURALEZA DE ESTA PRUEBA (léase antes de ejecutarla):
#
# Igual que scripts/integration-test-deploy.sh (tarea 27.2), esta prueba
# NO es ejecutable en este entorno: requiere un S3_Bucket real, ya
# aprovisionado por Terraform (ver s3.tf), con su
# aws_s3_bucket_public_access_block y su aws_s3_bucket_policy aplicados.
# No hay forma de "simular" la respuesta de S3 ante una solicitud HTTP
# directa sin un bucket real desplegado en una cuenta de AWS: la garantía
# que se verifica aquí (403 Forbidden) depende de la política de bucket
# evaluada por el servicio S3 real, no de nada que pueda inferirse
# estáticamente del código Terraform.
#
# REQUISITOS PARA EJECUTAR ESTE SCRIPT:
#   - Frontend_Application ya desplegada (S3_Bucket y CloudFront_Distribution
#     aprovisionados, p. ej. vía scripts/integration-test-deploy.sh o
#     terraform apply manual).
#   - Variable de entorno S3_BUCKET_NAME definida con el nombre real del
#     bucket. Se obtiene así, desde este mismo directorio:
#       export S3_BUCKET_NAME="$(terraform output -raw s3_bucket_name)"
#   - curl disponible en PATH.
#
# ESTE SCRIPT NO FORMA PARTE DE:
#   - `npm test`: no se ejecuta en el checkpoint automático de pruebas
#     unitarias/de propiedad (no requiere credenciales de AWS para
#     *ejecutarse* sin fallar por falta de herramientas, pero sí requiere
#     infraestructura real desplegada, lo cual no está disponible en CI de
#     pruebas unitarias).
#
# SOBRE LA URL USADA (endpoint REST estándar vs. endpoint de sitio web):
#
# S3_Bucket (ver s3.tf) NO tiene habilitado static website hosting
# (no existe un recurso aws_s3_bucket_website_configuration en este
# proyecto). Por lo tanto NO se usa el endpoint de sitio web
# (http://<bucket>.s3-website-<region>.amazonaws.com), que de todos modos
# solo soporta HTTP y nunca HTTPS. Se usa en su lugar el endpoint REST
# estándar de S3 en formato "virtual-hosted-style":
#
#   https://<bucket>.s3.amazonaws.com/index.html
#
# Este formato (sin sufijo de región) es válido para S3 en la región
# us-east-1 (el default de var.aws_region en variables.tf) y es resuelto
# automáticamente por AWS hacia el endpoint regional correcto. Si
# Frontend_Repository se despliega en una región distinta de us-east-1, usa
# en su lugar el formato con región explícita:
#
#   https://<bucket>.s3.<region>.amazonaws.com/index.html
#
# Este script detecta la región a partir de la variable de entorno opcional
# AWS_REGION (o AWS_DEFAULT_REGION); si ninguna está definida, usa el
# formato sin región (us-east-1, el default del proyecto).
#
# Independientemente del formato de URL elegido, el resultado esperado es
# el mismo: aws_s3_bucket_public_access_block bloquea cualquier ACL o
# política pública, y aws_s3_bucket_policy (data.aws_iam_policy_document
# .frontend_bucket_policy) solo otorga s3:GetObject al principal de
# servicio cloudfront.amazonaws.com con la condición AWS:SourceArn igual al
# ARN exacto de CloudFront_Distribution. Una solicitud HTTP directa (sin
# pasar por CloudFront) no cumple esa condición, por lo que S3 responde
# 403 Forbidden.
#
# Uso:
#   export S3_BUCKET_NAME="$(terraform output -raw s3_bucket_name)"
#   ./scripts/integration-test-s3-direct-access-forbidden.sh

set -euo pipefail

fail() {
  echo "FALLO: $1" >&2
  exit 1
}

echo "==> [1/4] Verificando precondiciones"

if ! command -v curl >/dev/null 2>&1; then
  fail "curl no está disponible en PATH. Instálalo antes de ejecutar esta prueba de integración."
fi
echo "    OK: curl disponible"

if [ -z "${S3_BUCKET_NAME:-}" ]; then
  fail "La variable de entorno S3_BUCKET_NAME no está definida. Define el nombre real de S3_Bucket, por ejemplo: export S3_BUCKET_NAME=\"\$(terraform output -raw s3_bucket_name)\" (ejecutado desde el directorio raíz de Frontend_Repository, con Frontend_Application ya desplegada)."
fi
echo "    OK: S3_BUCKET_NAME=${S3_BUCKET_NAME}"

echo "==> [2/4] Construyendo la URL de acceso directo (endpoint REST estándar, no endpoint de sitio web)"
AWS_REGION_FOR_TEST="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
if [ -n "${AWS_REGION_FOR_TEST}" ] && [ "${AWS_REGION_FOR_TEST}" != "us-east-1" ]; then
  S3_DIRECT_URL="https://${S3_BUCKET_NAME}.s3.${AWS_REGION_FOR_TEST}.amazonaws.com/index.html"
else
  S3_DIRECT_URL="https://${S3_BUCKET_NAME}.s3.amazonaws.com/index.html"
fi
echo "    OK: URL de acceso directo = ${S3_DIRECT_URL}"

echo "==> [3/4] Solicitud HTTP directa a S3_Bucket (sin pasar por CloudFront_Distribution)"
HTTP_STATUS="$(curl -s -o /dev/null -w '%{http_code}' "${S3_DIRECT_URL}")"
echo "    Código de estado HTTP recibido: ${HTTP_STATUS}"

echo "==> [4/4] Verificando que el acceso directo fue denegado (403 Forbidden, Requisito 3.1)"
if [ "${HTTP_STATUS}" != "403" ]; then
  if [ "${HTTP_STATUS}" = "200" ]; then
    fail "El acceso directo a S3_Bucket devolvió 200 (en lugar de 403). Esto indica una REGRESIÓN DE SEGURIDAD GRAVE: el bucket quedó accesible públicamente, violando el Requisito 3.1 (el acceso directo a S3_Bucket debe estar restringido, solo accesible vía CloudFront_Distribution con OAC). Revisa aws_s3_bucket_public_access_block y aws_s3_bucket_policy en s3.tf."
  fi
  fail "El acceso directo a S3_Bucket devolvió ${HTTP_STATUS} en lugar del 403 esperado. Revisa aws_s3_bucket_public_access_block y aws_s3_bucket_policy en s3.tf, y confirma que AWS:SourceArn coincide con el ARN real de CloudFront_Distribution."
fi

echo ""
echo "==> ÉXITO: el acceso directo a S3_Bucket (${S3_DIRECT_URL}) respondió 403 Forbidden."
echo "    S3_Bucket solo es accesible a través de CloudFront_Distribution mediante OAC (Requisito 3.1)."
