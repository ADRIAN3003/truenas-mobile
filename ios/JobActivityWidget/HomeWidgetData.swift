import Foundation

/// What the app saved for the home screen widgets: one JSON document in the
/// App Group, written by `HomeWidgetPublisher` on the Dart side. The text is
/// already in the user's language.
struct WidgetDocument: Decodable {
  var labels: [String: String] = [:]
  var defaultId: String?
  var servers: [WidgetServer] = []

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    labels = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
    defaultId = try c.decodeIfPresent(String.self, forKey: .defaultId)
    servers = try c.decodeIfPresent([WidgetServer].self, forKey: .servers) ?? []
  }

  private enum CodingKeys: String, CodingKey { case labels, defaultId, servers }

  func label(_ key: String, _ fallback: String) -> String {
    labels[key] ?? fallback
  }

  /// The chosen server, else the app's default one, else the first.
  func server(id: String?) -> WidgetServer? {
    if let id = id, let match = servers.first(where: { $0.id == id }) { return match }
    if let id = defaultId, let match = servers.first(where: { $0.id == id }) { return match }
    return servers.first
  }
}

struct WidgetServer: Decodable {
  var id: String
  var name: String
  /// Milliseconds since 1970 of the last successful look.
  var updatedAt: Double?
  var unreachable: Bool?
  var pools: PoolsData?
  var system: SystemData?
  var alerts: AlertsData?

  var updatedDate: Date? {
    updatedAt.map { Date(timeIntervalSince1970: $0 / 1000) }
  }
}

/// Levels are "ok", "warn" or "bad".
struct PoolsData: Decodable {
  var level: String
  var summary: String
  var items: [PoolItem]
}

struct PoolItem: Decodable {
  var name: String
  var status: String
  /// Percent used, 0 to 100.
  var used: Double
  var level: String
}

struct SystemData: Decodable {
  /// Percent, 0 to 100.
  var cpu: Double?
  var memory: Double?
  var memoryText: String?
  var temperature: String?
}

struct AlertsData: Decodable {
  var level: String
  var count: Int
  var summary: String
  var items: [AlertItem]
}

struct AlertItem: Decodable {
  var level: String
  var text: String
}

enum WidgetStore {
  /// Must match `homeWidgetAppGroup` in `home_widgets.dart` and the
  /// entitlements of the app and of this extension.
  static let appGroup = "group.hu.adrian.truenasmobile"
  static let key = "snapshot.v1"

  /// False when this install has no App Group (a sideloading tool dropped
  /// the entitlement): the app then saves its data in its own sandbox, where
  /// the widgets cannot see it.
  static var groupAvailable: Bool {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) != nil
  }

  static func load() -> WidgetDocument? {
    // Without the group there is no shared container; do not open the suite
    // at all then.
    guard
      groupAvailable,
      let defaults = UserDefaults(suiteName: appGroup),
      let json = defaults.string(forKey: key),
      let data = json.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(WidgetDocument.self, from: data)
  }

  /// What the widget gallery shows before the app has saved anything.
  static let sample: WidgetDocument? = {
    let json = """
      {"labels":{},"defaultId":"s","servers":[{"id":"s","name":"TrueNAS","updatedAt":\
      \(Date().timeIntervalSince1970 * 1000),"unreachable":false,\
      "pools":{"level":"ok","summary":"All pools healthy","items":[\
      {"name":"tank","status":"ONLINE","used":42,"level":"ok"},\
      {"name":"backup","status":"ONLINE","used":71,"level":"ok"}]},\
      "system":{"cpu":18,"memory":46,"memoryText":"14.7 GiB of 32.0 GiB","temperature":"48 °C"},\
      "alerts":{"level":"warn","count":2,"summary":"2 active alerts","items":[\
      {"level":"warn","text":"Scrub of pool tank is overdue"},\
      {"level":"ok","text":"An update is available"}]}}]}
      """
    return try? JSONDecoder().decode(WidgetDocument.self, from: Data(json.utf8))
  }()
}
