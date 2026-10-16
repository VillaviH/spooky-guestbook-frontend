/*
 * Configuracion de Frontend_Application (Spooky Guestbook).
 *
 * `backendApiBaseUrl` debe apuntar a la URL base de Backend_API (el
 * endpoint de API_Gateway desplegado desde Backend_Repository), por
 * ejemplo "https://abc123.execute-api.us-east-1.amazonaws.com".
 *
 * No incluir una barra final ("/") en el valor.
 *
 * Este archivo se carga sin build step (no hay bundler ni variables de
 * entorno en tiempo de build para este sitio estatico): es un objeto
 * global simple que debes completar manualmente despues de desplegar
 * Backend_Repository. Ver el README de Frontend_Repository para
 * instrucciones de configuracion.
 */
window.SPOOKY_GUESTBOOK_CONFIG = {
  backendApiBaseUrl: "",
};
