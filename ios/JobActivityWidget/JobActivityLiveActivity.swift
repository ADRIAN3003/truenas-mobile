import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity of a running job: lock screen card, Dynamic Island.
struct JobActivityLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: JobActivityAttributes.self) { context in
      JobLockScreenView(
        attributes: context.attributes,
        state: context.state,
        isStale: context.isStale
      )
      .padding(16)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          JobIcon(kind: context.attributes.kind, status: context.state.status)
            .font(.title2)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(JobStyle.percent(context.state.progress, status: context.state.status))
            .font(.title3.monospacedDigit().weight(.semibold))
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.attributes.title).font(.headline).lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            JobProgress(
              progress: context.state.progress,
              status: context.state.status,
              isStale: context.isStale
            )
            Text(JobStyle.detail(context.state, isStale: context.isStale))
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      } compactLeading: {
        JobIcon(kind: context.attributes.kind, status: context.state.status)
      } compactTrailing: {
        Text(JobStyle.percent(context.state.progress, status: context.state.status))
          .monospacedDigit()
      } minimal: {
        JobIcon(kind: context.attributes.kind, status: context.state.status)
      }
    }
  }
}

struct JobLockScreenView: View {
  let attributes: JobActivityAttributes
  let state: JobActivityAttributes.ContentState
  let isStale: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        JobIcon(kind: attributes.kind, status: state.status)
          .font(.title2)
        VStack(alignment: .leading, spacing: 2) {
          Text(attributes.title).font(.headline).lineLimit(1)
          Text(attributes.server).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        Spacer()
        Text(JobStyle.percent(state.progress, status: state.status))
          .font(.title3.monospacedDigit().weight(.semibold))
      }
      JobProgress(progress: state.progress, status: state.status, isStale: isStale)
      Text(JobStyle.detail(state, isStale: isStale))
        .font(.caption)
        .foregroundStyle(isStale || state.status == "stale" ? .orange : .secondary)
        .lineLimit(2)
    }
  }
}

struct JobProgress: View {
  let progress: Double?
  let status: String
  let isStale: Bool

  var body: some View {
    if let progress = progress {
      ProgressView(value: min(max(progress, 0), 1))
        .tint(JobStyle.tint(status: status, isStale: isStale))
    } else if status == "done" || status == "failed" || status == "aborted" {
      ProgressView(value: status == "done" ? 1 : 0)
        .tint(JobStyle.tint(status: status, isStale: isStale))
    } else {
      // The server does not say how far along the job is.
      ProgressView()
        .progressViewStyle(.linear)
        .tint(JobStyle.tint(status: status, isStale: isStale))
    }
  }
}

struct JobIcon: View {
  let kind: String
  let status: String

  var body: some View {
    Image(systemName: JobStyle.symbol(kind: kind, status: status))
      .foregroundStyle(JobStyle.tint(status: status, isStale: false))
  }
}

enum JobStyle {
  static func symbol(kind: String, status: String) -> String {
    switch status {
    case "done": return "checkmark.circle.fill"
    case "failed": return "exclamationmark.triangle.fill"
    case "aborted": return "xmark.circle.fill"
    default: break
    }
    switch kind {
    case "scrub": return "checkmark.shield"
    case "replication": return "arrow.left.arrow.right"
    case "appUpdate": return "arrow.down.app"
    case "cloudSync", "cloudBackup": return "icloud"
    case "rsync": return "arrow.triangle.2.circlepath"
    default: return "arrow.down.circle"
    }
  }

  static func tint(status: String, isStale: Bool) -> Color {
    if isStale || status == "stale" { return .orange }
    switch status {
    case "done": return .green
    case "failed": return .red
    case "aborted": return .gray
    default: return .blue
    }
  }

  static func percent(_ progress: Double?, status: String) -> String {
    if status == "done" { return "100%" }
    guard let progress = progress, status != "failed", status != "aborted" else { return "" }
    return "\(Int((min(max(progress, 0), 1) * 100).rounded()))%"
  }

  /// What the job is doing, or that the app stopped following it.
  static func detail(_ state: JobActivityAttributes.ContentState, isStale: Bool) -> String {
    isStale && state.status != "stale" ? state.staleLabel : state.detail
  }
}
