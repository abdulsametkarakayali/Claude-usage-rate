import SwiftUI
import AppKit
import Foundation

// MARK: - Model

struct UsageSnapshot {
    var windowStart: Date?
    var windowEnd: Date?
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreateTokens: Int = 0
    var messageCount: Int = 0
    var byModel: [String: Int] = [:]
    var lastRefresh: Date = .now

    var totalBillable: Int { inputTokens + outputTokens + cacheCreateTokens }
    var totalIncludingCache: Int { inputTokens + outputTokens + cacheReadTokens + cacheCreateTokens }
}

// MARK: - Parser

final class UsageTracker: ObservableObject {
    @Published var snapshot = UsageSnapshot()
    @Published var limit: Int = UserDefaults.standard.integer(forKey: "tokenLimit") == 0
        ? 220_000_000
        : UserDefaults.standard.integer(forKey: "tokenLimit")
    @Published var isLoading = false

    private let projectsRoot = ("~/.claude/projects" as NSString).expandingTildeInPath
    private let windowHours: Double = 5
    private var timer: Timer?

    init() {
        setLimit(limit)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func setLimit(_ v: Int) {
        limit = max(0, v)
        UserDefaults.standard.set(limit, forKey: "tokenLimit")
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let snap = self.computeSnapshot()
            DispatchQueue.main.async {
                self.snapshot = snap
                self.isLoading = false
            }
        }
    }

    private func computeSnapshot() -> UsageSnapshot {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(atPath: projectsRoot) else {
            return UsageSnapshot()
        }

        let cutoff = Date().addingTimeInterval(-windowHours * 3600)
        var files: [URL] = []
        for dir in dirs {
            let full = URL(fileURLWithPath: projectsRoot).appendingPathComponent(dir)
            guard let items = try? fm.contentsOfDirectory(at: full, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for item in items where item.pathExtension == "jsonl" {
                let attrs = try? item.resourceValues(forKeys: [.contentModificationDateKey])
                if let mod = attrs?.contentModificationDate, mod >= cutoff.addingTimeInterval(-3600) {
                    files.append(item)
                }
            }
        }

        var earliestInWindow: Date?
        var snap = UsageSnapshot()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoNoFrac = ISO8601DateFormatter()
        isoNoFrac.formatOptions = [.withInternetDateTime]

        for file in files {
            guard let data = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for line in data.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let raw = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { continue }
                guard let ts = obj["timestamp"] as? String else { continue }
                let date = iso.date(from: ts) ?? isoNoFrac.date(from: ts)
                guard let date, date >= cutoff else { continue }
                guard let message = obj["message"] as? [String: Any],
                      let usage = message["usage"] as? [String: Any] else { continue }

                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                let cacheCreate = usage["cache_creation_input_tokens"] as? Int ?? 0
                if input == 0 && output == 0 && cacheRead == 0 && cacheCreate == 0 { continue }

                snap.inputTokens += input
                snap.outputTokens += output
                snap.cacheReadTokens += cacheRead
                snap.cacheCreateTokens += cacheCreate
                snap.messageCount += 1

                let model = (message["model"] as? String) ?? "unknown"
                snap.byModel[model, default: 0] += input + output + cacheCreate

                if earliestInWindow == nil || date < earliestInWindow! {
                    earliestInWindow = date
                }
            }
        }

        if let start = earliestInWindow {
            snap.windowStart = start
            snap.windowEnd = start.addingTimeInterval(windowHours * 3600)
        }
        snap.lastRefresh = .now
        return snap
    }
}

// MARK: - Formatting

func formatTokens(_ n: Int) -> String {
    let d = Double(n)
    if d >= 1_000_000_000 { return String(format: "%.2fB", d / 1_000_000_000) }
    if d >= 1_000_000 { return String(format: "%.2fM", d / 1_000_000) }
    if d >= 1_000 { return String(format: "%.1fK", d / 1_000) }
    return "\(n)"
}

func formatCountdown(_ end: Date?) -> String {
    guard let end else { return "—" }
    let remaining = Int(end.timeIntervalSinceNow)
    if remaining <= 0 { return "sıfırlandı" }
    let h = remaining / 3600
    let m = (remaining % 3600) / 60
    let s = remaining % 60
    return String(format: "%dsa %02ddk %02dsn", h, m, s)
}

func formatClock(_ d: Date?) -> String {
    guard let d else { return "—" }
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: d)
}

// MARK: - UI

struct MenuContent: View {
    @ObservedObject var tracker: UsageTracker
    @State private var now: Date = .now
    @State private var limitText: String = ""
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            progressSection
            Divider()
            breakdownSection
            if !tracker.snapshot.byModel.isEmpty {
                Divider()
                modelsSection
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 320)
        .onReceive(tick) { now = $0 }
        .onAppear { limitText = "\(tracker.limit)" }
    }

    private var header: some View {
        HStack {
            Image(systemName: "cpu")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Claude Token Kullanımı")
                    .font(.system(size: 13, weight: .semibold))
                Text("5 saatlik pencere")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: { tracker.refresh() }) {
                Image(systemName: tracker.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Yenile")
        }
    }

    private var progressSection: some View {
        let used = tracker.snapshot.totalBillable
        let pct = tracker.limit > 0 ? min(1.0, Double(used) / Double(tracker.limit)) : 0
        let color: Color = pct < 0.6 ? .green : pct < 0.85 ? .yellow : .red
        _ = now
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formatTokens(used))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text("/ \(formatTokens(tracker.limit))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(pct * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(color)
            }
            ProgressView(value: pct)
                .tint(color)
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("Sıfırlamaya: \(formatCountdown(tracker.snapshot.windowEnd))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatClock(tracker.snapshot.windowEnd))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var breakdownSection: some View {
        let s = tracker.snapshot
        return VStack(alignment: .leading, spacing: 4) {
            row("Giriş", formatTokens(s.inputTokens))
            row("Çıkış", formatTokens(s.outputTokens))
            row("Cache (yaz)", formatTokens(s.cacheCreateTokens))
            row("Cache (oku)", formatTokens(s.cacheReadTokens))
            row("Mesaj sayısı", "\(s.messageCount)")
        }
    }

    private var modelsSection: some View {
        let sorted = tracker.snapshot.byModel.sorted { $0.value > $1.value }.prefix(5)
        return VStack(alignment: .leading, spacing: 3) {
            Text("Modeller")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(sorted), id: \.key) { pair in
                HStack {
                    Text(shortModel(pair.key))
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                    Text(formatTokens(pair.value))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func shortModel(_ s: String) -> String {
        s.replacingOccurrences(of: "claude-", with: "")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Limit")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                TextField("", text: $limitText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 110)
                    .onSubmit { commitLimit() }
                Text("tok")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Kaydet") { commitLimit() }
                    .controlSize(.small)
            }
            HStack {
                Text("Güncellendi \(formatClock(tracker.snapshot.lastRefresh))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Çık") { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
        }
    }

    private func commitLimit() {
        let v = Int(limitText.filter { $0.isNumber }) ?? tracker.limit
        tracker.setLimit(v)
        limitText = "\(v)"
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
        }
    }
}

// MARK: - App

@main
struct ClaudeTokensApp: App {
    @StateObject private var tracker = UsageTracker()
    @State private var tick: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(tracker: tracker)
        } label: {
            labelView
                .onReceive(timer) { tick = $0 }
        }
        .menuBarExtraStyle(.window)
    }

    private var labelView: some View {
        let used = tracker.snapshot.totalBillable
        let pct = tracker.limit > 0 ? min(1.0, Double(used) / Double(tracker.limit)) : 0
        let icon = pct < 0.6 ? "circle" : pct < 0.85 ? "circle.lefthalf.filled" : "circle.fill"
        _ = tick
        return HStack(spacing: 3) {
            Image(systemName: icon)
            Text(formatTokens(used))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
    }
}
