import AppIntents
import Foundation

// Siri and Shortcuts actions: start, stop or restart an app, run a cloud sync.
//
// They run in the app's own process but not in its Flutter engine. Like the
// home screen widgets they sign in to the server by themselves, with the
// details the app keeps in the shared Keychain group (`WidgetKeychain`), over
// the small JSON-RPC client in `Shared/ServerLink.swift`. The app hands the
// details over while the "Siri and Shortcuts" setting is on
// (`HomeWidgetPublisher`), so the actions work after the app was opened once.
//
// Each action only starts the job on the server and answers; the server
// carries it out (it shows under Jobs in the app, and in the Live Activity
// while the app runs). Nothing here waits for it to finish, since a background
// action gets little time.

@available(iOS 16.0, *)
enum ShortcutText {
  static var hungarian: Bool {
    Locale.preferredLanguages.first?.hasPrefix("hu") == true
  }

  /// The English or Hungarian text. The titles of the actions below are
  /// English only (they need string catalogs); what is said back is both.
  static func pick(_ en: String, _ hu: String) -> String {
    hungarian ? hu : en
  }
}

@available(iOS 16.0, *)
enum ShortcutError: Error, CustomLocalizedStringResourceConvertible {
  case noServers
  case unknownServer
  case badItem
  case unreachable(String)
  case signIn(String)
  case failed(String)

  /// Turns whatever a visit to [server] threw into something to say.
  static func from(_ error: Error, server: String) -> ShortcutError {
    if let error = error as? ShortcutError { return error }
    switch error as? WidgetFetchError {
    case .rejected(let type)?: return .signIn("\(server): \(type)")
    case .server(let message)?: return .failed(message)
    default: return .unreachable(server)
    }
  }

  var localizedStringResource: LocalizedStringResource {
    let text: String
    switch self {
    case .noServers:
      text = ShortcutText.pick(
        "No server is available. Open TrueNAS Mobile once, add a server, and check that Siri and Shortcuts is switched on in Settings.",
        "Nincs elérhető szerver. Nyisd meg egyszer a TrueNAS Mobile-t, add hozzá a szervert, és ellenőrizd, hogy a Siri és Parancsok be van kapcsolva a Beállításokban.")
    case .unknownServer:
      text = ShortcutText.pick(
        "That server is no longer saved in TrueNAS Mobile.",
        "Ez a szerver már nincs elmentve a TrueNAS Mobile-ban.")
    case .badItem:
      text = ShortcutText.pick(
        "I could not tell which item you meant. Pick it again in the shortcut.",
        "Nem tudom, melyik elemre gondoltál. Válaszd ki újra a parancsban.")
    case .unreachable(let server):
      text = ShortcutText.pick(
        "Could not reach \(server).", "A(z) \(server) nem érhető el.")
    case .signIn(let detail):
      text = ShortcutText.pick(
        "TrueNAS did not accept the saved sign-in (\(detail)). Accounts with two-factor authentication cannot be used here.",
        "A TrueNAS nem fogadta el a mentett belépést (\(detail)). A kétlépcsős azonosítású fiókok itt nem használhatók.")
    case .failed(let message):
      text = message
    }
    return "\(text)"
  }
}

/// The saved servers and the calls to them.
@available(iOS 16.0, *)
enum ShortcutServers {
  static func credentials() throws -> [WidgetCredential] {
    let all = WidgetCredentialStore.loadForShortcuts()
    if all.isEmpty { throw ShortcutError.noServers }
    return all
  }

  /// An entity id is `<server id>/<item>`; the item has no `/`, the server id
  /// might.
  static func split(_ id: String) -> (server: String, item: String)? {
    guard let slash = id.lastIndex(of: "/") else { return nil }
    let item = String(id[id.index(after: slash)...])
    guard !item.isEmpty else { return nil }
    return (String(id[..<slash]), item)
  }

  /// Calls [method] on the server with the id [id], failing with something
  /// to say when it cannot.
  static func call(
    server id: String, method: String, params: [Any] = []
  ) async throws {
    guard let credential = try credentials().first(where: { $0.id == id }) else {
      throw ShortcutError.unknownServer
    }
    do {
      try await ServerLink.session(credential) { rpc in
        _ = try await rpc.call(method, params)
      }
    } catch {
      throw ShortcutError.from(error, server: credential.name ?? "TrueNAS")
    }
  }

  /// The rows of [method] (a `*.query`) on every saved server, as
  /// `(server, row)`. A server that does not answer is left out.
  static func rows(of method: String) async throws -> [(WidgetCredential, [String: Any])] {
    var found: [(WidgetCredential, [String: Any])] = []
    for credential in try credentials() {
      let rows = try? await ServerLink.session(credential, timeout: 15) { rpc in
        (try await rpc.call(method) as? [[String: Any]]) ?? []
      }
      for row in rows ?? [] { found.append((credential, row)) }
    }
    return found
  }

  /// Names the server on an entity only when there is a choice of servers.
  static func label(_ credential: WidgetCredential, among servers: Int) -> String? {
    servers > 1 ? (credential.name ?? "TrueNAS") : nil
  }
}

// MARK: - Apps

@available(iOS 16.0, *)
struct TrueNASAppEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "App"
  static var defaultQuery = TrueNASAppQuery()

  /// `<server id>/<app name>`.
  var id: String
  var name: String
  var server: String?

  var displayRepresentation: DisplayRepresentation {
    if let server = server {
      return DisplayRepresentation(title: "\(name)", subtitle: "\(server)")
    }
    return DisplayRepresentation(title: "\(name)")
  }
}

@available(iOS 16.0, *)
struct TrueNASAppQuery: EntityStringQuery {
  /// Built from the ids alone: a shortcut that runs must not need the server
  /// twice.
  func entities(for identifiers: [String]) async throws -> [TrueNASAppEntity] {
    let servers = WidgetCredentialStore.loadForShortcuts()
    return identifiers.compactMap { id in
      guard let parts = ShortcutServers.split(id) else { return nil }
      let credential = servers.first { $0.id == parts.server }
      return TrueNASAppEntity(
        id: id, name: parts.item,
        server: credential.flatMap { ShortcutServers.label($0, among: servers.count) })
    }
  }

  func entities(matching string: String) async throws -> [TrueNASAppEntity] {
    try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) }
  }

  func suggestedEntities() async throws -> [TrueNASAppEntity] {
    let servers = try ShortcutServers.credentials()
    let rows = try await ShortcutServers.rows(of: "app.query")
    return rows.compactMap { credential, row -> TrueNASAppEntity? in
      guard let name = row["name"] as? String, !name.isEmpty else { return nil }
      return TrueNASAppEntity(
        id: credential.id + "/" + name, name: name,
        server: ShortcutServers.label(credential, among: servers.count))
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }
}

@available(iOS 16.0, *)
struct StartAppIntent: AppIntent {
  static var title: LocalizedStringResource = "Start an app"
  static var description = IntentDescription("Starts an app on your TrueNAS.")

  @Parameter(title: "App", requestValueDialog: "Which app?")
  var app: TrueNASAppEntity

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let parts = ShortcutServers.split(app.id) else { throw ShortcutError.badItem }
    try await ShortcutServers.call(server: parts.server, method: "app.start", params: [parts.item])
    return .result(
      dialog: "\(ShortcutText.pick("Starting \(parts.item).", "A(z) \(parts.item) indul."))")
  }
}

@available(iOS 16.0, *)
struct StopAppIntent: AppIntent {
  static var title: LocalizedStringResource = "Stop an app"
  static var description = IntentDescription("Stops an app on your TrueNAS.")

  @Parameter(title: "App", requestValueDialog: "Which app?")
  var app: TrueNASAppEntity

  /// Off for a shortcut that runs by itself, where nobody can answer.
  @Parameter(title: "Ask first", default: true)
  var confirm: Bool

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let parts = ShortcutServers.split(app.id) else { throw ShortcutError.badItem }
    if confirm {
      try await requestConfirmation(
        result: .result(
          dialog: "\(ShortcutText.pick("Stop \(parts.item)?", "Leállítod a(z) \(parts.item) appot?"))"
        ))
    }
    try await ShortcutServers.call(server: parts.server, method: "app.stop", params: [parts.item])
    return .result(
      dialog: "\(ShortcutText.pick("Stopping \(parts.item).", "A(z) \(parts.item) leáll."))")
  }
}

@available(iOS 16.0, *)
struct RestartAppIntent: AppIntent {
  static var title: LocalizedStringResource = "Restart an app"
  static var description = IntentDescription(
    "Restarts (redeploys) an app on your TrueNAS. The server does the work, so the app is back in a minute or so.")

  @Parameter(title: "App", requestValueDialog: "Which app?")
  var app: TrueNASAppEntity

  /// Off for a shortcut that runs by itself, where nobody can answer.
  @Parameter(title: "Ask first", default: true)
  var confirm: Bool

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let parts = ShortcutServers.split(app.id) else { throw ShortcutError.badItem }
    if confirm {
      try await requestConfirmation(
        result: .result(
          dialog:
            "\(ShortcutText.pick("Restart \(parts.item)?", "Újraindítod a(z) \(parts.item) appot?"))"
        ))
    }
    try await ShortcutServers.call(
      server: parts.server, method: "app.redeploy", params: [parts.item])
    return .result(
      dialog: "\(ShortcutText.pick("Restarting \(parts.item).", "A(z) \(parts.item) újraindul."))")
  }
}

// MARK: - Cloud sync

@available(iOS 16.0, *)
struct TrueNASCloudSyncEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Cloud sync task"
  static var defaultQuery = TrueNASCloudSyncQuery()

  /// `<server id>/<task id>`.
  var id: String
  var name: String
  var server: String?

  var displayRepresentation: DisplayRepresentation {
    if let server = server {
      return DisplayRepresentation(title: "\(name)", subtitle: "\(server)")
    }
    return DisplayRepresentation(title: "\(name)")
  }
}

@available(iOS 16.0, *)
struct TrueNASCloudSyncQuery: EntityStringQuery {
  func entities(for identifiers: [String]) async throws -> [TrueNASCloudSyncEntity] {
    let servers = WidgetCredentialStore.loadForShortcuts()
    return identifiers.compactMap { id in
      guard let parts = ShortcutServers.split(id) else { return nil }
      let credential = servers.first { $0.id == parts.server }
      return TrueNASCloudSyncEntity(
        id: id, name: "#" + parts.item,
        server: credential.flatMap { ShortcutServers.label($0, among: servers.count) })
    }
  }

  func entities(matching string: String) async throws -> [TrueNASCloudSyncEntity] {
    try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) }
  }

  func suggestedEntities() async throws -> [TrueNASCloudSyncEntity] {
    let servers = try ShortcutServers.credentials()
    let rows = try await ShortcutServers.rows(of: "cloudsync.query")
    return rows.compactMap { credential, row -> TrueNASCloudSyncEntity? in
      guard let id = (row["id"] as? NSNumber)?.intValue else { return nil }
      let description = (row["description"] as? String) ?? ""
      return TrueNASCloudSyncEntity(
        id: credential.id + "/" + String(id),
        name: description.isEmpty ? "#\(id)" : description,
        server: ShortcutServers.label(credential, among: servers.count))
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }
}

@available(iOS 16.0, *)
struct RunCloudSyncIntent: AppIntent {
  static var title: LocalizedStringResource = "Run a cloud sync"
  static var description = IntentDescription(
    "Starts a cloud sync task on your TrueNAS now. The transfer carries on on the server.")

  @Parameter(title: "Cloud sync task", requestValueDialog: "Which cloud sync?")
  var task: TrueNASCloudSyncEntity

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let parts = ShortcutServers.split(task.id), let number = Int(parts.item) else {
      throw ShortcutError.badItem
    }
    try await ShortcutServers.call(server: parts.server, method: "cloudsync.sync", params: [number])
    return .result(
      dialog: "\(ShortcutText.pick("Cloud sync started.", "A felhő szinkron elindult."))")
  }
}

// MARK: - Siri

/// The phrases Siri knows. Every phrase names the app, and the item is asked
/// for afterwards (the apps on a server are not known to Siri in advance).
@available(iOS 16.0, *)
struct TrueNASShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: RestartAppIntent(),
      phrases: [
        "Restart an app in \(.applicationName)",
        "Restart a \(.applicationName) app",
      ],
      shortTitle: "Restart app",
      systemImageName: "arrow.clockwise")
    AppShortcut(
      intent: StartAppIntent(),
      phrases: [
        "Start an app in \(.applicationName)",
        "Start a \(.applicationName) app",
      ],
      shortTitle: "Start app",
      systemImageName: "play.fill")
    AppShortcut(
      intent: StopAppIntent(),
      phrases: [
        "Stop an app in \(.applicationName)",
        "Stop a \(.applicationName) app",
      ],
      shortTitle: "Stop app",
      systemImageName: "stop.fill")
    AppShortcut(
      intent: RunCloudSyncIntent(),
      phrases: [
        "Run a cloud sync in \(.applicationName)",
        "Start a \(.applicationName) cloud sync",
      ],
      shortTitle: "Run cloud sync",
      systemImageName: "icloud.and.arrow.up")
  }
}
