#!/usr/bin/env bash
#
# smoke-test-pipeline-trigger.sh
#
# Prueba de humo (tarea 23.2) para el Requisito 1.6:
#
#   "WHEN se publica un cambio (push o fusión de un merge request) en la
#   rama principal de Frontend_Repository, THE Frontend_Pipeline SHALL
#   iniciarse automáticamente y construir Frontend_Application sin requerir
#   ningún cambio en Backend_Repository."
#
# NATURALEZA DE ESTA PRUEBA (léase antes de modificarla):
#
# Esta es una verificación ESTRUCTURAL/ESTÁTICA ejecutable localmente, NO un
# smoke test de extremo a extremo contra GitHub real. No existe forma de
# ejercitar "un push real a Backend_Repository" desde este entorno local sin
# un repositorio remoto en GitHub, y aunque existiera, el resultado esperado
# (que NO dispare Frontend_Pipeline) es indistinguible de "no pasó nada" — no
# es una señal observable sin esperar un timeout arbitrario.
#
# La garantía real de que "un push a Backend_Repository nunca activa
# Frontend_Pipeline" no depende de ninguna condición escrita en el YAML: es
# una propiedad estructural del modelo de eventos de GitHub Actions. Cada
# workflow vive dentro de un repositorio Git y su trigger `on.push` solo
# observa referencias (branches) de ESE MISMO repositorio. GitHub Actions no
# ofrece ningún mecanismo por el cual un push a un repositorio ajeno genere
# un evento `push` en otro repositorio, salvo que se configure explícitamente
# un trigger cross-repo (p. ej. `repository_dispatch` disparado manualmente
# por un workflow del otro repositorio, o un `workflow_call` reusable). Este
# proyecto no usa ninguno de esos mecanismos.
#
# Lo que este script SÍ puede, y debe, verificar localmente:
#   1. Que deploy.yml existe y define un trigger `push` sobre la rama `main`
#      (confirma la mitad "se activa automáticamente" del Requisito 1.6).
#   2. Que deploy.yml NO contiene ninguna referencia a Backend_Repository
#      como condición de disparo (ni `paths:` apuntando a esa carpeta, ni
#      `repository_dispatch`, ni `workflow_call`, ni `repository:` apuntando
#      a otro repo) — confirma negativamente que no se introdujo una
#      dependencia cruzada accidental.
#   3. Que Frontend_Repository y Backend_Repository son árboles de trabajo
#      Git independientes: ausencia de `.gitmodules` en Frontend_Repository
#      (no hay acoplamiento vía submódulo) y ausencia de un directorio
#      `.git` de Backend_Repository anidado dentro de Frontend_Repository
#      (y viceversa). Dado que son repositorios Git separados, el historial
#      de commits de uno es invisible para el `on.push` del otro por
#      definición del modelo de eventos de GitHub Actions — este es el
#      argumento que cierra el Requisito 1.6, no algo que GitHub Actions
#      necesite "configurarse" para cumplir.
#
# Ejecutable localmente:
#   ./scripts/smoke-test-pipeline-trigger.sh
#
# No requiere credenciales de AWS ni acceso a GitHub.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKFLOW_PATH="${FRONTEND_DIR}/.github/workflows/deploy.yml"

fail() {
  echo "FALLO: $1" >&2
  exit 1
}

echo "==> [1/4] Verificando que .github/workflows/deploy.yml existe"
[ -f "${WORKFLOW_PATH}" ] || fail "No se encontró ${WORKFLOW_PATH}"
echo "    OK: ${WORKFLOW_PATH}"

echo "==> [2/4] Verificando que el trigger incluye push sobre la rama main"
# Se exige que exista un bloque `push:` seguido (en las líneas siguientes)
# por `branches:` que mencione `main`, confirmando el disparo automático
# exigido por el Requisito 1.6.
if ! awk '
  /^on:/ { in_on=1 }
  in_on && /^[a-zA-Z]/ && !/^on:/ { in_on=0 }
  in_on && /push:/ { in_push=1; next }
  in_on && in_push && /branches:/ { if ($0 ~ /main/) { found=1 } }
  in_on && in_push && /^[[:space:]]*[a-zA-Z_]+:/ && !/branches:/ && !/push:/ { in_push=0 }
  END { exit !found }
' "${WORKFLOW_PATH}"; then
  fail "El workflow no define un trigger 'push' con 'branches' que incluya 'main'"
fi
echo "    OK: trigger 'on.push.branches' incluye 'main' (disparo automático confirmado)"

echo "==> [3/4] Verificando ausencia de dependencias cruzadas con Backend_Repository"
# Ninguna de estas construcciones debería aparecer en el workflow: si
# aparecieran, el pipeline dependería de un cambio en otro repositorio para
# dispararse, violando la cláusula "sin requerir ningún cambio en
# Backend_Repository" del Requisito 1.6.
CROSS_REPO_PATTERNS=(
  "Backend_Repository"
  "repository_dispatch"
  "workflow_call"
  "^[[:space:]]*paths:"
)
for pattern in "${CROSS_REPO_PATTERNS[@]}"; do
  if grep -Eiq "${pattern}" "${WORKFLOW_PATH}"; then
    # Backend_Repository solo está permitido dentro de comentarios
    # explicativos (líneas que empiezan, tras espacios, con '#'). Se
    # verifica explícitamente para ese patrón para no generar falsos
    # positivos con la documentación en línea del propio workflow.
    if [ "${pattern}" = "Backend_Repository" ]; then
      non_comment_matches="$(grep -Ein "${pattern}" "${WORKFLOW_PATH}" | grep -Ev '^[0-9]+:[[:space:]]*#' || true)"
      [ -z "${non_comment_matches}" ] && continue
      fail "Referencia no-comentada a 'Backend_Repository' encontrada en deploy.yml: ${non_comment_matches}"
    fi
    fail "Se encontró el patrón de dependencia cruzada '${pattern}' en deploy.yml"
  fi
done
echo "    OK: no hay 'paths:', 'repository_dispatch', 'workflow_call' ni referencias funcionales a Backend_Repository"

echo "==> [4/4] Verificando independencia de árboles de trabajo Git"
[ ! -f "${FRONTEND_DIR}/.gitmodules" ] || fail "Se encontró .gitmodules en Frontend_Repository (acoplamiento vía submódulo)"
echo "    OK: Frontend_Repository no define .gitmodules"

BACKEND_DIR="$(cd "${FRONTEND_DIR}/.." && pwd)/Backend_Repository"
if [ -d "${BACKEND_DIR}" ]; then
  [ ! -d "${FRONTEND_DIR}/Backend_Repository/.git" ] || fail "Backend_Repository/.git está anidado dentro de Frontend_Repository"
  [ ! -d "${BACKEND_DIR}/Frontend_Repository/.git" ] || fail "Frontend_Repository/.git está anidado dentro de Backend_Repository"
  echo "    OK: Frontend_Repository y Backend_Repository son directorios hermanos independientes (${BACKEND_DIR})"
else
  echo "    OK: no se encontró Backend_Repository en este entorno; se omite la verificación de anidamiento (no aplica)"
fi

echo ""
echo "==> Prueba de humo completada exitosamente."
echo "    Frontend_Pipeline (deploy.yml) se activa automáticamente ante un push"
echo "    a 'main' de Frontend_Repository, y no depende de ninguna condición"
echo "    (paths, repository_dispatch, workflow_call) atada a Backend_Repository."
echo "    Dado que Frontend_Repository y Backend_Repository son repositorios Git"
echo "    independientes (sin .gitmodules ni anidamiento de .git), un push a"
echo "    Backend_Repository nunca genera un evento 'push' observable por este"
echo "    workflow: esto es una propiedad estructural del modelo de eventos de"
echo "    GitHub Actions (cada workflow solo observa el historial de commits del"
echo "    repositorio donde vive, salvo un trigger cross-repo explícito, que este"
echo "    proyecto no utiliza), no un comportamiento que dependa de prueba"
echo "    adicional contra GitHub real."
