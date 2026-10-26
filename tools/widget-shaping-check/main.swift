import Foundation

// Holds the Swift widget shaping (`WidgetShape` in WidgetFetch.swift) to the
// same file as the Dart one (test/core/widgets/widget_shaping_test.dart): the
// raw answers of a server, and the JSON that must come out of them.
//
//   tools/check-widget-shaping.sh

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(2)
}

/// [value] without the nulls: Dart writes `"percent": null`, Swift leaves the
/// key out.
func withoutNulls(_ value: Any) -> Any {
  if let object = value as? [String: Any] {
    return object.filter { !($0.value is NSNull) }.mapValues(withoutNulls)
  }
  if let list = value as? [Any] { return list.map(withoutNulls) }
  return value
}

func encoded<T: Encodable>(_ value: T) -> Any {
  guard
    let data = try? JSONEncoder().encode(value),
    let object = try? JSONSerialization.jsonObject(with: data)
  else { fail("Could not encode \(value)") }
  return object
}

func text(_ value: Any) -> String {
  guard
    JSONSerialization.isValidJSONObject(value),
    let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted])
  else { return "\(value)" }
  return String(decoding: data, as: UTF8.self)
}

func rows(_ value: Any?) -> [[String: Any]] { (value as? [[String: Any]]) ?? [] }

guard CommandLine.arguments.count == 2 else { fail("usage: shape-check <widget_shaping.json>") }
guard
  let data = FileManager.default.contents(atPath: CommandLine.arguments[1]),
  let fixture = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
  let cases = fixture["cases"] as? [[String: Any]]
else { fail("Could not read the fixture") }

let labels = fixture["labels"] as? [String: String] ?? [:]
let label: (String, String) -> String = { key, fallback in labels[key] ?? fallback }

var failures = 0
for testCase in cases {
  let name = testCase["name"] as? String ?? "?"
  let raw = testCase["raw"] as? [String: Any] ?? [:]
  var shaped: [String: Any] = [
    "pools": encoded(WidgetShape.pools(rows(raw["pools"]), label: label)),
    "alerts": encoded(WidgetShape.alerts(rows(raw["alerts"]), label: label)),
    "jobs": encoded(WidgetShape.jobs(rows(raw["jobs"]), label: label)),
    "apps": encoded(WidgetShape.apps(rows(raw["apps"]), label: label)),
  ]
  if let realtime = raw["realtime"] as? [String: Any] {
    shaped["system"] = encoded(WidgetShape.system(realtime, label: label))
  }
  let have = text(withoutNulls(shaped))
  let want = text(withoutNulls(testCase["expected"] ?? [:]))
  if have == want {
    print("ok   \(name)")
  } else {
    failures += 1
    print("FAIL \(name)\n--- expected\n\(want)\n--- Swift made\n\(have)")
  }
}
exit(failures == 0 ? 0 : 1)
