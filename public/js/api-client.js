/*
 * Modulo cliente de API de Frontend_Application (Spooky Guestbook).
 *
 * Implementa las llamadas HTTPS hacia Backend_API (POST/GET /messages)
 * descritas en el contrato de API de design.md. Lee la URL base desde
 * `window.SPOOKY_GUESTBOOK_CONFIG.backendApiBaseUrl` (ver js/config.js,
 * que debe cargarse antes que este archivo).
 *
 * Sin build step: vanilla JS consistente con el resto del frontend,
 * usa `fetch` nativo del navegador.
 */

(function () {
  "use strict";

  var GENERIC_ERROR_MESSAGE = "Ocurrio un error al comunicarse con Backend_API.";

  /**
   * Obtiene la URL base configurada para Backend_API, sin barra final.
   * @returns {string}
   */
  function getBaseUrl() {
    var config = window.SPOOKY_GUESTBOOK_CONFIG || {};
    var baseUrl = config.backendApiBaseUrl || "";
    return baseUrl.replace(/\/+$/, "");
  }

  /**
   * Verifica que la URL base use HTTPS y loguea una advertencia en
   * consola en caso contrario. No bloquea la llamada: en desarrollo
   * local (localhost/127.0.0.1) o cuando el placeholder esta vacio es
   * normal no tener HTTPS todavia (el participante del hackathon
   * completa el valor tras desplegar Backend_API, ver js/config.js).
   * @param {string} baseUrl
   */
  function warnIfNotHttps(baseUrl) {
    if (!baseUrl) {
      return;
    }
    var isHttps = /^https:\/\//i.test(baseUrl);
    var isLocalDev = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?/i.test(baseUrl);
    if (!isHttps && !isLocalDev) {
      console.warn(
        "[SpookyGuestbookApiClient] backendApiBaseUrl no usa HTTPS: " + baseUrl
      );
    }
  }

  /**
   * Intenta parsear el cuerpo de una respuesta HTTP como JSON.
   * Devuelve `null` si el cuerpo esta vacio o no es JSON valido, en
   * lugar de lanzar, para que los llamadores puedan decidir que hacer
   * (p. ej. construir un mensaje de error generico).
   * @param {Response} response
   * @returns {Promise<any|null>}
   */
  function parseJsonSafe(response) {
    return response
      .text()
      .then(function (text) {
        if (!text) {
          return null;
        }
        try {
          return JSON.parse(text);
        } catch (parseError) {
          return null;
        }
      })
      .catch(function () {
        return null;
      });
  }

  /**
   * Construye un Error a partir de una respuesta HTTP no exitosa,
   * usando el mensaje del backend cuando esta disponible (contrato
   * `{ "error": "...", "message": "..." }`) o un mensaje generico si
   * el cuerpo no se puede parsear.
   * @param {any|null} body
   * @returns {Error}
   */
  function buildErrorFromBody(body) {
    if (body && typeof body.message === "string" && body.message) {
      return new Error(body.message);
    }
    return new Error(GENERIC_ERROR_MESSAGE);
  }

  /**
   * Envia un nuevo Spooky_Message a Backend_API.
   *
   * POST /messages
   *   Request: { "content": "..." }
   *   201 Created: { "messageId": "...", "content": "...", "timestamp": "..." }
   *   400/500: { "error": "...", "message": "..." }
   *
   * @param {string} content
   * @returns {Promise<{ messageId: string, content: string, timestamp: string }>}
   */
  function createMessage(content) {
    var baseUrl = getBaseUrl();
    warnIfNotHttps(baseUrl);

    return fetch(baseUrl + "/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ content: content }),
    }).then(function (response) {
      return parseJsonSafe(response).then(function (body) {
        if (!response.ok) {
          throw buildErrorFromBody(body);
        }
        return body;
      });
    });
  }

  /**
   * Obtiene el listado de Spooky_Message desde Backend_API.
   *
   * GET /messages
   *   200 OK: { "messages": [ { "messageId": "...", "content": "...", "timestamp": "..." }, ... ] }
   *
   * @returns {Promise<Array<{ messageId: string, content: string, timestamp: string }>>}
   */
  function listMessages() {
    var baseUrl = getBaseUrl();
    warnIfNotHttps(baseUrl);

    return fetch(baseUrl + "/messages", {
      method: "GET",
    }).then(function (response) {
      return parseJsonSafe(response).then(function (body) {
        if (!response.ok) {
          throw buildErrorFromBody(body);
        }
        if (!body || !Array.isArray(body.messages)) {
          throw new Error(GENERIC_ERROR_MESSAGE);
        }
        return body.messages;
      });
    });
  }

  window.SpookyGuestbookApiClient = {
    createMessage: createMessage,
    listMessages: listMessages,
  };
})();
