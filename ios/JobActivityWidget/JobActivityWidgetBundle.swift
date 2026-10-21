import SwiftUI
import WidgetKit

@main
struct JobActivityWidgetBundle: WidgetBundle {
  var body: some Widget {
    JobActivityLiveActivity()
    // Choosing a server for a widget needs iOS 17.
    if #available(iOS 17.0, *) {
      HomeWidgets()
    }
  }
}
