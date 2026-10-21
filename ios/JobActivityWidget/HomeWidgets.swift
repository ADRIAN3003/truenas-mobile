import AppIntents
import SwiftUI
import WidgetKit

/// The three home screen widgets. Each shows one server; the user picks
/// which one when adding the widget (iOS 17 and newer).
enum WidgetSection {
  case pools, system, alerts

  /// Must match `_iosKinds` in `home_widgets.dart`.
  var kind: String {
    switch self {
    case .pools: return "TrueNASPools"
    case .system: return "TrueNASSystem"
    case .alerts: return "TrueNASAlerts"
    }
  }

  var symbol: String {
    switch self {
    case .pools: return "externaldrive.fill"
    case .system: return "cpu"
    case .alerts: return "bell.fill"
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
    }
  }
}

struct StatusEntry: TimelineEntry {
  let date: Date
  let document: WidgetDocument?
  let server: WidgetServer?

  static func current(serverId: String?, preview: Bool = false) -> StatusEntry {
    let document = WidgetStore.load()
    // A gallery preview of a widget with no data yet shows a sample.
    let shown = (preview && document?.servers.isEmpty != false) ? WidgetStore.sample : document
    return StatusEntry(date: Date(), document: shown, server: shown?.server(id: serverId))
  }
}

/// How soon the widget asks to be drawn again. The app tells the widgets when
/// there is news; this is only a safety net.
private func nextRefresh() -> Date {
  Date().addingTimeInterval(15 * 60)
}

// MARK: - Server choice (iOS 17 and newer)

@available(iOS 17.0, *)
struct ServerEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Server"
  static var defaultQuery = ServerEntityQuery()

  var id: String
  var name: String

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

  private func all() -> [ServerEntity] {
    (WidgetStore.load()?.servers ?? []).map { ServerEntity(id: $0.id, name: $0.name) }
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
    Timeline(
      entries: [StatusEntry.current(serverId: configuration.server?.id)],
      policy: .after(nextRefresh()))
  }
}

// MARK: - Widgets

@available(iOS 17.0, *)
struct StatusWidget: Widget {
  let section: WidgetSection

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: section.kind, intent: SelectServerIntent.self, provider: StatusProvider()
    ) { entry in
      StatusWidgetView(entry: entry, section: section)
    }
    .configurationDisplayName(section.galleryName)
    .description(section.galleryDescription)
    .supportedFamilies(section.families)
  }
}

/// The widgets of the app, for the extension's bundle.
@available(iOS 17.0, *)
struct HomeWidgets: WidgetBundle {
  var body: some Widget {
    StatusWidget(section: .pools)
    StatusWidget(section: .system)
    StatusWidget(section: .alerts)
  }
}
