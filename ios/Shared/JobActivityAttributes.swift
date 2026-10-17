import ActivityKit
import Foundation

/// A running TrueNAS job on the lock screen and in the Dynamic Island.
///
/// Compiled into the app (which starts and updates the activity) and into the
/// JobActivityWidget extension (which draws it), so both agree on the type.
@available(iOS 16.2, *)
struct JobActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// What the job is doing now, or why it failed.
    var detail: String
    /// 0 to 1, or nil when the server does not say how far along it is.
    var progress: Double?
    /// waiting, running, done, failed, aborted or stale.
    var status: String
    var statusLabel: String
    /// Shown when the system marks the activity stale: no update for a while.
    var staleLabel: String
  }

  var jobId: String
  /// scrub, replication, appUpdate, cloudSync, cloudBackup, rsync or systemUpdate.
  var kind: String
  var title: String
  var server: String
  var startedAt: Date
}
