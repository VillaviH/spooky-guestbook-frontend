#!/usr/bin/env bash
#
# integration-test-spa-routing.sh
#
# Prueba de INTEGRACIÓN real (tarea 27.5) para el Requisito 3.5:
#
#   "WHEN un visitante solicita una ruta que no corresponde a un objeto
#   real en S3_Bucket (por ejemplo, una ruta de enrutamiento del lado del
#   cliente de la SPA), THE CloudFront_Distribution SHALL servir
#   index.html con código de estado 200, mediante una Custom Error
#   Response que traduce los códigos 403/404 originados en S3_Bucket."
#
# NATURALEZA DE ESTA PRUEBA (léase antes de ejecutarla):
#
# A diferencia de scripts/validate-terraform.sh (tarea 22.1, estático, sin
# backend remoto, sin credenciales de AWS), este script requiere que
# Frontend_Application ya esté desplegada en una cuenta de AWS real (por
# ejemplo mediante scripts/integration-test-deploy.sh, tarea 27.2, o el job
# `deploy` de .github/workflows/deploy.yml). Este script NO ejecuta
# `terraform apply`: solo hace una solicitud HTTP real contra la
# CloudFront_Distribution ya existente para confirmar el comportamiento de
# enrutamiento de la SPA (Custom Error Response 403/404 -> /index.html,
# 200), definido en cloudfront.tf (tarea 21.1).
#
# REQUISITOS PARA EJECUTAR ESTE SCRIPT:
#   - Frontend_Application ya desplegada (S3_Bucket + CloudFront_Distribution
#     aprovisionados y con contenido sincronizado).
#   - curl instalado y disponible en PATH.
#   - Variable de entorno CLOUDFRONT_DOMAIN definida con el dominio real de
#     la CloudFront_Distribution desplegada. Se obtiene con:
#       terraform output -raw cloudfront_domain_name
#
# ESTE SCRIPT NO FORMA PARTE DE:
#   - `npm test` (ver package.json): no se ejecuta en el checkpoint
#     automático de pruebas unitarias/de propiedad.
#   - Los puntos de control automáticos del plan de implementación (tareas
#     7, 14, 18, 25, 28): esos puntos de control validan pruebas unitarias y
#     de propiedad que corren sin credenciales de AWS ni infraestructura
#     real desplegada; esta prueba de integración se ejecuta manualmente y
#     bajo demanda, contra una CloudFront_Distribution real.
#
# NO se ejecuta en el entorno de este agente (no hay Frontend_Application
# real desplegada ni acceso de red a AWS/CloudFront disponibles aquí): este
# script se entrega escrito y verificado sintácticamente (`bash -n`), listo
# para que un Hackathon_Participant lo ejecute contra su propio despliegue.
#
# Uso:
#   export CLOUDFRONT_DOMAIN="$(terraform output -raw cloudfront_domain_name)"
#   ./scripts/integration-test-spa-routing.sh

set -euo pipefail

RESPONSE_BODY_FILE="/tmp/spa-routing-response.html"

# String reconocible del index.html real de Frontend_Application
# (public/index.html, tarea 20.1). Si el título cambia, actualiza este
# valor para que siga coincidiendo exactamente.
EXPECTED_TITLE_SNIPPET="<title>Spooky Guestbook</title>"

fail() {
  echo "FALLO: $1" >&2
  exit 1
}

echo "==> [1/4] Verificando precondiciones"

if [ -z "${CLOUDFRONT_DOMAIN:-}" ]; then
  fail "La variable de entorno CLOUDFRONT_DOMAIN no está definida. Obténla con 'terraform output -raw cloudfront_domain_name' desde Frontend_Repository (requiere Frontend_Application ya desplegada) y exportala antes de ejecutar esta prueba de integración, por ejemplo: export CLOUDFRONT_DOMAIN=\"\$(terraform output -raw cloudfront_domain_name)\""
fi
echo "    OK: CLOUDFRONT_DOMAIN=${CLOUDFRONT_DOMAIN}"

if ! command -v curl >/dev/null 2>&1; then
  fail "curl no está disponible en PATH. Instálalo antes de ejecutar esta prueba de integración."
fi
echo "    OK: curl disponible"

# Ruta que casi seguro no existe como objeto real en S3_Bucket.
NONEXISTENT_PATH="esta-ruta-no-existe-${RANDOM}"
TARGET_URL="https://${CLOUDFRONT_DOMAIN}/${NONEXISTENT_PATH}"

echo "==> [2/4] Solicitando ruta inexistente de la SPA vía CloudFront: ${TARGET_URL}"
HTTP_STATUS="$(curl -o "${RESPONSE_BODY_FILE}" -w '%{http_code}' -s "${TARGET_URL}")"
echo "    Código de estado HTTP recibido: ${HTTP_STATUS}"

echo "==> [3/4] Verificando que el código de estado HTTP es 200 (Custom Error Response 403/404 -> index.html, Requisito 3.5)"
if [ "${HTTP_STATUS}" != "200" ]; then
  fail "Se esperaba el código de estado HTTP 200 (servido mediante la Custom Error Response de CloudFront_Distribution que traduce 403/404 a index.html), pero se recibió '${HTTP_STATUS}' al solicitar '${TARGET_URL}'."
fi
echo "    OK: código de estado HTTP 200"

echo "==> [4/4] Verificando que el cuerpo de la respuesta corresponde a index.html"
if ! grep -qF "${EXPECTED_TITLE_SNIPPET}" "${RESPONSE_BODY_FILE}"; then
  fail "El cuerpo de la respuesta (guardado en ${RESPONSE_BODY_FILE}) no contiene el contenido esperado de index.html ('${EXPECTED_TITLE_SNIPPET}'). CloudFront_Distribution puede no estar sirviendo index.html como se esperaba para rutas inexistentes."
fi
echo "    OK: el cuerpo de la respuesta contiene '${EXPECTED_TITLE_SNIPPET}'"

echo ""
echo "==> ÉXITO: la ruta inexistente '${NONEXISTENT_PATH}' fue servida con código 200 y contenido de index.html (Requisito 3.5)"
