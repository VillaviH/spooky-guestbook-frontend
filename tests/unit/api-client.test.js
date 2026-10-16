/*
 * Pruebas unitarias del modulo cliente de API de Frontend_Application
 * (public/js/api-client.js): createMessage() y listMessages().
 *
 * El archivo real se auto-ejecuta como IIFE y asigna
 * `window.SpookyGuestbookApiClient`. Con testEnvironment "jsdom", Jest
 * expone `window` como el objeto global de Node (es decir,
 * `global === window`), por lo que tras hacer `require(...)` el objeto
 * exportado es accesible indistintamente como `window.SpookyGuestbookApiClient`
 * o `global.SpookyGuestbookApiClient`. Se usa `window.*` en estas
 * pruebas por ser mas explicito y coherente con el codigo fuente.
 *
 * Como `require` cachea modulos y el archivo fuente solo verifica
 * `window.SPOOKY_GUESTBOOK_CONFIG`/`fetch` en tiempo de llamada (no al
 * cargar), basta requerir el archivo una sola vez; cada test redefine
 * `window.SPOOKY_GUESTBOOK_CONFIG` y `global.fetch` segun el caso.
 */

require("../../public/js/api-client.js");

describe("SpookyGuestbookApiClient", function () {
  var GENERIC_ERROR_MESSAGE =
    "Ocurrio un error al comunicarse con Backend_API.";

  beforeEach(function () {
    window.SPOOKY_GUESTBOOK_CONFIG = {
      backendApiBaseUrl: "https://fake-api.example.com",
    };
    global.fetch = jest.fn();
  });

  test("el modulo se expone en window tras cargar el script", function () {
    expect(window.SpookyGuestbookApiClient).toBeDefined();
    expect(typeof window.SpookyGuestbookApiClient.createMessage).toBe(
      "function"
    );
    expect(typeof window.SpookyGuestbookApiClient.listMessages).toBe(
      "function"
    );
  });

  describe("createMessage - casos de exito", function () {
    test("resuelve con el objeto creado y llama a fetch con POST /messages", function () {
      var responseBody = {
        messageId: "abc",
        content: "hello",
        timestamp: "2025-01-01T00:00:00.000Z",
      };
      global.fetch.mockResolvedValue({
        ok: true,
        text: function () {
          return Promise.resolve(JSON.stringify(responseBody));
        },
      });

      return window.SpookyGuestbookApiClient.createMessage("hello").then(
        function (result) {
          expect(global.fetch).toHaveBeenCalledTimes(1);
          expect(global.fetch).toHaveBeenCalledWith(
            "https://fake-api.example.com/messages",
            {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ content: "hello" }),
            }
          );
          expect(result).toEqual(responseBody);
        }
      );
    });
  });

  describe("listMessages - casos de exito", function () {
    test("resuelve con el arreglo de mensajes y llama a fetch con GET /messages", function () {
      var messages = [{ messageId: "1", content: "a", timestamp: "..." }];
      global.fetch.mockResolvedValue({
        ok: true,
        text: function () {
          return Promise.resolve(JSON.stringify({ messages: messages }));
        },
      });

      return window.SpookyGuestbookApiClient.listMessages().then(function (
        result
      ) {
        expect(global.fetch).toHaveBeenCalledTimes(1);
        expect(global.fetch).toHaveBeenCalledWith(
          "https://fake-api.example.com/messages",
          { method: "GET" }
        );
        expect(result).toEqual(messages);
      });
    });
  });

  describe("createMessage - casos de error", function () {
    test("se rechaza con el mensaje del backend cuando la respuesta no es ok", function () {
      global.fetch.mockResolvedValue({
        ok: false,
        text: function () {
          return Promise.resolve(
            JSON.stringify({
              error: "ValidationError",
              message: "El mensaje no puede estar vacio.",
            })
          );
        },
      });

      return expect(
        window.SpookyGuestbookApiClient.createMessage("")
      ).rejects.toThrow("El mensaje no puede estar vacio.");
    });

    test("propaga el rechazo cuando fetch falla (error de red)", function () {
      global.fetch.mockRejectedValue(new Error("network down"));

      return expect(
        window.SpookyGuestbookApiClient.createMessage("hello")
      ).rejects.toThrow("network down");
    });
  });

  describe("listMessages - casos de error", function () {
    test("se rechaza con el mensaje generico cuando el cuerpo de error no es parseable", function () {
      global.fetch.mockResolvedValue({
        ok: false,
        text: function () {
          return Promise.resolve("");
        },
      });

      return expect(
        window.SpookyGuestbookApiClient.listMessages()
      ).rejects.toThrow(GENERIC_ERROR_MESSAGE);
    });

    test("se rechaza con el mensaje generico cuando la respuesta no tiene campo messages valido", function () {
      global.fetch.mockResolvedValue({
        ok: true,
        text: function () {
          return Promise.resolve(JSON.stringify({ notMessages: [] }));
        },
      });

      return expect(
        window.SpookyGuestbookApiClient.listMessages()
      ).rejects.toThrow(GENERIC_ERROR_MESSAGE);
    });

    test("propaga el rechazo cuando fetch falla (error de red)", function () {
      global.fetch.mockRejectedValue(new Error("network down"));

      return expect(
        window.SpookyGuestbookApiClient.listMessages()
      ).rejects.toThrow("network down");
    });
  });
});
