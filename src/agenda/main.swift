// agenda-json — prints upcoming calendar events (incl. synced Google calendars) as JSON
// for the Hammerspoon agenda widget. Usage: agenda-json [days=7]
import EventKit
import Foundation

let store = EKEventStore()
let days = Int(CommandLine.arguments.dropFirst().first ?? "") ?? 7

let sem = DispatchSemaphore(value: 0)
var granted = false
store.requestFullAccessToEvents { ok, _ in granted = ok; sem.signal() }
sem.wait()
guard granted else { print(#"{"error":"no-access"}"#); exit(2) }

func hex(_ c: CGColor?) -> String? {
  guard let c = c?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
        let p = c.components, p.count >= 3 else { return nil }
  return String(format: "%02x%02x%02x", Int(p[0] * 255), Int(p[1] * 255), Int(p[2] * 255))
}

let cal = Calendar.current
let from = cal.startOfDay(for: Date())
let to = cal.date(byAdding: .day, value: days, to: from)!
let iso = ISO8601DateFormatter()
let now = Date()

let events: [[String: Any]] = store.events(matching: store.predicateForEvents(withStart: from, end: to, calendars: nil))
  .filter { $0.endDate > now }
  .sorted { $0.startDate < $1.startDate }
  .map { e in
    var d: [String: Any] = ["title": e.title ?? "(untitled)", "start": iso.string(from: e.startDate),
                            "end": iso.string(from: e.endDate), "allDay": e.isAllDay, "calendar": e.calendar.title]
    if let l = e.location, !l.isEmpty { d["location"] = l }
    if let c = hex(e.calendar.cgColor) { d["color"] = c }
    return d
  }

let calendars = store.calendars(for: .event).map { ["title": $0.title, "source": $0.source.title] }
let json = try! JSONSerialization.data(withJSONObject: ["events": events, "calendars": calendars])
print(String(data: json, encoding: .utf8)!)
