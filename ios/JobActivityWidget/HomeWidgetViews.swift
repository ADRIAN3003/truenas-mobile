import SwiftUI
import UIKit
import WidgetKit

enum WidgetTint {
  /// "ok", "warn" or "bad", as the app saves the levels.
  static func color(_ level: String) -> Color {
    switch level {
    case "bad": return .red
    case "warn": return .orange
    default: return .green
    }
  }

  /// A gauge turns orange and red as the load climbs.
  static func load(_ percent: Double) -> Color {
    if percent >= 90 { return .red }
    if percent >= 75 { return .orange }
    return .blue
  }
}

struct StatusWidgetView: View {
  let entry: StatusEntry
  let section: WidgetSection

  @Environment(\.widgetFamily) private var family

  var body: some View {
    content
      .containerBackground(for: .widget) {
        Color(uiColor: .secondarySystemBackground)
      }
  }

  @ViewBuilder
  private var content: some View {
    if let server = entry.server, let document = entry.document {
      VStack(alignment: .leading, spacing: 8) {
        HeaderRow(symbol: section.symbol, title: server.name)
        switch section {
        case .pools: PoolsBody(server: server, document: document, family: family)
        case .system: SystemBody(server: server, document: document, family: family)
        case .alerts: AlertsBody(server: server, document: document, family: family)
        }
        Spacer(minLength: 0)
        FooterRow(server: server, document: document)
      }
    } else {
      VStack(alignment: .leading, spacing: 8) {
        HeaderRow(symbol: section.symbol, title: "TrueNAS")
        Spacer(minLength: 0)
        Text(verbatim: entry.document?.label("setup", "Open TrueNAS Mobile to set up")
          ?? "Open TrueNAS Mobile to set up")
          .font(.footnote)
          .foregroundStyle(.secondary)
        Spacer(minLength: 0)
      }
    }
  }
}

struct HeaderRow: View {
  let symbol: String
  let title: String

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: symbol)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(verbatim: title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
  }
}

/// The time of the last look, or why there is none.
struct FooterRow: View {
  let server: WidgetServer
  let document: WidgetDocument

  var body: some View {
    if server.unreachable == true {
      Text(verbatim: document.label("unreachable", "Can't reach the server"))
        .font(.caption2)
        .foregroundStyle(.orange)
        .lineLimit(1)
    } else if let date = server.updatedDate {
      HStack(spacing: 3) {
        Text(verbatim: document.label("updated", "Updated"))
        Text(date, style: .time)
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
      .lineLimit(1)
    } else {
      Text(verbatim: document.label("noData", "No data yet. Open the app."))
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)
    }
  }
}

// MARK: - Pools

struct PoolsBody: View {
  let server: WidgetServer
  let document: WidgetDocument
  let family: WidgetFamily

  var body: some View {
    if let pools = server.pools {
      if family == .systemSmall {
        VStack(alignment: .leading, spacing: 4) {
          Image(systemName: pools.level == "ok"
            ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.title)
            .foregroundStyle(WidgetTint.color(pools.level))
          Text(verbatim: pools.summary)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
        }
      } else {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Image(systemName: pools.level == "ok"
              ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
              .font(.largeTitle)
              .foregroundStyle(WidgetTint.color(pools.level))
            Text(verbatim: pools.summary)
              .font(.subheadline.weight(.semibold))
              .lineLimit(3)
              .minimumScaleFactor(0.8)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          VStack(spacing: 6) {
            ForEach(Array(pools.items.prefix(3).enumerated()), id: \.offset) { _, item in
              PoolRow(item: item)
            }
          }
          .frame(maxWidth: .infinity)
        }
      }
    } else {
      NoData(document: document)
    }
  }
}

struct PoolRow: View {
  let item: PoolItem

  var body: some View {
    VStack(spacing: 2) {
      HStack {
        Text(verbatim: item.name)
          .font(.caption.weight(.medium))
          .lineLimit(1)
        Spacer(minLength: 4)
        Text(verbatim: item.level == "ok" ? "\(Int(item.used.rounded()))%" : item.status)
          .font(.caption2.monospacedDigit())
          .foregroundStyle(item.level == "ok" ? Color.secondary : WidgetTint.color(item.level))
          .lineLimit(1)
      }
      ProgressView(value: min(max(item.used / 100, 0), 1))
        .tint(WidgetTint.color(item.level))
    }
  }
}

// MARK: - CPU and memory

struct SystemBody: View {
  let server: WidgetServer
  let document: WidgetDocument
  let family: WidgetFamily

  var body: some View {
    if let system = server.system {
      HStack(spacing: 12) {
        LoadGauge(
          title: document.label("cpu", "CPU"), percent: system.cpu)
        LoadGauge(
          title: document.label("memory", "RAM"), percent: system.memory)
        if family != .systemSmall {
          VStack(alignment: .leading, spacing: 4) {
            if let text = system.memoryText {
              Text(verbatim: text)
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            }
            if let temperature = system.temperature {
              Label {
                Text(verbatim: temperature)
              } icon: {
                Image(systemName: "thermometer.medium")
              }
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .frame(maxWidth: .infinity)
    } else {
      NoData(document: document)
    }
  }
}

/// A ring that fills with the load, with the number and its name inside.
struct LoadGauge: View {
  let title: String
  let percent: Double?

  var body: some View {
    let fraction = min(max((percent ?? 0) / 100, 0), 1)
    let color = percent.map { WidgetTint.load($0) } ?? Color.gray
    ZStack {
      Circle()
        .stroke(color.opacity(0.2), lineWidth: 8)
      Circle()
        .trim(from: 0, to: fraction)
        .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
        .rotationEffect(.degrees(-90))
      VStack(spacing: 0) {
        Text(verbatim: percent.map { "\(Int($0.rounded()))%" } ?? "–")
          .font(.system(.callout, design: .rounded).weight(.semibold))
          .minimumScaleFactor(0.7)
          .lineLimit(1)
        Text(verbatim: title)
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .padding(.horizontal, 6)
    }
    .aspectRatio(1, contentMode: .fit)
    .frame(maxWidth: 80, maxHeight: 80)
    .padding(4)
  }
}

// MARK: - Alerts

struct AlertsBody: View {
  let server: WidgetServer
  let document: WidgetDocument
  let family: WidgetFamily

  var body: some View {
    if let alerts = server.alerts {
      if family == .systemSmall {
        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: "\(alerts.count)")
            .font(.system(size: 40, weight: .semibold, design: .rounded))
            .foregroundStyle(alerts.count == 0 ? Color.green : WidgetTint.color(alerts.level))
          Text(verbatim: alerts.summary)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
        }
      } else {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 6) {
            Image(systemName: alerts.count == 0
              ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
              .foregroundStyle(alerts.count == 0 ? Color.green : WidgetTint.color(alerts.level))
            Text(verbatim: alerts.summary)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
          }
          ForEach(
            Array(alerts.items.prefix(family == .systemLarge ? 4 : 2).enumerated()),
            id: \.offset
          ) { _, item in
            HStack(alignment: .top, spacing: 6) {
              Circle()
                .fill(WidgetTint.color(item.level))
                .frame(width: 7, height: 7)
                .padding(.top, 4)
              Text(verbatim: item.text)
                .font(.caption)
                .lineLimit(family == .systemLarge ? 3 : 2)
            }
          }
        }
      }
    } else {
      NoData(document: document)
    }
  }
}

struct NoData: View {
  let document: WidgetDocument

  var body: some View {
    Text(verbatim: document.label("noData", "No data yet. Open the app."))
      .font(.footnote)
      .foregroundStyle(.secondary)
  }
}
