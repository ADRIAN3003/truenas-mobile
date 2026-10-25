import CryptoKit
import Foundation
import Security

// What the home screen widgets (JobActivityWidget) and the Siri / Shortcuts
// actions (Runner) share to talk to a saved server by themselves: the sign-in
// details from the shared Keychain group, and a small JSON-RPC 2.0 client over
// one WebSocket (`/api/<version>`, `auth.login_ex`). The app's own client is in
// Dart; this is the Swift side for the two places that cannot call it.

enum WidgetFetchError: Error {
  case badAddress
  case timeout
  case closed
  case rejected(String)
  case server(String)
}

/// A saved server's sign-in details, as the app puts them in the shared
/// Keychain group (`HomeWidgetPublisher._credentials`).
struct WidgetCredential: Decodable {
  var id: String
  var name: String?
  var url: String
  /// "apiKey" or "password".
  var authMethod: String
  var username: String
  var secret: String
  /// SHA-256 of a self-signed certificate the user chose to trust, as
  /// `AB:CD:...`.
  var pinnedFingerprint: String?
  var apiVersion: String?
}

enum WidgetCredentialStore {
  private struct Saved: Decodable {
    var servers: [WidgetCredential]
    /// Who may use the details (settings in the app); absent in details an
    /// older app version saved, which only the widgets used.
    var widgets: Bool?
    var shortcuts: Bool?
  }

  private static func saved() -> Saved? {
    guard let data = WidgetKeychain.load() else { return nil }
    return try? JSONDecoder().decode(Saved.self, from: data)
  }

  /// For the home screen widgets: none when the app switched them off.
  static func load() -> [WidgetCredential] {
    guard let saved = saved(), saved.widgets != false else { return [] }
    return saved.servers
  }

  /// For the Siri and Shortcuts actions: none when the app switched them off.
  static func loadForShortcuts() -> [WidgetCredential] {
    guard let saved = saved(), saved.shortcuts != false else { return [] }
    return saved.servers
  }
}

/// Runs [body], and gives up after [seconds]: [close] is called then, to
/// release whatever [body] is waiting on.
func withTimeout<T>(
  _ seconds: Double, close: @escaping () -> Void, _ body: @escaping () async throws -> T
) async throws -> T {
  try await withThrowingTaskGroup(of: T.self) { group in
    group.addTask { try await body() }
    group.addTask {
      try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      close()
      throw WidgetFetchError.timeout
    }
    guard let first = try await group.next() else { throw WidgetFetchError.closed }
    group.cancelAll()
    return first
  }
}

/// A minimal JSON-RPC 2.0 client over one WebSocket. Calls go one after the
/// other, which is all a widget needs.
final class WidgetRpc: NSObject, URLSessionDelegate {
  private let pinned: String?
  private var session: URLSession?
  private var socket: URLSessionWebSocketTask?
  private var nextId = 1

  init(pinnedFingerprint: String?) {
    pinned = pinnedFingerprint?.uppercased()
    super.init()
  }

  func open(_ url: URL) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 15
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    self.session = session
    let socket = session.webSocketTask(with: url)
    self.socket = socket
    socket.resume()
  }

  func close() {
    socket?.cancel(with: .goingAway, reason: nil)
    session?.invalidateAndCancel()
  }

  /// Calls [method] and returns its `result`.
  func call(_ method: String, _ params: [Any] = []) async throws -> Any? {
    guard let socket = socket else { throw WidgetFetchError.closed }
    let id = nextId
    nextId += 1
    let body: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method, "params": params]
    let data = try JSONSerialization.data(withJSONObject: body)
    try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    while true {
      guard let object = try await receive(), (object["id"] as? Int) == id else { continue }
      if let error = object["error"] as? [String: Any] {
        throw WidgetFetchError.server((error["message"] as? String) ?? method)
      }
      return object["result"]
    }
  }

  /// The `fields` of the next `collection_update` of [collection], after
  /// `core.subscribe` for it.
  func nextUpdate(of collection: String) async throws -> [String: Any] {
    while true {
      guard
        let object = try await receive(),
        object["method"] as? String == "collection_update",
        let params = object["params"] as? [String: Any],
        params["collection"] as? String == collection,
        let fields = params["fields"] as? [String: Any]
      else { continue }
      return fields
    }
  }

  private func receive() async throws -> [String: Any]? {
    guard let socket = socket else { throw WidgetFetchError.closed }
    let data: Data
    switch try await socket.receive() {
    case .string(let text): data = Data(text.utf8)
    case .data(let bytes): data = bytes
    @unknown default: return nil
    }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  /// The certificates the system trusts, plus the one the user pinned for this
  /// server (trust on first use, as in the app).
  func urlSession(
    _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard
      challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
      let trust = challenge.protectionSpace.serverTrust
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }
    if SecTrustEvaluateWithError(trust, nil)
      || (pinned != nil && WidgetRpc.fingerprint(of: trust) == pinned)
    {
      completionHandler(.useCredential, URLCredential(trust: trust))
    } else {
      completionHandler(.cancelAuthenticationChallenge, nil)
    }
  }

  /// SHA-256 of the server's own certificate, `AB:CD:...`, as the app shows it.
  static func fingerprint(of trust: SecTrust) -> String? {
    guard
      let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
      let leaf = chain.first
    else { return nil }
    let digest = SHA256.hash(data: SecCertificateCopyData(leaf) as Data)
    return digest.map { String(format: "%02X", $0) }.joined(separator: ":")
  }
}

/// Finding and signing in to a saved server.
enum ServerLink {
  /// Opens [credential]'s server, signs in and runs [body] on the connection,
  /// all within [timeout] seconds.
  static func session<T>(
    _ credential: WidgetCredential, timeout: Double = 20,
    _ body: @escaping (WidgetRpc) async throws -> T
  ) async throws -> T {
    guard let url = socketURL(credential) else { throw WidgetFetchError.badAddress }
    let rpc = WidgetRpc(pinnedFingerprint: credential.pinnedFingerprint)
    defer { rpc.close() }
    return try await withTimeout(timeout, close: rpc.close) {
      rpc.open(url)
      try await login(rpc, credential)
      return try await body(rpc)
    }
  }

  static func login(_ rpc: WidgetRpc, _ credential: WidgetCredential) async throws {
    let data: [String: Any] =
      credential.authMethod == "apiKey"
      ? [
        "mechanism": "API_KEY_PLAIN", "username": credential.username,
        "api_key": credential.secret,
      ]
      : [
        "mechanism": "PASSWORD_PLAIN", "username": credential.username,
        "password": credential.secret,
      ]
    let result = try await rpc.call("auth.login_ex", [data]) as? [String: Any]
    let type = result?["response_type"] as? String
    // A 2FA account cannot sign in here (there is nobody to ask for the code).
    guard type == "SUCCESS" else { throw WidgetFetchError.rejected(type ?? "UNKNOWN") }
  }

  /// `wss://host[:port]/api/<version>`; the version the app last used, else
  /// `current`.
  static func socketURL(_ credential: WidgetCredential) -> URL? {
    let text = credential.url.contains("://") ? credential.url : "https://" + credential.url
    guard
      let address = URLComponents(string: text), let host = address.host, !host.isEmpty,
      address.scheme == "https" || address.scheme == "http"
    else { return nil }
    var parts = URLComponents()
    parts.scheme = address.scheme == "http" ? "ws" : "wss"
    parts.host = host
    parts.port = address.port
    parts.path = "/api/" + (credential.apiVersion ?? "current")
    return parts.url
  }
}
