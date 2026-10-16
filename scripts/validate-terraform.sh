#!/usr/bin/env bash
#
# validate-terraform.sh
#
# Paso de validación estática de Infrastructure_as_Code para Frontend_Repository.
#
# Corresponde a:
#   - Requisito 7.4: emitir una confirmación observable de que la configuración
#     de Terraform es sintácticamente válida y está lista para aprovisionar
#     Frontend_Application (S3_Bucket, CloudFront_Distribution).
#   - Requisito 7.6: detectar errores de forma temprana (antes de `terraform apply`)
#     para que el proceso de aprovisionamiento se detenga ante un error, en vez
#     de aplicar cambios parciales.
#
# Ejecutable localmente:
#   ./scripts/validate-terraform.sh
#
# Y reutilizable desde Frontend_Pipeline (ver tarea 23.1), que invocará este
# mismo script como etapa previa a `terraform apply`.
#
# No requiere credenciales de AWS: `terraform init -backend=false` evita
# configurar el backend remoto y `terraform validate` no se conecta a AWS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${TF_DIR}"

cleanup() {
  echo "==> Limpiando directorio .terraform/ (artefacto local, no versionado)"
  rm -rf "${TF_DIR}/.terraform"
}
trap cleanup EXIT

echo "==> [1/3] Verificando formato de Terraform (terraform fmt -check -recursive)"
terraform fmt -check -recursive .

echo "==> [2/3] Inicializando Terraform sin backend remoto (terraform init -backend=false)"
terraform init -backend=false -input=false

echo "==> [3/3] Validando configuración de Terraform (terraform validate)"
terraform validate

echo "==> Validación de Terraform de Frontend_Repository completada exitosamente."
