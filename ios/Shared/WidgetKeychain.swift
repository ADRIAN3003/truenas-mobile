import Foundation
import Security

/// The sign-in details of the saved servers, in a Keychain group that the app
/// and the widget extension share. The widgets fetch their own data (the phone
/// does not wake the app often enough to do it for them), so they need these.
///
/// The app writes (`WidgetCredentialsPlugin`), the extension reads. The group
/// is `<team prefix>hu.adrian.truenasmobile.shared`, declared in both
/// entitlements files; the team prefix reaches the code as `AppIdentifierPrefix`
/// in both Info.plists. An install a sideloading tool re-signed has no such
/// group: saving then fails, and the widgets show what the app last saved.
enum WidgetKeychain {
  static let service = "hu.adrian.truenasmobile.widget"
  static let account = "credentials.v1"

  /// Nil when the build has no team prefix (an unsigned build).
  static var accessGroup: String? {
    guard
      let prefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String,
      !prefix.isEmpty, !prefix.contains("$")
    else { return nil }
    return prefix + "hu.adrian.truenasmobile.shared"
  }

  private static func match(_ group: String) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account,
      kSecAttrAccessGroup: group,
    ]
  }

  /// True when the details are stored.
  static func save(_ data: Data) -> Bool {
    guard let group = accessGroup else { return false }
    // Readable after the first unlock: a widget refreshes while the phone is
    // locked. Never leaves this phone.
    let attributes: [CFString: Any] = [
      kSecValueData: data,
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    var status = SecItemUpdate(match(group) as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      let item = match(group).merging(attributes) { _, new in new }
      status = SecItemAdd(item as CFDictionary, nil)
    }
    return status == errSecSuccess
  }

  static func load() -> Data? {
    guard let group = accessGroup else { return nil }
    var query = match(group)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
    return result as? Data
  }

  static func delete() {
    guard let group = accessGroup else { return }
    SecItemDelete(match(group) as CFDictionary)
  }
}
