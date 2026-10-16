/*
 * Logica de UI de Frontend_Application (Spooky Guestbook).
 *
 * La tarea 20.1 implemento la logica de UI estatica: manejo del submit
 * del formulario, renderizado de la lista de mensajes y validacion
 * basica en cliente del limite de 280 caracteres.
 *
 * La tarea 20.2 conecta `onSubmitMessage` y `loadMessages` al modulo
 * cliente de API real (js/api-client.js, expuesto como
 * `window.SpookyGuestbookApiClient`), que realiza las llamadas HTTPS
 * POST/GET /messages hacia Backend_API.
 */

(function () {
  "use strict";

  var MAX_MESSAGE_LENGTH = 280;

  var form = document.getElementById("message-form");
  var textarea = document.getElementById("message-content");
  var charCounter = document.getElementById("char-counter");
  var submitButton = document.getElementById("submit-button");
  var formError = document.getElementById("form-error");
  var messageList = document.getElementById("message-list");
  var listEmpty = document.getElementById("list-empty");

  /**
   * Valida el contenido de un Spooky_Message en el cliente.
   * Replica (de forma simplificada) la validacion del backend: rechaza
   * contenido vacio tras recortar espacios, y contenido de mas de 280
   * caracteres.
   *
   * @param {string} rawContent
   * @returns {{ valid: boolean, error: string|null, content: string }}
   */
  function validateMessageContent(rawContent) {
    var trimmed = (rawContent || "").trim();

    if (trimmed.length === 0) {
      return { valid: false, error: "El mensaje no puede estar vacio.", content: trimmed };
    }

    if (trimmed.length > MAX_MESSAGE_LENGTH) {
      return {
        valid: false,
        error: "El mensaje supera el limite de " + MAX_MESSAGE_LENGTH + " caracteres.",
        content: trimmed,
      };
    }

    return { valid: true, error: null, content: trimmed };
  }

  /**
   * Actualiza el contador visual de caracteres del textarea.
   */
  function updateCharCounter() {
    var length = textarea.value.length;
    charCounter.textContent = length + " / " + MAX_MESSAGE_LENGTH;
    charCounter.classList.toggle(
      "message-form__counter--over",
      length > MAX_MESSAGE_LENGTH
    );
  }

  /**
   * Muestra u oculta el mensaje de error del formulario.
   * @param {string|null} message
   */
  function setFormError(message) {
    if (!message) {
      formError.hidden = true;
      formError.textContent = "";
      return;
    }
    formError.hidden = false;
    formError.textContent = message;
  }

  /**
   * Crea el elemento <li> de un mensaje individual para la lista.
   * @param {{ messageId?: string, content: string, timestamp: string }} message
   * @returns {HTMLLIElement}
   */
  function createMessageListItem(message) {
    var item = document.createElement("li");
    item.className = "message-item";

    var content = document.createElement("p");
    content.className = "message-item__content";
    content.textContent = message.content;

    var timestamp = document.createElement("time");
    timestamp.className = "message-item__timestamp";
    timestamp.textContent = formatTimestamp(message.timestamp);
    if (message.timestamp) {
      timestamp.setAttribute("datetime", message.timestamp);
    }

    item.appendChild(content);
    item.appendChild(timestamp);
    return item;
  }

  /**
   * Formatea un timestamp ISO 8601 a una representacion legible.
   * Si el valor no es una fecha valida, lo devuelve tal cual.
   * @param {string} isoTimestamp
   * @returns {string}
   */
  function formatTimestamp(isoTimestamp) {
    if (!isoTimestamp) {
      return "";
    }
    var date = new Date(isoTimestamp);
    if (isNaN(date.getTime())) {
      return isoTimestamp;
    }
    return date.toLocaleString();
  }

  /**
   * Renderiza la lista de mensajes en el DOM.
   * Se asume que `messages` ya viene ordenado del mas reciente al mas
   * antiguo (ese orden lo garantiza Backend_API / GET /messages).
   *
   * `loadMessages` llama a esta funcion con la respuesta real del
   * cliente de API tras cargar la pagina y tras cada envio exitoso.
   *
   * @param {Array<{ messageId?: string, content: string, timestamp: string }>} messages
   */
  function renderMessages(messages) {
    messageList.innerHTML = "";

    var hasMessages = Array.isArray(messages) && messages.length > 0;
    listEmpty.hidden = hasMessages;

    if (!hasMessages) {
      return;
    }

    messages.forEach(function (message) {
      messageList.appendChild(createMessageListItem(message));
    });
  }

  /**
   * Punto de conexion para el envio de un Spooky_Message.
   *
   * Delega en el modulo cliente de API (`window.SpookyGuestbookApiClient`,
   * ver js/api-client.js) para realizar el POST /messages real hacia
   * Backend_API. Los errores se propagan al llamador (`handleSubmit`),
   * que ya los captura con `.catch` y muestra `setFormError`.
   *
   * @param {string} content - Contenido ya validado (trim aplicado).
   * @returns {Promise<void>}
   */
  function onSubmitMessage(content) {
    return window.SpookyGuestbookApiClient.createMessage(content).then(function () {
      return undefined;
    });
  }

  /**
   * Punto de conexion para cargar el listado de mensajes.
   *
   * Delega en el modulo cliente de API (`window.SpookyGuestbookApiClient`,
   * ver js/api-client.js) para realizar el GET /messages real hacia
   * Backend_API y pasa el resultado a `renderMessages`.
   *
   * @returns {Promise<void>}
   */
  function loadMessages() {
    return window.SpookyGuestbookApiClient.listMessages().then(renderMessages);
  }

  function handleSubmit(event) {
    event.preventDefault();

    var validation = validateMessageContent(textarea.value);
    if (!validation.valid) {
      setFormError(validation.error);
      return;
    }

    setFormError(null);
    submitButton.disabled = true;

    onSubmitMessage(validation.content)
      .then(function () {
        textarea.value = "";
        updateCharCounter();
        return loadMessages();
      })
      .catch(function (error) {
        setFormError("No se pudo enviar el mensaje. Intenta de nuevo.");
        console.error("Error al enviar Spooky_Message:", error);
      })
      .then(function () {
        submitButton.disabled = false;
      });
  }

  function init() {
    textarea.addEventListener("input", updateCharCounter);
    form.addEventListener("submit", handleSubmit);
    updateCharCounter();
    loadMessages().catch(function (error) {
      console.error("Error al cargar los Spooky_Message:", error);
    });
  }

  document.addEventListener("DOMContentLoaded", init);

  // Expuesto para pruebas unitarias (tarea 20.3).
  window.SpookyGuestbookApp = {
    validateMessageContent: validateMessageContent,
    renderMessages: renderMessages,
    onSubmitMessage: onSubmitMessage,
    loadMessages: loadMessages,
  };
})();
