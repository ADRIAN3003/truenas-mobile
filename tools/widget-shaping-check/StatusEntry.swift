import Foundation

// Stands in for the widget extension's `StatusEntry` (HomeWidgets.swift, which
// needs WidgetKit and SwiftUI): `WidgetFetch.swift` only builds one.
struct StatusEntry {
  let date: Date
  let document: WidgetDocument?
  let server: WidgetServer?
  let groupAvailable: Bool

  static func current(serverId: String?, preview: Bool = false) -> StatusEntry {
    StatusEntry(date: Date(), document: nil, server: nil, groupAvailable: false)
  }
}
