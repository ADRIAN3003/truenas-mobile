import CryptoKit
import Foundation
import Security

// The home screen widgets fetch their own data. The phone rarely wakes the app
// in the background, and a widget that only shows what the app last saved goes
// stale (and then says "can't reach the server" for good after one failed
// background run). So every time WidgetKit asks for a new timeline, the widget
// signs in to its server, reads pools, alerts and one CPU/memory sample, and
// saves the result for the other widgets and the app.
//
// It speaks the same JSON-RPC over WebSocket as the app (`/api/<version>`,
// `auth.login_ex`, `pool.query`, `alert.list`, `reporting.realtime`) and
// shapes the data the way `serverWidgetData` in `home_widget_data.dart` does.
// Keep the two in step.

/// What one visit to a server brings back.
struct WidgetSnapshot {
  var pools: PoolsData
  var alerts: AlertsData
  /// Nil when the server could not list its jobs.
  var jobs: JobsData?
  /// Nil when the server has no apps to list.
  var apps: AppsData?
  /// Nil when the server sent no CPU/memory sample in time.
  var system: SystemData?
}

enum WidgetFetcher {
  /// The whole visit, sign-in included. WidgetKit gives a timeline a short
  /// time, and a server behind a VPN can be slow to answer the first time.
  static let visitTimeout = 20.0
  static let sampleTimeout = 6.0

  static func snapshot(
    of credential: WidgetCredential, label: @escaping (String, String) -> String
  ) async throws -> WidgetSnapshot {
    guard let url = ServerLink.socketURL(credential) else { throw WidgetFetchError.badAddress }
    let rpc = WidgetRpc(pinnedFingerprint: credential.pinnedFingerprint)
    defer { rpc.close() }
    return try await withTimeout(visitTimeout, close: rpc.close) {
      rpc.open(url)
      try await ServerLink.login(rpc, credential)
      let pools = (try await rpc.call("pool.query") as? [[String: Any]]) ?? []
      let alerts = (try await rpc.call("alert.list") as? [[String: Any]]) ?? []
      // Not worth failing the visit for: the widget then shows no jobs.
      let active: [Any] = ["state", "in", ["WAITING", "RUNNING"]]
      let jobs = try? await rpc.call("core.get_jobs", [[active]]) as? [[String: Any]]
      let apps = try? await rpc.call("app.query") as? [[String: Any]]
      // Last, because a server that sends no sample is waited for until the
      // timeout and then hung up on, which ends the visit.
      let fields = try? await withTimeout(sampleTimeout, close: rpc.close) {
        _ = try await rpc.call("core.subscribe", ["reporting.realtime"])
        return try await rpc.nextUpdate(of: "reporting.realtime")
      }
      return WidgetSnapshot(
        pools: WidgetShape.pools(pools, label: label),
        alerts: WidgetShape.alerts(alerts, label: label),
        jobs: jobs.map { WidgetShape.jobs($0, label: label) },
        apps: apps.map { WidgetShape.apps($0, label: label) },
        system: fields.map { WidgetShape.system($0, label: label) })
    }
  }
}

/// The JSON the app saves for a widget (`serverWidgetData`), built from the
/// raw answers of the server.
enum WidgetShape {
  private static let alertLevels = [
    "info", "notice", "warning", "error", "critical", "alert", "emergency",
  ]

  static func pools(
    _ rows: [[String: Any]], label: (String, String) -> String
  ) -> PoolsData {
    let items = rows.map { row -> PoolItem in
      let status = (row["status"] as? String ?? "UNKNOWN").uppercased()
      let size = number(row["size"])
      let fraction = size == 0 ? 0 : number(row["allocated"]) / size
      let level: String
      switch status {
      case "ONLINE": level = (row["healthy"] as? Bool != true || fraction >= 0.9) ? "warn" : "ok"
      case "DEGRADED": level = "warn"
      default: level = "bad"
      }
      return PoolItem(
        name: row["name"] as? String ?? "", status: status,
        used: round1(min(max(fraction, 0), 1) * 100), level: level)
    }
    let attention = items.filter { $0.level != "ok" }.count
    let level = items.contains { $0.level == "bad" } ? "bad" : (attention > 0 ? "warn" : "ok")
    let summary: String
    if items.isEmpty {
      summary = label("noPools", "No pools")
    } else if attention == 0 {
      summary = label("poolsOk", "All pools healthy")
    } else {
      summary = counted(
        attention, label: label, one: ("poolsAttentionOne", "1 pool needs attention"),
        many: ("poolsAttentionMany", "{count} pools need attention"))
    }
    return PoolsData(level: level, summary: summary, items: items)
  }

  static func alerts(
    _ rows: [[String: Any]], label: (String, String) -> String
  ) -> AlertsData {
    let active = rows
      .filter { $0["dismissed"] as? Bool != true }
      .sorted { levelIndex($0) > levelIndex($1) }
    let severities = active.map(severity)
    let level =
      severities.contains("bad") ? "bad" : (severities.contains("warn") ? "warn" : "ok")
    let summary =
      active.isEmpty
      ? label("alertsNone", "No active alerts")
      : counted(
        active.count, label: label, one: ("alertsCountOne", "1 active alert"),
        many: ("alertsCountMany", "{count} active alerts"))
    let items = active.prefix(4).map { row in
      AlertItem(level: severity(row), text: shorten(plain(message(row))))
    }
    return AlertsData(level: level, count: active.count, summary: summary, items: Array(items))
  }

  /// How many of [rows] (the installed apps) have an update, like `_apps` in
  /// `home_widget_data.dart`.
  static func apps(_ rows: [[String: Any]], label: (String, String) -> String) -> AppsData {
    let updates = rows.filter { $0["upgrade_available"] as? Bool == true }.count
    let summary =
      updates == 0
      ? label("appsNone", "All apps are up to date")
      : counted(
        updates, label: label, one: ("appsUpdatesOne", "1 app has an update"),
        many: ("appsUpdatesMany", "{count} apps have updates"))
    return AppsData(updates: updates, summary: summary)
  }

  /// The scrubs and cloud syncs among [rows] (the jobs that wait or run), like
  /// `_jobItems` in `home_widget_data.dart`.
  static func jobs(_ rows: [[String: Any]], label: (String, String) -> String) -> JobsData {
    var items: [JobItem] = []
    for row in rows {
      let state = (row["state"] as? String ?? "").uppercased()
      guard state == "RUNNING" || state == "WAITING" else { continue }
      // `core.bulk` counts as the method it runs.
      let arguments = row["arguments"] as? [Any] ?? []
      let first = arguments.first as? String
      var method = row["method"] as? String ?? ""
      if method == "core.bulk", let first = first { method = first }
      let kind: String
      let name: String
      if method.hasPrefix("pool.scrub") {
        kind = "scrub"
        name = label("jobScrub", "Scrub")
      } else if method == "cloudsync.sync" {
        kind = "cloudSync"
        name = label("jobCloudSync", "Cloud sync")
      } else if method == "cloud_backup.sync" {
        kind = "cloudBackup"
        name = label("jobCloudBackup", "Cloud backup")
      } else {
        continue
      }
      let target = (kind == "scrub" && row["method"] as? String != "core.bulk") ? first : nil
      let progress = row["progress"] as? [String: Any] ?? [:]
      let running = state == "RUNNING"
      let percent = running ? (progress["percent"] as? NSNumber).map { $0.doubleValue } : nil
      items.append(
        JobItem(
          kind: kind, title: target.map { "\(name) · \($0)" } ?? name,
          percent: percent.map { round1(min(max($0, 0), 100)) },
          detail: running
            ? shorten(progress["description"] as? String ?? "", 80) : label("jobWaiting", "Waiting")
        ))
      if items.count == 3 { break }
    }
    return JobsData(items: items)
  }

  static func system(_ fields: [String: Any], label: (String, String) -> String) -> SystemData {
    let cpu = (fields["cpu"] as? [String: Any])?["cpu"] as? [String: Any] ?? [:]
    let memory = fields["memory"] as? [String: Any] ?? [:]
    let total = number(memory["physical_memory_total"])
    let used = total - number(memory["physical_memory_available"])
    let temperature = (cpu["temp"] as? NSNumber).map { "\(Int($0.doubleValue.rounded())) °C" }
    return SystemData(
      cpu: round1(number(cpu["usage"])),
      memory: total == 0 ? nil : round1(used / total * 100),
      memoryText: label("memoryText", "{used} of {total}")
        .replacingOccurrences(of: "{used}", with: bytes(used))
        .replacingOccurrences(of: "{total}", with: bytes(total)),
      temperature: temperature)
  }

  // MARK: Helpers

  /// A plural message: [one] for exactly 1, else [many] with `{count}`.
  private static func counted(
    _ count: Int, label: (String, String) -> String, one: (String, String),
    many: (String, String)
  ) -> String {
    if count == 1 { return label(one.0, one.1) }
    return label(many.0, many.1).replacingOccurrences(of: "{count}", with: "\(count)")
  }

  private static func levelIndex(_ alert: [String: Any]) -> Int {
    alertLevels.firstIndex(of: (alert["level"] as? String ?? "").lowercased()) ?? 0
  }

  /// The colour level the app gives an alert: "ok", "warn" or "bad".
  private static func severity(_ alert: [String: Any]) -> String {
    switch levelIndex(alert) {
    case 0, 1: return "ok"
    case 2: return "warn"
    default: return "bad"
    }
  }

  private static func message(_ alert: [String: Any]) -> String {
    let text = (alert["formatted"] as? String) ?? (alert["text"] as? String) ?? ""
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// An alert's text without the HTML TrueNAS puts in it.
  private static func plain(_ text: String) -> String {
    text
      .replacingOccurrences(
        of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive]
      )
      .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
      .replacingOccurrences(of: "&nbsp;", with: " ")
      .replacingOccurrences(of: "&amp;", with: "&")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// A widget has little room: the first line or so.
  private static func shorten(_ text: String, _ limit: Int = 110) -> String {
    let first = text.split(separator: "\n", omittingEmptySubsequences: false).first
    let line = String(first ?? "").trimmingCharacters(in: .whitespaces)
    guard line.count > limit else { return line }
    return String(line.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
  }

  private static func number(_ value: Any?) -> Double {
    if let number = value as? NSNumber { return number.doubleValue }
    if let text = value as? String, let number = Double(text) { return number }
    return 0
  }

  private static func round1(_ value: Double) -> Double { (value * 10).rounded() / 10 }

  /// `17179869184` is "16.0 GiB", like `formatBytes` in the app.
  private static func bytes(_ value: Double) -> String {
    let units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
    var scaled = value
    var unit = 0
    while scaled >= 1024 && unit < units.count - 1 {
      scaled /= 1024
      unit += 1
    }
    return unit == 0 ? "\(Int(value)) B" : String(format: "%.1f %@", scaled, units[unit])
  }
}

/// The widgets' own refresh: look at the server now, keep what was known when
/// it cannot be reached.
enum WidgetRefresher {
  /// A look this recent is not repeated: the three widgets reload together.
  static let freshFor: TimeInterval = 60

  /// The entry to draw, after a visit to the server of this widget when the
  /// phone can read its sign-in details and the data is not fresh already.
  static func entry(serverId: String?) async -> StatusEntry {
    let document = WidgetStore.load()
    let credentials = WidgetCredentialStore.load()
    let wantedId =
      document?.server(id: serverId)?.id
      ?? credentials.first(where: { $0.id == serverId })?.id
      ?? credentials.first?.id
    // Nothing to sign in with (a sideloaded install without the Keychain
    // group): show what the app saved.
    guard
      let id = wantedId, let credential = credentials.first(where: { $0.id == id })
    else { return StatusEntry.current(serverId: serverId) }

    let known = document?.servers.first(where: { $0.id == id })
    if let known = known, known.unreachable != true, let at = known.updatedDate,
      Date().timeIntervalSince(at) < freshFor
    {
      return StatusEntry.current(serverId: id)
    }

    var server = known ?? WidgetServer(id: id, name: credential.name ?? "TrueNAS")
    do {
      let snapshot = try await WidgetFetcher.snapshot(of: credential) { key, fallback in
        document?.label(key, fallback) ?? fallback
      }
      server.pools = snapshot.pools
      server.alerts = snapshot.alerts
      server.jobs = snapshot.jobs
      server.apps = snapshot.apps
      // A server that sent no sample keeps the last one.
      if let system = snapshot.system { server.system = system }
      server.updatedAt = Date().timeIntervalSince1970 * 1000
      server.unreachable = false
    } catch {
      server.unreachable = true
    }

    var saved = document ?? WidgetDocument()
    saved.replace(server)
    WidgetStore.save(saved)
    return StatusEntry(
      date: Date(), document: saved, server: server, groupAvailable: WidgetStore.groupAvailable)
  }
}
