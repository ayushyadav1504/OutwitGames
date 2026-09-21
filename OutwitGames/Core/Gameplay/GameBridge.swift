import Foundation

nonisolated enum GameLifecycleState: String, Sendable {
  case active
  case paused
}

nonisolated enum GameBridge {
  static let hostHandler = "outwitHost"
  static let lifecycleHandler = "outwitLifecycleReady"

  static func documentStartScript(
    configuration: [String: JSONValue],
    lifecycle: GameLifecycleState
  ) throws -> String {
    let configurationJSON = try json(configuration)
    let lifecycleName = try json(lifecycleHandler)
    let hostName = try json(hostHandler)
    let lifecycleValue = try json(lifecycle.rawValue)

    return """
      (() => {
        if (window.top !== window.self) return;
        const configuration = \(configurationJSON);
        configuration.lifecycle = { version: 1, state: \(lifecycleValue) };
        window.OutwitHost = configuration;

        const nativeHandlers = window.webkit && window.webkit.messageHandlers;
        if (!nativeHandlers) return;
        const hostTypes = [
          'outwit:pause', 'outwit:resume', 'outwit:lifecycle', 'outwit:get-state'
        ];
        const post = (payload) => {
          try {
            return nativeHandlers[\(hostName)].postMessage(payload);
          } catch (_) {
            return Promise.resolve(null);
          }
        };
        window.addEventListener('message', (event) => {
          const data = event.data;
          if (!data || typeof data !== 'object' || typeof data.type !== 'string') return;
          if (hostTypes.indexOf(data.type) !== -1) return;
          post(data);
        });

        const compatibilityHost = window.flutter_inappwebview || {};
        compatibilityHost.callHandler = (name, ...args) => {
          if (name === \(lifecycleName)) {
            return nativeHandlers[\(lifecycleName)].postMessage(null);
          }
          if (name === \(hostName)) {
            post(args.length === 1 ? args[0] : args);
          }
          return Promise.resolve(null);
        };
        window.flutter_inappwebview = compatibilityHost;
      })();
      """
  }

  static func lifecycleScript(_ lifecycle: GameLifecycleState, hostOrigin: URL) throws -> String {
    let state = try json(lifecycle.rawValue)
    let origin = try json(hostOrigin.absoluteString)
    return """
      (() => {
        window.OutwitHost = window.OutwitHost || {};
        const lifecycle = { version: 1, state: \(state) };
        window.OutwitHost.lifecycle = lifecycle;
        const message = { type: 'outwit:\(lifecycle == .active ? "resume" : "pause")' };
        try {
          window.dispatchEvent(new MessageEvent('message', { data: message, origin: \(origin) }));
        } catch (_) {
          window.postMessage(message, window.location.origin);
        }
        window.dispatchEvent(new CustomEvent('outwit:lifecycle', { detail: lifecycle }));
      })();
      """
  }

  static func stateRequestScript(requestID: String, hostOrigin: URL) throws -> String {
    let identifier = try json(requestID)
    let origin = try json(hostOrigin.absoluteString)
    return """
      (() => {
        const message = { type: 'outwit:get-state', requestId: \(identifier) };
        try {
          window.dispatchEvent(new MessageEvent('message', { data: message, origin: \(origin) }));
        } catch (_) {
          window.postMessage(message, window.location.origin);
        }
      })();
      """
  }

  private static func json<T: Encodable>(_ value: T) throws -> String {
    let data = try JSONEncoder().encode(value)
    guard let value = String(data: data, encoding: .utf8) else { throw AppError.parsing }
    return value
  }
}
