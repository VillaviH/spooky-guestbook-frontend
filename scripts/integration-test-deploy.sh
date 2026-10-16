#!/usr/bin/env bash
#
# integration-test-deploy.sh
#
# Prueba de INTEGRACIÓN real (tarea 27.2) para el Requisito 7.4:
#
#   "WHEN un Hackathon_Participant ejecuta el comando de despliegue
#   documentado en Frontend_Repository, THE Infrastructure_as_Code SHALL
#   aprovisionar todos los recursos de Frontend_Application en una sola
#   ejecución y SHALL emitir una confirmación observable (por ejemplo,
#   mensaje o código de finalización) que indique que el aprovisionamiento
#   se completó exitosamente."
#
# NATURALEZA DE ESTA PRUEBA (léase antes de ejecutarla):
#
# A diferencia de scripts/validate-terraform.sh (tarea 22.1, estático, sin
# backend remoto, sin credenciales de AWS) y de
# scripts/smoke-test-pipeline-trigger.sh (tarea 23.2, verificación
# estructural del YAML), este script SÍ aprovisiona infraestructura real en
# una cuenta de AWS: ejecuta `terraform apply` contra S3_Bucket y
# CloudFront_Distribution, sincroniza public/ al bucket real, e invalida la
# cache de CloudFront real. Replica exactamente el flujo del job `deploy` de
# .github/workflows/deploy.yml (tarea 23.1) para poder ejercitarlo de forma
# ejecutable localmente, sin depender de un push a GitHub.
#
# REQUISITOS PARA EJECUTAR ESTE SCRIPT:
#   - Terraform CLI instalado (misma versión que usa el pipeline: 1.5.0+).
#   - Credenciales de AWS válidas disponibles en el entorno (variables de
#     entorno AWS_*, perfil de ~/.aws/credentials, o rol asumido), con
#     permisos suficientes para crear/leer/modificar S3_Bucket y
#     CloudFront_Distribution.
#   - AWS CLI instalado (se usa para `aws s3 sync` y
#     `aws cloudfront create-invalidation`).
#
# ESTE SCRIPT NO FORMA PARTE DE:
#   - `npm test` (ver package.json): no se ejecuta en el checkpoint
#     automático de pruebas unitarias/de propiedad.
#   - Los puntos de control automáticos del plan de implementación (tareas
#     7, 14, 18, 25, 28): esos puntos de control validan pruebas unitarias y
#     de propiedad que corren sin credenciales de AWS; esta prueba de
#     integración se ejecuta manualmente y bajo demanda, cuando un
#     Hackathon_Participant decide desplegar Frontend_Application de verdad.
#
# NO se ejecuta en el entorno de este agente (no hay credenciales de AWS
# reales disponibles aquí): este script se entrega escrito y verificado
# sintácticamente (`bash -n`), listo para que un Hackathon_Participant lo
# ejecute contra su propia cuenta de AWS.
#
# Uso:
#   ./scripts/integration-test-deploy.sh
#
# Limpieza opcional tras la prueba (deshabilitada por defecto, igual patrón
# que la tarea 27.1 en Backend_Repository):
#   CLEANUP_AFTER_TEST=true ./scripts/integration-test-deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# URL base de Backend_API usada únicamente para esta prueba de integración.
# No apunta a ningún Backend_API real: variables.tf define esta variable
# con default "" (string vacío) precisamente para no exigir un Backend_API
# ya desplegado al provisionar Frontend_Application de forma aislada.
INTEGRATION_TEST_BACKEND_API_BASE_URL="${INTEGRATION_TEST_BACKEND_API_BASE_URL:-https://integration-test-backend.example.com}"

fail() {
  echo "FALLO: $1" >&2
  exit 1
}

cd "${TF_DIR}"

echo "==> [1/7] Verificando precondiciones"

if ! command -v terraform >/dev/null 2>&1; then
  fail "Terraform CLI no está disponible en PATH. Instálalo antes de ejecutar esta prueba de integración (https://developer.hashicorp.com/terraform/install)."
fi
echo "    OK: Terraform CLI disponible ($(terraform version | head -n1))"

if ! command -v aws >/dev/null 2>&1; then
  fail "AWS CLI no está disponible en PATH. Instálalo antes de ejecutar esta prueba de integración."
fi
echo "    OK: AWS CLI disponible"

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  fail "No se pudieron validar credenciales de AWS ('aws sts get-caller-identity' falló). Configura credenciales válidas (variables de entorno AWS_*, perfil de ~/.aws/credentials, o rol asumido) antes de ejecutar esta prueba de integración."
fi
echo "    OK: credenciales de AWS válidas ($(aws sts get-caller-identity --query 'Arn' --output text))"

echo "==> [2/7] terraform init"
terraform init -input=false

echo "==> [3/7] terraform apply (aprovisiona S3_Bucket + CloudFront_Distribution en una sola ejecución)"
# backend_api_base_url: variable documentada en variables.tf (default "").
# Se pasa explícitamente aquí para dejar constancia, dentro de esta prueba
# de integración, de que Frontend_Application puede aprovisionarse de forma
# aislada apuntando a cualquier Backend_API (real o de prueba).
if ! terraform apply -auto-approve -input=false \
  -var="backend_api_base_url=${INTEGRATION_TEST_BACKEND_API_BASE_URL}"; then
  fail "terraform apply falló. Revisa la salida de Terraform arriba para identificar el recurso que falló. Los recursos ya aprovisionados exitosamente permanecen en el state (no se destruyen automáticamente)."
fi
echo "    OK: terraform apply completado exitosamente (confirmación observable de aprovisionamiento, Requisito 7.4)"

echo "==> [4/7] Obteniendo outputs de Terraform (s3_bucket_name, cloudfront_distribution_id, cloudfront_domain_name)"
S3_BUCKET_NAME="$(terraform output -raw s3_bucket_name)"
CLOUDFRONT_DISTRIBUTION_ID="$(terraform output -raw cloudfront_distribution_id)"
CLOUDFRONT_DOMAIN_NAME="$(terraform output -raw cloudfront_domain_name)"
[ -n "${S3_BUCKET_NAME}" ] || fail "El output 's3_bucket_name' de Terraform está vacío"
[ -n "${CLOUDFRONT_DISTRIBUTION_ID}" ] || fail "El output 'cloudfront_distribution_id' de Terraform está vacío"
[ -n "${CLOUDFRONT_DOMAIN_NAME}" ] || fail "El output 'cloudfront_domain_name' de Terraform está vacío"
echo "    OK: s3_bucket_name=${S3_BUCKET_NAME}"
echo "    OK: cloudfront_distribution_id=${CLOUDFRONT_DISTRIBUTION_ID}"
echo "    OK: cloudfront_domain_name=${CLOUDFRONT_DOMAIN_NAME}"

echo "==> [5/7] Sync de public/ a S3_Bucket (mismo paso que el job 'deploy' de deploy.yml)"
if ! aws s3 sync public/ "s3://${S3_BUCKET_NAME}" --delete; then
  fail "'aws s3 sync' falló. El bucket real ya fue aprovisionado por Terraform, pero el contenido estático no quedó sincronizado."
fi
echo "    OK: public/ sincronizado con s3://${S3_BUCKET_NAME}"

echo "==> [6/7] Invalidación de CloudFront (mismo paso que el job 'deploy' de deploy.yml)"
if ! aws cloudfront create-invalidation \
  --distribution-id "${CLOUDFRONT_DISTRIBUTION_ID}" \
  --paths "/*" >/dev/null; then
  fail "'aws cloudfront create-invalidation' falló."
fi
echo "    OK: invalidación de cache solicitada para la distribución ${CLOUDFRONT_DISTRIBUTION_ID}"

echo "==> [7/7] Confirmación de éxito (Requisito 7.4)"
echo ""
echo "==> ÉXITO: Frontend_Application desplegado y accesible en:"
echo "    https://${CLOUDFRONT_DOMAIN_NAME}"
echo ""

if [ "${CLEANUP_AFTER_TEST:-false}" = "true" ]; then
  echo "==> CLEANUP_AFTER_TEST=true: destruyendo los recursos aprovisionados por esta prueba de integración"
  terraform destroy -auto-approve -input=false \
    -var="backend_api_base_url=${INTEGRATION_TEST_BACKEND_API_BASE_URL}"
  echo "    OK: recursos destruidos"
else
  echo "==> CLEANUP_AFTER_TEST no está en 'true': los recursos aprovisionados (S3_Bucket, CloudFront_Distribution)"
  echo "    permanecen desplegados. Ejecuta con CLEANUP_AFTER_TEST=true para destruirlos automáticamente,"
  echo "    o usa 'terraform destroy' manualmente desde ${TF_DIR}."
fi
