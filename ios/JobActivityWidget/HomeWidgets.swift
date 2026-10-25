import AppIntents
import SwiftUI
import WidgetKit

/// The three home screen widgets. Each shows one server; the user picks
/// which one when adding the widget (iOS 17 and newer).
enum WidgetSection {
  case pools, system, alerts, activity

  /// Must match `_iosKinds` in `home_widgets.dart`.
  var kind: String {
    switch self {
    case .pools: return "TrueNASPools"
    case .system: return "TrueNASSystem"
    case .alerts: return "TrueNASAlerts"
    case .activity: return "TrueNASActivity"
    }
  }

  var symbol: String {
    switch self {
    case .pools: return "externaldrive.fill"
    case .system: return "cpu"
    case .alerts: return "bell.fill"
    case .activity: return "arrow.triangle.2.circlepath"
    }
  }

  var families: [WidgetFamily] {
    switch self {
    case .alerts: return [.systemSmall, .systemMedium, .systemLarge]
    default: return [.systemSmall, .systemMedium]
    }
  }

  /// The gallery texts, in the phone's language: the widget extension has no
  /// string files, and these are all it needs.
  var galleryName: String {
    let hu = Locale.preferredLanguages.first?.hasPrefix("hu") == true
    switch self {
    case .pools: return hu ? "Tárolók állapota" : "Pool health"
    case .system: return hu ? "CPU és RAM" : "CPU and memory"
    case .alerts: return hu ? "Riasztások" : "Alerts"
    case .activity: return hu ? "Tevékenység" : "Activity"
    }
  }

  var galleryDescription: String {
    let hu = Locale.preferredLanguages.first?.hasPrefix("hu") == true
    switch self {
    case .pools:
      return hu ? "A TrueNAS tárolóid állapota és telítettsége." : "How your TrueNAS pools are doing."
    case .system:
      return hu ? "A TrueNAS processzor- és memóriahasználata." : "CPU and memory use of your TrueNAS."
    case .alerts:
      return hu ? "A TrueNAS aktív riasztásai." : "The active alerts on your TrueNAS."
    case .activity:
      return hu
        ? "Frissítésre váró alkalmazások, futó scrub és felhő szinkron."
        : "Apps with updates, and running scrubs and cloud syncs."
    }
  }
}

struct StatusEntry: TimelineEntry {
  let date: Date
  let document: WidgetDocument?
  let server: WidgetServer?
  /// False when the install lacks the App Group, so the data cannot arrive.
  let groupAvailable: Bool

  static func current(serverId: String?, preview: Bool = false) -> StatusEntry {
    let document = WidgetStore.load()
    // A gallery preview of a widget with no data yet shows a sample.
    let shown = (preview && document?.servers.isEmpty != false) ? WidgetStore.sample : document
    return StatusEntry(
      date: Date(), document: shown, server: shown?.server(id: serverId),
      groupAvailable: WidgetStore.groupAvailable)
  }
}

/// How soon the widget asks to be drawn again, and so to look at its server
/// again: the phone decides how often it really does (a widget has a daily
/// budget), sooner after a failed visit.
private func nextRefresh(after entry: StatusEntry) -> Date {
  Date().addingTimeInterval(entry.server?.unreachable == true ? 5 * 60 : 15 * 60)
}

// MARK: - Server choice (iOS 17 and newer)

@available(iOS 17.0, *)
struct ServerEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Server"
  static var defaultQuery = ServerEntityQuery()

  var id: String
  var name: String

  /// Shows the app's default server (see `WidgetDocument.server(id:)`).
  static var followApp: ServerEntity {
    let hu = Locale.preferredLanguages.first?.hasPrefix("hu") == true
    return ServerEntity(id: "", name: hu ? "Alapértelmezett szerver" : "Default server")
  }

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }
}

@available(iOS 17.0, *)
struct ServerEntityQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [ServerEntity] {
    all().filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [ServerEntity] {
    all()
  }

  func defaultResult() async -> ServerEntity? {
    ServerEntity.followApp
  }

  /// "Follow the app" first, so the picker always has something to offer,
  /// even when the App Group cannot be read (a sideloading tool dropped it)
  /// or the app has not saved a server list yet.
  private func all() -> [ServerEntity] {
    let servers = (WidgetStore.load()?.servers ?? []).map {
      ServerEntity(id: $0.id, name: $0.name)
    }
    return [ServerEntity.followApp] + servers
  }
}

@available(iOS 17.0, *)
struct SelectServerIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Server"
  static var description = IntentDescription("Choose which server the widget shows.")

  @Parameter(title: "Server")
  var server: ServerEntity?
}

@available(iOS 17.0, *)
struct StatusProvider: AppIntentTimelineProvider {
  typealias Intent = SelectServerIntent

  func placeholder(in context: Context) -> StatusEntry {
    StatusEntry.current(serverId: nil, preview: true)
  }

  func snapshot(for configuration: SelectServerIntent, in context: Context) async -> StatusEntry {
    StatusEntry.current(serverId: configuration.server?.id, preview: context.isPreview)
  }

  func timeline(for configuration: SelectServerIntent, in context: Context) async
    -> Timeline<StatusEntry>
  {
    // The widget asks the server itself; see WidgetFetch.swift.
    let entry = await WidgetRefresher.entry(serverId: configuration.server?.id)
    return Timeline(entries: [entry], policy: .after(nextRefresh(after: entry)))
  }
}

// MARK: - Widgets

/// The configuration all three widgets share. A `Widget` needs an `init()`,
/// so each has a small type of its own instead of a stored `section`.
@available(iOS 17.0, *)
func statusConfiguration(_ section: WidgetSection) -> some WidgetConfiguration {
  AppIntentConfiguration(
    kind: section.kind, intent: SelectServerIntent.self, provider: StatusProvider()
  ) { entry in
    StatusWidgetView(entry: entry, section: section)
  }
  .configurationDisplayName(LocalizedStringKey(section.galleryName))
  .description(LocalizedStringKey(section.galleryDescription))
  .supportedFamilies(section.families)
}

@available(iOS 17.0, *)
struct PoolsWidget: Widget {
  var body: some WidgetConfiguration { statusConfiguration(.pools) }
}

@available(iOS 17.0, *)
struct SystemWidget: Widget {
  var body: some WidgetConfiguration { statusConfiguration(.system) }
}

@available(iOS 17.0, *)
struct AlertsWidget: Widget {
  var body: some WidgetConfiguration { statusConfiguration(.alerts) }
}

@available(iOS 17.0, *)
struct ActivityWidget: Widget {
  var body: some WidgetConfiguration { statusConfiguration(.activity) }
}
