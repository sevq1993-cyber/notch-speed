// ClaudeSpeed — generation speed of Claude Code and Codex beside the MacBook notch (status items elsewhere).
// Polls `collect.py --menu-json` (3 s while generating, 10 s idle). No third-party deps, plain swiftc.
import AppKit

enum DotLogo {
    static let patterns: [String: [String]] = [
        "claude": [
            ".....#.....", ".#...#...#.", "..#..#..#..", "...#.#.#...",
            "....###....", "###########", "....###....", "...#.#.#...",
            "..#..#..#..", ".#...#...#.", ".....#.....",
        ],
        "codex": [
            "..#######..", ".#.......#.", "#.........#", "#.#.......#",
            "#..#......#", "#...#.....#", "#..#......#", "#.#..####.#",
            "#.........#", ".#.......#.", "..#######..",
        ],
    ]
    static let lamps: Set<Character> = ["🟢", "🟡", "🔴", "⚪"]
    static let claudeColor = NSColor(srgbRed: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0, alpha: 1)
    static let codexFrom = NSColor(srgbRed: 0x4F / 255.0, green: 0x7C / 255.0, blue: 0xFF / 255.0, alpha: 1)
    static let codexTo = NSColor(srgbRed: 0xA3 / 255.0, green: 0x5C / 255.0, blue: 0xFF / 255.0, alpha: 1)
    static let dimAlpha: CGFloat = 0.22

    // dots sorted from the center outwards, ties broken clockwise from 12 o'clock
    static let dots: [String: [(Int, Int)]] = patterns.mapValues { rows in
        let c = Double(rows.count - 1) / 2
        var pts: [(Int, Int)] = []
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" { pts.append((x, y)) }
        }
        func key(_ p: (Int, Int)) -> Double {
            let dx = Double(p.0) - c, dy = Double(p.1) - c
            var a = atan2(dx, -dy)
            if a < 0 { a += 2 * .pi }
            return (dx * dx + dy * dy).squareRoot() + a * 1e-3
        }
        return pts.sorted { key($0) < key($1) }
    }

    static func color(_ src: String, x: Int, y: Int, n: Int) -> NSColor {
        if src == "claude" { return claudeColor }
        let t = CGFloat(x + y) / CGFloat(2 * (n - 1))
        return codexFrom.blended(withFraction: t, of: codexTo) ?? codexFrom
    }

    // phase < 0: static (full logo when lit, all dim otherwise); 0..<1: draw on, then erase in the same order
    static var cache: [String: NSImage] = [:]

    static func image(_ src: String, size: CGFloat, phase: Double, lit: Bool, mono: NSColor? = nil) -> NSImage? {
        guard let order = dots[src] else { return nil }
        let steps = 2 * order.count
        let step = phase < 0 ? (lit ? -1 : -2) : Int(phase * Double(steps))
        let key = "\(src)/\(size)/\(step)/\(mono?.description ?? "")"
        if let img = cache[key] { return img }
        let img = draw(src, size: size, phase: phase < 0 ? -1 : Double(step) / Double(steps), lit: lit, mono: mono)
        cache[key] = img
        return img
    }

    static func draw(_ src: String, size: CGFloat, phase: Double, lit: Bool, mono: NSColor? = nil) -> NSImage? {
        guard let rows = patterns[src], let order = dots[src] else { return nil }
        let n = rows.count, total = Double(order.count)
        let cell = size / CGFloat(n), px = cell * 2 / 3
        return NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            for (i, p) in order.enumerated() {
                let pos = Double(i) / total
                let on: Bool
                if phase < 0 {
                    on = lit
                } else {
                    let q = phase * 2
                    on = q < 1 ? pos < q : pos >= q - 1
                }
                let col = mono ?? color(src, x: p.0, y: p.1, n: n)
                (on ? col : col.withAlphaComponent(dimAlpha)).setFill()
                NSRect(x: CGFloat(p.0) * cell, y: CGFloat(p.1) * cell, width: px, height: px).fill()
            }
            return true
        }
    }

    struct Line {
        var src = "", live = false, text = "", tps: Double? = nil
    }

    // tps is the number right after the speed lamp (≈/≥ allowed)
    static func line(src: String, live: Bool = false, text: String = "⚪") -> Line {
        var l = Line(src: src, live: live, text: text)
        if let i = l.text.firstIndex(where: { lamps.contains($0) }) {
            let digits = l.text[l.text.index(after: i)...]
                .drop(while: { $0 == " " || $0 == "≈" || $0 == "≥" })
                .prefix(while: { $0.isNumber })
            l.tps = Double(digits)
        }
        return l
    }

    // one full draw+erase cycle: 120/tps seconds (100 tok/s → 1.2 s)
    static func phase(_ l: Line, at t: TimeInterval) -> Double {
        guard l.live, let tps = l.tps, tps > 0 else { return -1 }
        let period = 120 / tps
        return t.truncatingRemainder(dividingBy: period) / period
    }
}

enum DotFont {
    static let glyphs: [Character: [String]] = [
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
        "≈": [".....", ".##.#", "#..#.", ".....", ".##.#", "#..#.", "....."],
        "≥": ["#....", ".##..", "...##", ".##..", "#....", ".....", "#####"],
        "Σ": ["#####", "#....", ".#...", "..#..", ".#...", "#....", "#####"],
        "⚠": ["...#...", "..#.#..", "..#.#..", ".#.#.#.", ".#...#.", "#..#..#", "#######"],
        "🤖": ["...#...", ".#####.", "#.....#", "#.#.#.#", "#.....#", ".#####.", ".#...#."],
        " ": ["..", "..", "..", "..", "..", "..", ".."],
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        ".": [".", ".", ".", ".", ".", ".", "#"],
        "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
        "🔒": [".###.", "#...#", "#...#", "#####", "##.##", "##.##", "#####"],
        "✓": ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#....", "......."],
        "✕": ["#.....#", ".#...#.", "..#.#..", "...#...", "..#.#..", ".#...#.", "#.....#"],
    ]

    // glyphs drawn in their own color instead of the label color
    static let tints: [Character: NSColor] = ["🔒": NSColor(srgbRed: 0xEF / 255.0, green: 0x9F / 255.0, blue: 0x27 / 255.0, alpha: 1)]

    static var frames: [String: NSImage] = [:]

    static func width(_ text: String, cell: CGFloat) -> CGFloat {
        let cols = text.compactMap { glyphs[$0]?[0].count }
        return CGFloat(cols.reduce(0, +) + max(0, cols.count - 1)) * cell
    }

    // draws glyphs straight into the current (flipped) context; used by the hover card
    static func draw(_ text: String, at p: NSPoint, cell: CGFloat, color: NSColor) {
        color.setFill()
        var x = p.x
        for ch in text {
            guard let g = glyphs[ch] else { continue }
            for (y, row) in g.enumerated() {
                for (cx, c) in row.enumerated() where c == "#" {
                    NSRect(x: x + CGFloat(cx) * cell, y: p.y + CGFloat(y) * cell, width: cell * 3 / 4, height: cell * 3 / 4).fill()
                }
            }
            x += CGFloat(g[0].count + 1) * cell
        }
    }

    // frames are rasterized once per (title, animation step, appearance) and reused
    static func cachedTitle(_ l: DotLogo.Line, size: CGFloat, phase: Double, dark: Bool) -> NSImage {
        let steps = 2 * (DotLogo.dots[l.src]?.count ?? 1)
        let step = phase < 0 ? -1 : Int(phase * Double(steps))
        let id = "\(l.src)|\(l.live)|\(l.text)|\(dark)|\(step)"
        if frames.count > 600 { frames = [:] }
        if let img = frames[id] { return img }
        let vec = title(l, size: size, phase: step < 0 ? -1 : Double(step) / Double(steps))
        let scale: CGFloat = 2
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(vec.size.width * scale), pixelsHigh: Int(size * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = vec.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
            vec.draw(in: NSRect(origin: .zero, size: vec.size))
        }
        NSGraphicsContext.restoreGraphicsState()
        let img = NSImage(size: vec.size)
        img.addRepresentation(rep)
        frames[id] = img
        return img
    }

    // the whole title as one dot-matrix image: brand logo (animated) + glyphs in the label color
    static func title(_ l: DotLogo.Line, size: CGFloat, phase: Double) -> NSImage {
        let rows = 11, cell = size / CGFloat(rows), px = cell * 2 / 3
        let logo = DotLogo.image(l.src, size: size, phase: phase, lit: l.tps != nil)
        var cols: [(Character, Int)] = []
        var logoAt: Int? = nil
        var x = 0
        for ch in l.text {
            if DotLogo.lamps.contains(ch), logo != nil, logoAt == nil {
                logoAt = x
                x += rows + 2
                continue
            }
            let g = ch.unicodeScalars.first.map { Character($0) } ?? ch
            guard let pat = glyphs[g] else { continue }
            cols.append((g, x))
            x += pat[0].count + 1
        }
        let width = max(CGFloat(x - 1) * cell, cell)
        return NSImage(size: NSSize(width: width, height: size), flipped: true) { _ in
            if let at = logoAt, let logo {
                logo.draw(in: NSRect(x: CGFloat(at) * cell, y: 0, width: size, height: size))
            }
            let top = (rows - 7) / 2
            for (g, gx) in cols {
                (tints[g] ?? .labelColor).setFill()
                for (y, row) in glyphs[g]!.enumerated() {
                    for (cx, ch) in row.enumerated() where ch == "#" {
                        NSRect(x: CGFloat(gx + cx) * cell, y: CGFloat(top + y) * cell, width: px, height: px).fill()
                    }
                }
            }
            return true
        }
    }
}

enum Table {
    static let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize, weight: .regular)
    static let small = NSFont.systemFont(ofSize: 11)

    static func para(_ cols: [CGFloat]) -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.tabStops = cols.map { NSTextTab(textAlignment: .right, location: $0) }
        ps.lineBreakMode = .byClipping
        return ps
    }

    // section header, column header and one line per session, aligned with right tab stops
    static func lines(src: String, name: String, rows: [[String: Any]], cols: [CGFloat], maxLabel: Int) -> [NSAttributedString] {
        let ps = para(cols)
        let base: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: ps, .foregroundColor: NSColor.labelColor]
        let dim = base.merging([.foregroundColor: NSColor.secondaryLabelColor]) { $1 }
        var out: [NSAttributedString] = []

        let h = NSMutableAttributedString()
        if let logo = DotLogo.image(src, size: 14, phase: -1, lit: true) {
            let att = NSTextAttachment()
            att.image = logo
            att.bounds = NSRect(x: 0, y: (font.capHeight - 14) / 2, width: 14, height: 14)
            h.append(NSAttributedString(attachment: att))
        }
        h.append(NSAttributedString(string: "  " + name, attributes: base.merging([
            .font: NSFont.boldSystemFont(ofSize: font.pointSize)]) { $1 }))
        let n = rows.count
        h.append(NSAttributedString(string: "\t" + sessionCount(n), attributes: dim))
        h.addAttribute(.paragraphStyle, value: para([cols.last!]), range: NSRange(location: 0, length: h.length))
        out.append(h)

        if rows.isEmpty {
            out.append(NSAttributedString(string: noSessions, attributes: dim))
            return out
        }
        out.append(NSAttributedString(string: "project · model\tspeed\tTTFT\tcache\twhen", attributes: [
            .font: small, .foregroundColor: NSColor.tertiaryLabelColor, .paragraphStyle: ps]))
        for r in rows { out.append(row(r, base: base, dim: dim, maxLabel: maxLabel)) }
        return out
    }

    static func row(_ r: [String: Any], base: [NSAttributedString.Key: Any], dim: [NSAttributedString.Key: Any], maxLabel: Int) -> NSAttributedString {
        let s = NSMutableAttributedString()
        func add(_ t: String, _ a: [NSAttributedString.Key: Any]) { s.append(NSAttributedString(string: t, attributes: a)) }
        let warn = base.merging([.foregroundColor: NSColor.systemYellow]) { $1 }
        let bad = base.merging([.foregroundColor: NSColor.systemRed]) { $1 }
        var label = r["label"] as? String ?? ""
        if label.count > maxLabel { label = String(label.prefix(maxLabel - 1)) + "…" }
        add(label, base)
        if let m = r["model"] as? String, !m.isEmpty { add("  " + m, dim) }
        if let a = r["agents"] as? Int, a > 0 { add("  🤖\(a)", dim) }
        if let e = r["errs"] as? Int, e > 0 { add("  ⚠️\(e)", bad) }
        if let tps = r["tps"] as? Int {
            let pre = (r["lower"] as? Bool ?? false) ? "≥" : (r["approx"] as? Bool ?? false) ? "≈" : ""
            add("\t\(pre)\(tps) tok/s", base)
        } else {
            add("\t" + (r["status"] as? String ?? "—"), dim)
        }
        if let t = r["ttft"] as? Double { add("\t\(Int(t.rounded())) s", base) } else { add("\t—", dim) }
        if let c = r["cache"] as? Int {
            add("\t\(c)%" + ((r["cold"] as? Bool ?? false) ? "❄" : ""), base)
        } else { add("\t—", dim) }
        if let w = r["wait"] as? Int {
            add("\twaiting \(w)s", warn)
        } else {
            add("\t" + (r["ago"] as? String ?? "—"), dim)
        }
        return s
    }
}

// subscription windows (5-hour / weekly) as pixel meters: brand color, red once 80% is used
enum Limits {
    static func color(_ pct: Int, brand: NSColor) -> NSColor { pct >= 80 ? .systemRed : brand }

    // ear meters: closed, one column per window, 6 cells tall; open, one row per window (see NotchView.layoutMeters)
    static let rows = 6, cell: CGFloat = 2.5, openStep: CGFloat = 3.5
    static func earWidth(_ n: Int) -> CGFloat { n == 0 ? 0 : CGFloat(2 * n - 1) * cell }
    static func lit(_ pct: Int, of n: Int) -> Int { pct > 0 ? max(1, Int((Double(pct) / 100 * Double(n)).rounded())) : 0 }
}


let noSessions = "no active sessions in 2 h"

func plural(_ n: Int, _ one: String, _ many: String) -> String { "\(n) " + (n == 1 ? one : many) }

// 950, 8.2K, 640K, 1.8M, 18M
func compactCount(_ n: Int) -> String {
    func f(_ v: Double, _ u: String) -> String { v < 10 ? String(format: "%.1f%@", v, u) : "\(Int(v.rounded()))\(u)" }
    return n < 1000 ? "\(n)" : n < 1_000_000 ? f(Double(n) / 1000, "K") : f(Double(n) / 1_000_000, "M")
}

func sessionCount(_ n: Int) -> String {
    plural(n, "session", "sessions")
}

let providers: [(src: String, name: String)] = [("claude", "Claude"), ("codex", "Codex")]

// which providers have a process alive (desktop app or CLI); libproc keeps this in-process and cheap
enum Running {
    static let names: [String: Set<String>] = ["claude": ["Claude", "claude"], "codex": ["codex"]]

    static func scan() -> Set<String> {
        let n = proc_listallpids(nil, 0)
        guard n > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(n) + 64)
        let got = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        var found: Set<String> = []
        var buf = [CChar](repeating: 0, count: 64)
        for pid in pids.prefix(Int(max(got, 0))) where pid > 0 {
            guard proc_name(pid, &buf, UInt32(buf.count)) > 0 else { continue }
            let name = String(cString: buf)
            for (src, set) in names where set.contains(name) { found.insert(src) }
            if found.count == names.count { break }
        }
        return found
    }
}

// fallback for screens without a notch: one status-bar item per provider
final class ProviderItem {
    let src: String
    let name: String
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let frameLayer = CALayer()
    var line: DotLogo.Line
    var lastFrame: NSImage? = nil
    var lastSize = NSSize.zero
    var dirty = true

    init(src: String, name: String) {
        self.src = src
        self.name = name
        line = DotLogo.line(src: src)
    }

    deinit { NSStatusBar.system.removeStatusItem(statusItem) }

    func draw() {
        guard let button = statusItem.button else { return }
        let ph = DotLogo.phase(line, at: Date().timeIntervalSinceReferenceDate)
        let dark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let frame = DotFont.cachedTitle(line, size: 16.5, phase: ph, dark: dark)
        if !dirty && frame === lastFrame { return }
        dirty = false
        lastFrame = frame
        // swap layer contents instead of button.image: no status-bar relayout per frame
        if frame.size != lastSize {
            lastSize = frame.size
            button.title = ""
            button.image = NSImage(size: frame.size)
            button.wantsLayer = true
            if frameLayer.superlayer == nil { button.layer?.addSublayer(frameLayer) }
            button.layoutSubtreeIfNeeded()
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let b = button.bounds
        frameLayer.frame = NSRect(
            x: ((b.width - frame.size.width) / 2).rounded(), y: ((b.height - frame.size.height) / 2).rounded(),
            width: frame.size.width, height: frame.size.height)
        frameLayer.contentsScale = 2
        frameLayer.contents = frame.cgImage(forProposedRect: nil, context: nil, hints: nil)
        CATransaction.commit()
    }

    func update(_ p: [String: Any]) {
        line = DotLogo.line(src: src, live: p["live"] as? Bool ?? false, text: p["title"] as? String ?? "⚪")
        dirty = true
        draw()
        let menu = NSMenu()
        menu.autoenablesItems = false
        for l in Table.lines(src: src, name: name, rows: p["rows"] as? [[String: Any]] ?? [],
                             cols: [330, 385, 440, 520], maxLabel: 22) {
            let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            item.attributedTitle = l
            item.isEnabled = true
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ClaudeSpeed", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
}

// permission requests from permission-hook.py: <id>.json in, <id>.answer ("allow"/"deny"/"pass") out.
// While the app hosting the session is in front the request is passed to the chat's own dialog at once and
// stays here only as a reminder ("state": "chat") until its tool_result shows up in the transcript.
final class Permissions {
    static let dir = (NSHomeDirectory() as NSString).appendingPathComponent(".cache/claude-speed/permissions")
    static let pidFile = (NSHomeDirectory() as NSString).appendingPathComponent(".cache/claude-speed/app.pid")
    private(set) var items: [[String: Any]] = []
    var onChange: (([[String: Any]]) -> Void)?
    private var source: DispatchSourceFileSystemObject?
    private var clock: Timer?  // while something waits: countdown, expiry, reminder checks
    private var reminders: [String: [String: Any]] = [:]
    private var activation: NSObjectProtocol?
    static let reminderTTL: Double = 15 * 60

    init() {
        try? FileManager.default.createDirectory(atPath: Self.dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        let fd = open(Self.dir, O_EVTONLY)
        if fd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
            src.setEventHandler { [weak self] in self?.scan() }
            src.setCancelHandler { close(fd) }
            src.resume()
            source = src
        }
        // switching into the session's app hands a waiting request over to the chat
        activation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.scan() }
        scan()
    }

    deinit {
        source?.cancel()
        clock?.invalidate()
        if let a = activation { NSWorkspace.shared.notificationCenter.removeObserver(a) }
    }

    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func hostInFront(_ r: [String: Any]) -> Bool {
        guard let host = r["host"] as? String, !host.isEmpty else { return false }
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == host
    }

    // the chat answered once the transcript holds the result of this request's tool_use. The tool_use is found by
    // tool and input (it can land in the transcript after the hook ran); only the transcript tail is read.
    static func answered(_ r: [String: Any]) -> Bool {
        guard let path = r["transcript"] as? String, let fh = FileHandle(forReadingAtPath: path) else { return false }
        defer { try? fh.close() }
        let end = (try? fh.seekToEnd()) ?? 0
        try? fh.seek(toOffset: end > 262_144 ? end - 262_144 : 0)
        let data = (try? fh.readToEnd()) ?? Data()
        let tool = r["tool"] as? String ?? "", want = r["text"] as? String ?? ""
        // the same command may have run before in this chat: only a tool_use from just before the request counts
        let since = (r["created"] as? Double ?? 0) - 30
        var id: String?
        for line in data.split(separator: UInt8(ascii: "\n")).reversed() where id == nil {
            guard line.range(of: Data("\"tool_use\"".utf8)) != nil,
                  let rec = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any],
                  let blocks = (rec["message"] as? [String: Any])?["content"] as? [[String: Any]] else { continue }
            guard let ts = (rec["timestamp"] as? String).flatMap(Self.iso.date(from:)),
                  ts.timeIntervalSince1970 >= since else { break }
            for b in blocks.reversed() where b["type"] as? String == "tool_use" && b["name"] as? String == tool {
                let input = b["input"] as? [String: Any] ?? [:]
                let keys = ["command", "file_path", "notebook_path", "url", "pattern", "path"]
                let text = keys.lazy.compactMap { input[$0].map { "\($0)" } }.first
                if text == nil || text == want {
                    id = b["id"] as? String
                    break
                }
            }
        }
        guard let id else { return false }
        return data.range(of: Data("\"tool_use_id\":\"\(id)\"".utf8)) != nil
    }

    // the hook only waits for an app that announced itself
    static func announce(_ on: Bool) {
        if on {
            try? "\(getpid())".write(toFile: pidFile, atomically: true, encoding: .utf8)
        } else if (try? String(contentsOfFile: pidFile, encoding: .utf8)) == "\(getpid())" {
            try? FileManager.default.removeItem(atPath: pidFile)
        }
    }

    func scan() {
        let now = Date().timeIntervalSince1970
        let names = (try? FileManager.default.contentsOfDirectory(atPath: Self.dir)) ?? []
        var asks = names.filter { $0.hasSuffix(".json") }.compactMap { name -> [String: Any]? in
            let path = (Self.dir as NSString).appendingPathComponent(name)
            guard let d = FileManager.default.contents(atPath: path),
                  let r = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                  (r["expires"] as? Double ?? 0) > now,
                  !FileManager.default.fileExists(atPath: path.replacingOccurrences(of: ".json", with: ".answer"))
            else { return nil }
            return r
        }
        for r in asks where Self.hostInFront(r) { pass(r) }
        asks.removeAll { reminders[$0["id"] as? String ?? ""] != nil }
        reminders = reminders.filter { _, r in
            now - (r["created"] as? Double ?? 0) < Self.reminderTTL && !Self.answered(r)
        }
        items = (asks + reminders.values).sorted { ($0["created"] as? Double ?? 0) < ($1["created"] as? Double ?? 0) }
        if items.isEmpty {
            clock?.invalidate()
            clock = nil
        } else if clock == nil {
            clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.scan() }
        }
        onChange?(items)
    }

    // the user is looking at the session's own app: let Claude Code show its dialog, keep a reminder here
    private func pass(_ r: [String: Any]) {
        guard let id = r["id"] as? String else { return }
        let path = (Self.dir as NSString).appendingPathComponent(id + ".answer")
        try? "pass".write(toFile: path, atomically: true, encoding: .utf8)
        var rem = r
        rem["state"] = "chat"
        reminders[id] = rem
    }

    func answer(_ id: String, allow: Bool) {
        let path = (Self.dir as NSString).appendingPathComponent(id + ".answer")
        try? (allow ? "allow" : "deny").write(toFile: path, atomically: true, encoding: .utf8)
        scan()
    }
}

// hover card, scoreboard rows: chat title over a mono details line, mini speed history and LED speed on the right
final class TilesView: NSView {
    var sections: [(src: String, name: String, rows: [[String: Any]])] = [] { didSet { needsDisplay = true } }
    // rows that open their chat, in this view's flipped coordinates; filled while drawing
    private(set) var links: [(rect: NSRect, url: URL)] = []
    var hoverRow: Int? = nil
    // permission requests on top of the Claude section; their buttons are hit-tested like links
    var pending: [[String: Any]] = []
    var today: [String: [String: Int]] = [:]  // per provider: output tokens ("out") and responses ("n") since midnight
    var hold: (id: String, lit: Int)? = nil
    var hoverButton: Int? = nil
    private(set) var buttons: [(rect: NSRect, id: String, action: String)] = []
    static let cmdFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
    static let cmdLine: CGFloat = 13, cmdMaxLines = 3, holdCells = 10
    // same idea as DANGER in permission-hook.py: the parts worth a second look
    static let danger = try! NSRegularExpression(
        pattern: #"\brm\s+(-\w+\s+)*|\s-delete\b|--force\b|\s-f\b|\breset\s+--hard\b|\bsudo\b|\bmkfs\S*|\bdd\s|\bchmod\s+-R|\bchown\s+-R|\bkill(all)?\b|>\s*/dev/\S+|\btruncate\b|\bdrop\s+(table|database)\b|\bdocker\s+(rm|rmi|system\s+prune)\b"#,
        options: [.caseInsensitive])
    static let pad: CGFloat = 14, headH: CGFloat = 26, rowH: CGFloat = 40, sepH: CGFloat = 14, emptyH: CGFloat = 20
    static let digitCell: CGFloat = 2.6, histCell: CGFloat = 3.5, histRows = 7

    override var isFlipped: Bool { true }

    static func height(_ sections: [(src: String, name: String, rows: [[String: Any]])],
                       pending: [[String: Any]] = [], width: CGFloat = 0) -> CGFloat {
        var h = pad - 2
        for (i, s) in sections.enumerated() {
            if i > 0 { h += sepH }
            let asks = pending.filter { ($0["src"] as? String) == s.src }
            h += headH + asks.reduce(0) { $0 + pendingHeight($1, width: width) }
            h += s.rows.isEmpty ? (asks.isEmpty ? emptyH : 0) : CGFloat(s.rows.count) * rowH
        }
        return h + pad
    }

    static func brand(_ src: String) -> NSColor {
        src == "claude" ? DotLogo.claudeColor
            : (DotLogo.codexFrom.blended(withFraction: 0.45, of: DotLogo.codexTo) ?? DotLogo.codexFrom)
    }

    func button(at p: NSPoint) -> (index: Int, id: String, action: String)? {
        buttons.firstIndex { $0.rect.contains(p) }.map { ($0, buttons[$0].id, buttons[$0].action) }
    }

    // the command wraps under the title, up to cmdMaxLines lines
    static func cmdText(_ p: [String: Any], color: NSColor) -> NSAttributedString {
        let str = p["text"] as? String ?? ""
        let ps = NSMutableParagraphStyle()
        ps.lineBreakMode = .byCharWrapping
        ps.minimumLineHeight = cmdLine
        ps.maximumLineHeight = cmdLine
        let s = NSMutableAttributedString(string: str, attributes: [.font: cmdFont, .foregroundColor: color, .paragraphStyle: ps])
        if p["tool"] as? String == "Bash" {
            for m in danger.matches(in: str, range: NSRange(str.startIndex..., in: str)) {
                s.addAttribute(.foregroundColor, value: NSColor.systemRed, range: m.range)
            }
        }
        return s
    }

    static func cmdWidth(_ width: CGFloat) -> CGFloat { width - 2 * pad + 12 - 2 * askInset }
    static let askInset: CGFloat = 13, ledCell: CGFloat = 1.8, frameStep: CGFloat = 6, frameDot: CGFloat = 2.5

    static func cmdLines(_ p: [String: Any], width: CGFloat) -> Int {
        let h = cmdText(p, color: .labelColor).boundingRect(with: NSSize(width: max(cmdWidth(width), 50), height: 1000),
                                                         options: [.usesLineFragmentOrigin]).height
        return min(cmdMaxLines, max(1, Int((h / cmdLine).rounded(.up))))
    }

    static func pendingHeight(_ p: [String: Any], width: CGFloat) -> CGFloat {
        52 + CGFloat(cmdLines(p, width: width)) * cmdLine + 14
    }

    func link(at p: NSPoint) -> (index: Int, url: URL)? {
        links.firstIndex { $0.rect.contains(p) }.map { ($0, links[$0].url) }
    }

    override func draw(_ dirtyRect: NSRect) {
        links = []
        buttons = []
        let w = bounds.width
        var y = Self.pad - 2
        let sec = NSColor.secondaryLabelColor
        for (i, s) in sections.enumerated() {
            if i > 0 { y += Self.sepH }
            DotLogo.image(s.src, size: 14, phase: -1, lit: true)?.draw(
                in: NSRect(x: Self.pad, y: y + 3, width: 14, height: 14), from: .zero, operation: .sourceOver,
                fraction: 1, respectFlipped: true, hints: nil)
            DotFont.draw(s.name.uppercased(), at: NSPoint(x: Self.pad + 22, y: y + 3), cell: 2, color: .labelColor)
            // the limits live in the ears; the header sums up today: a large brand-colored count, then two small
            // dim lines "tok today" / "142 responses" so the eye lands on the one number
            if let t = today[s.src], let out = t["out"], let n = t["n"], n > 0 {
                let small = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
                let l1 = text("tok today", small, sec), l2 = text(plural(n, "response", "responses"), small, sec)
                let tw = max(l1.size().width, l2.size().width)
                var x = w - Self.pad - tw
                l1.draw(at: NSPoint(x: x, y: y + 1))
                l2.draw(at: NSPoint(x: x, y: y + 11))
                let num = compactCount(out)
                x -= DotFont.width(num, cell: 2) + 6
                DotFont.draw(num, at: NSPoint(x: x, y: y + 3), cell: 2, color: Self.brand(s.src))
            } else {
                let cnt = text(sessionCount(s.rows.count), .systemFont(ofSize: 11.5), sec)
                cnt.draw(at: NSPoint(x: w - Self.pad - cnt.size().width, y: y + 2))
            }
            y += Self.headH
            let asks = pending.filter { ($0["src"] as? String) == s.src }
            for p in asks {
                let h = Self.pendingHeight(p, width: w)
                ask(p, rect: NSRect(x: Self.pad - 6, y: y, width: w - 2 * Self.pad + 12, height: h), col: Self.brand(s.src))
                y += h
            }
            if s.rows.isEmpty && !asks.isEmpty { continue }
            if s.rows.isEmpty {
                text(noSessions, .systemFont(ofSize: 12), sec).draw(at: NSPoint(x: Self.pad, y: y))
                y += Self.emptyH
                continue
            }
            for r in s.rows {
                let rect = NSRect(x: Self.pad - 6, y: y, width: w - 2 * Self.pad + 12, height: Self.rowH)
                if let u = (r["open"] as? String).flatMap(URL.init(string:)) {
                    if hoverRow == links.count {
                        NSColor.labelColor.withAlphaComponent(0.1).setFill()
                        NSBezierPath(roundedRect: rect.insetBy(dx: 0, dy: 1.5), xRadius: 6, yRadius: 6).fill()
                    }
                    links.append((rect, u))
                }
                row(r, rect: rect, col: Self.brand(s.src))
                y += Self.rowH
            }
        }
    }

    func text(_ str: String, _ font: NSFont, _ color: NSColor) -> NSAttributedString {
        NSAttributedString(string: str, attributes: [.font: font, .foregroundColor: color])
    }

    // a waiting permission request inside an amber LED frame that melts clockwise as its time runs out:
    // tool name in dots, chat title, ✕ / ✓ (or hold-to-allow), project, then the command
    func ask(_ p: [String: Any], rect: NSRect, col: NSColor) {
        let id = p["id"] as? String ?? ""
        let sec = NSColor.secondaryLabelColor
        let amber = DotFont.tints["🔒"]!
        let box = rect.insetBy(dx: 0, dy: 3)

        // the frame: dots clockwise from the top-left corner, lit share = time left
        let inChat = p["state"] as? String == "chat"
        let created = p["created"] as? Double ?? 0, expires = p["expires"] as? Double ?? 0
        let left = max(0, expires - Date().timeIntervalSince1970)
        // a reminder has no timer: its frame stays whole and dimmer
        let share = inChat ? 1 : expires > created ? left / (expires - created) : 0
        let st = Self.frameStep, d = Self.frameDot
        let (x0, y0, x1, y1) = (box.minX, box.minY, box.maxX - d, box.maxY - d)
        var dots: [NSPoint] = []
        var x = x0
        while x < x1 { dots.append(NSPoint(x: x, y: y0)); x += st }
        var y = y0
        while y < y1 { dots.append(NSPoint(x: x1, y: y)); y += st }
        x = x1
        while x > x0 { dots.append(NSPoint(x: x, y: y1)); x -= st }
        y = y1
        while y > y0 { dots.append(NSPoint(x: x0, y: y)); y -= st }
        let lit = Int((Double(dots.count) * share).rounded(.up))
        for (i, pt) in dots.enumerated() {
            (i < lit ? amber.withAlphaComponent(inChat ? 0.45 : 1) : NSColor.labelColor.withAlphaComponent(0.1)).setFill()
            NSRect(x: pt.x, y: pt.y, width: d, height: d).fill()
        }
        let inner = box.insetBy(dx: Self.askInset, dy: 0)

        // buttons, right to left: allow (or hold) then deny
        var bx = inner.maxX
        func button(_ bw: CGFloat, _ action: String, _ draw: (NSRect) -> Void) {
            bx -= bw
            let r = NSRect(x: bx, y: box.minY + 9, width: bw, height: 24)
            NSColor.labelColor.withAlphaComponent(hoverButton == buttons.count ? 0.2 : 0.09).setFill()
            NSBezierPath(roundedRect: r, xRadius: 5, yRadius: 5).fill()
            draw(r)
            buttons.append((r, id, action))
            bx -= 6
        }
        func glyph(_ g: String, _ r: NSRect, _ c: NSColor) {
            DotFont.draw(g, at: NSPoint(x: r.midX - DotFont.width(g, cell: 2) / 2, y: r.midY - 7), cell: 2, color: c)
        }
        if inChat {
            if p["open"] as? String != nil || !(p["host"] as? String ?? "").isEmpty {
                let label = text(p["open"] as? String != nil ? "open chat" : "switch", .systemFont(ofSize: 11), .labelColor)
                button(label.size().width + 20, "open") { r in
                    label.draw(at: NSPoint(x: r.midX - label.size().width / 2, y: r.midY - label.size().height / 2))
                }
            }
        } else if p["danger"] as? Bool ?? false {
            let label = text("hold", .systemFont(ofSize: 10.5), .systemRed)
            let cells = CGFloat(Self.holdCells) * 5
            button(10 + cells + 6 + label.size().width + 10, "hold") { r in
                let lit = hold?.id == id ? hold!.lit : 0
                for i in 0..<Self.holdCells {
                    (i < lit ? NSColor.systemRed : NSColor.systemRed.withAlphaComponent(0.28)).setFill()
                    NSRect(x: r.minX + 10 + CGFloat(i) * 5, y: r.midY - 1.5, width: 3, height: 3).fill()
                }
                label.draw(at: NSPoint(x: r.minX + 10 + cells + 6, y: r.midY - label.size().height / 2))
            }
        } else {
            button(30, "allow") { glyph("✓", $0, col) }
        }
        if !inChat { button(30, "deny") { glyph("✕", $0, sec) } }

        // LED tool name, then the chat title
        let tool = String((p["tool"] as? String ?? "").uppercased().filter { DotFont.glyphs[$0] != nil }.prefix(9))
        let ledW = DotFont.width(tool, cell: Self.ledCell)
        DotFont.draw(tool, at: NSPoint(x: inner.minX, y: box.minY + 21 - 3.5 * Self.ledCell), cell: Self.ledCell,
                     color: amber.withAlphaComponent(inChat ? 0.6 : 1))
        let tx = inner.minX + (ledW > 0 ? ledW + 8 : 0)
        let ps = NSMutableParagraphStyle()
        ps.lineBreakMode = .byTruncatingTail
        var title = p["chat"] as? String ?? ""
        if title.isEmpty { title = "Permission request" }
        NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor,
                                                       .paragraphStyle: ps])
            .draw(with: NSRect(x: tx, y: box.minY + 12, width: bx - tx - 4, height: 17), options: [.usesLineFragmentOrigin])
        let pr = p["project"] as? String ?? ""
        if !pr.isEmpty || inChat {
            let mono = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
            let d = NSMutableAttributedString(attributedString: text(pr, mono, sec))
            if inChat {
                let place = p["host"] as? String == "com.anthropic.claudefordesktop" ? "in chat" : "in terminal"
                d.append(text((pr.isEmpty ? "" : " · ") + "waiting " + place, mono, amber))
            }
            d.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: d.length))
            d.draw(with: NSRect(x: inner.minX, y: box.minY + 34, width: inner.width, height: 14), options: [.usesLineFragmentOrigin])
        }
        let lines = Self.cmdLines(p, width: bounds.width)
        Self.cmdText(p, color: NSColor.labelColor.withAlphaComponent(0.85)).draw(
            with: NSRect(x: inner.minX, y: box.minY + 50, width: Self.cmdWidth(bounds.width), height: CGFloat(lines) * Self.cmdLine),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    func row(_ r: [String: Any], rect: NSRect, col: NSColor) {
        let live = r["live"] as? Bool ?? false
        let sec = NSColor.secondaryLabelColor
        // dashed top rule, highlighted background and a brand square while generating
        let rule = NSBezierPath()
        rule.move(to: NSPoint(x: rect.minX, y: rect.minY + 0.5))
        rule.line(to: NSPoint(x: rect.maxX, y: rect.minY + 0.5))
        rule.setLineDash([2, 2], count: 2, phase: 0)
        rule.lineWidth = 0.5
        NSColor.separatorColor.setStroke()
        rule.stroke()
        if live {
            NSColor.labelColor.withAlphaComponent(0.06).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 0, dy: 1.5), xRadius: 6, yRadius: 6).fill()
            col.setFill()
            NSRect(x: rect.minX + 6, y: rect.midY - 2, width: 4, height: 4).fill()
        }
        let inner = NSRect(x: rect.minX + 16, y: rect.minY, width: rect.width - 22, height: rect.height)

        // right: LED speed (or status), mini history left of it
        // fixed speed column so the histories line up whatever the number width
        var right = inner.maxX
        let speedW = DotFont.width("≈000", cell: Self.digitCell)
        if let tps = r["tps"] as? Int {
            let pre = (r["lower"] as? Bool ?? false) ? "≥" : (r["approx"] as? Bool ?? false) ? "≈" : ""
            let str = "\(pre)\(tps)"
            let sw = DotFont.width(str, cell: Self.digitCell)
            DotFont.draw(str, at: NSPoint(x: right - sw, y: rect.midY - 3.5 * Self.digitCell), cell: Self.digitCell,
                         color: live ? col : .labelColor)
            right -= speedW + 10
        } else {
            let st = text(r["status"] as? String ?? "—", .systemFont(ofSize: 11), sec)
            st.draw(at: NSPoint(x: right - st.size().width, y: rect.midY - st.size().height / 2))
            right -= max(speedW, st.size().width) + 10
        }
        let hist = r["hist"] as? [Int] ?? []
        if !hist.isEmpty {
            let c = Self.histCell, n = 8
            let hx = right - CGFloat(n) * c
            let base = rect.midY + CGFloat(Self.histRows) * c / 2
            let top = Double(hist.max() ?? 1)  // relative scale: the tallest recent response fills the column
            for i in 0..<n {
                let k = i - (n - hist.count)
                let lit = k >= 0 ? max(1, min(Self.histRows, Int((Double(hist[k]) / max(top, 1) * Double(Self.histRows)).rounded()))) : 0
                for j in 0..<Self.histRows {
                    let on = j < lit
                    (on ? (k == hist.count - 1 ? col : col.withAlphaComponent(0.55)) : NSColor.labelColor.withAlphaComponent(0.07)).setFill()
                    NSRect(x: hx + CGFloat(i) * c, y: base - CGFloat(j + 1) * c, width: c * 2 / 3, height: c * 2 / 3).fill()
                }
            }
            right = hx - 10
        }

        // left: chat title, then project · model · TTFT · cache · agents · errors · when
        var chat = r["chat"] as? String ?? ""
        if chat.isEmpty { chat = "Untitled" }
        let tw = right - inner.minX
        let ps = NSMutableParagraphStyle()
        ps.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: chat, attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor,
                                                      .paragraphStyle: ps])
            .draw(with: NSRect(x: inner.minX, y: rect.minY + 5, width: tw, height: 17), options: [.usesLineFragmentOrigin])
        let mono = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
        let d = NSMutableAttributedString(attributedString: text(r["project"] as? String ?? "", mono, col))
        var parts: [String] = []
        if let m = r["model_name"] as? String, !m.isEmpty { parts.append(m) }
        if let t = r["ttft"] as? Double { parts.append("TTFT \(Int(t.rounded()))s") }
        if let c = r["cache"] as? Int { parts.append("cache \(c)%" + ((r["cold"] as? Bool ?? false) ? "❄" : "")) }
        if let a = r["agents"] as? Int, a > 0 { parts.append("agent \(a)") }
        d.append(text(parts.map { " · " + $0 }.joined(), mono, sec))
        if let e = r["errs"] as? Int, e > 0 { d.append(text(" · ⚠\(e)", mono, .systemRed)) }
        if let wt = r["wait"] as? Int {
            d.append(text(" · waiting \(wt)s", mono, .systemYellow))
        } else if let ago = r["ago"] as? String {
            d.append(text(" · " + ago, mono, sec))
        }
        d.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: d.length))
        d.draw(with: NSRect(x: inner.minX, y: rect.minY + 22, width: tw, height: 14), options: [.usesLineFragmentOrigin])
    }
}

final class NotchView: NSView {
    var notch = NSSize.zero
    var notchX: CGFloat = 0
    private(set) var expanded = false
    private(set) var animating = false
    private var generation = 0  // a newer open/close supersedes the completion of an older one
    // offscreen renderer for the hover card; its snapshot is shown in `content`
    let tiles = TilesView()
    let earsView = NSView()
    // boring.notch-style panel: a black notch-shaped layer that springs open from the physical notch
    let panel = CAShapeLayer()
    let content = CALayer()
    // per side: logo layer and speed-text layer
    let logos = [CALayer(), CALayer()]
    let texts = [CALayer(), CALayer()]
    // limit meters: one layer per dot, so the columns can unroll into rows when the panel opens
    var dots: [[CALayer]] = [[], []]
    let meterLabels = [CALayer(), CALayer()]  // name, LED percent and reset time beside the open rows
    var meterLimits: [[[String: Any]]] = [[], []]
    var meterBrand: [NSColor] = [.clear, .clear]
    var meterShown = [true, true]
    var placed: [(logoW: CGFloat, textW: CGFloat, showText: Bool, h: CGFloat, meterW: CGFloat)?] = [nil, nil]
    private var meterClosed: [NSPoint] = [.zero, .zero]  // bottom-left of the closed columns
    private var meterSpan: [(a: CGFloat, b: CGFloat)] = [(0, 0), (0, 0)]  // room for the open rows
    static let meterGap: CGFloat = 5
    var onHover: ((Bool) -> Void)?
    var tracking: NSTrackingArea?
    static let outer: CGFloat = 10
    static let inner: CGFloat = 8
    static let gap: CGFloat = 6
    static let textGap: CGFloat = 4
    // notch shape radii (closed → open) and the margin that absorbs the spring overshoot
    static let closedR: (top: CGFloat, bottom: CGFloat) = (6, 14)
    static let openR: (top: CGFloat, bottom: CGFloat) = (19, 24)
    static let margin: CGFloat = 8

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        tiles.appearance = NSAppearance(named: .darkAqua)
        // a layer-hosting subview owns the ear layers; AppKit rebuilds sublayers of layer-backed views
        earsView.layer = CALayer()
        earsView.wantsLayer = true
        panel.fillColor = NSColor.black.cgColor
        panel.opacity = 0
        panel.actions = ["path": NSNull(), "opacity": NSNull()]
        earsView.layer?.addSublayer(panel)
        for l in logos + texts + meterLabels {
            l.contentsScale = 2
            l.actions = ["contents": NSNull(), "bounds": NSNull()]
            earsView.layer?.addSublayer(l)
        }
        content.contentsScale = 2
        content.anchorPoint = CGPoint(x: 0.5, y: 1)  // scale in from the top edge
        content.contentsGravity = .top  // never stretch a stale raster, crop it
        content.opacity = 0
        content.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        earsView.layer?.addSublayer(content)
        addSubview(earsView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseMoved(with event: NSEvent) {
        if !expanded { onHover?(true) } else {
            let p = tilesPoint(event)
            setHoverRow(tiles.link(at: p)?.index, button: tiles.button(at: p)?.index)
        }
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }  // the panel never becomes key
    var onOpen: ((URL) -> Void)?

    var onAnswer: ((String, Bool) -> Void)?
    private var holdTimer: Timer?
    static let holdTime = 0.8  // seconds to hold for a destructive command

    override func mouseDown(with event: NSEvent) {
        guard expanded, !animating else { return }
        let p = tilesPoint(event)
        if let b = tiles.button(at: p) {
            if b.action == "hold" {
                startHold(b.id)
            } else if b.action == "open" {
                let item = tiles.pending.first { $0["id"] as? String == b.id }
                if let u = (item?["open"] as? String).flatMap(URL.init(string:)) {
                    onOpen?(u)
                } else if let host = item?["host"] as? String,
                          let app = NSRunningApplication.runningApplications(withBundleIdentifier: host).first {
                    app.activate()  // a terminal session has no deep link: bring its app forward
                }
            } else {
                onAnswer?(b.id, b.action == "allow")
            }
            return
        }
        guard let hit = tiles.link(at: p) else { return }
        onOpen?(hit.url)
    }

    override func mouseUp(with event: NSEvent) { cancelHold() }

    func startHold(_ id: String) {
        cancelHold()
        let start = CACurrentMediaTime()
        tiles.hold = (id, 0)
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            let f = (CACurrentMediaTime() - start) / NotchView.holdTime
            if f >= 1 {
                self.cancelHold()
                self.onAnswer?(id, true)
                return
            }
            let lit = Int(f * Double(TilesView.holdCells))
            if lit != self.tiles.hold?.lit {
                self.tiles.hold = (id, lit)
                self.renderContent()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        holdTimer = t
    }

    func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        if tiles.hold != nil {
            tiles.hold = nil
            renderContent()
        }
    }

    // window point → TilesView (flipped) point inside the card raster
    func tilesPoint(_ event: NSEvent) -> NSPoint {
        let p = convert(event.locationInWindow, from: nil), r = contentRect
        return NSPoint(x: p.x - r.minX, y: r.maxY - p.y)
    }

    func setHoverRow(_ i: Int?, button b: Int? = nil) {
        guard i != tiles.hoverRow || b != tiles.hoverButton else { return }
        tiles.hoverRow = i
        tiles.hoverButton = b
        renderContent()
    }
    override func mouseExited(with event: NSEvent) { onHover?(false) }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit ClaudeSpeed", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func layout() {
        super.layout()
        earsView.frame = bounds
        guard !animating else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if expanded {
            panel.path = openPath
            // a resized card needs a fresh raster; reusing the old one would stretch it
            if content.bounds.size != contentRect.size { renderContent() } else { placeContent() }
        } else {
            placeContent()
        }
        CATransaction.commit()
    }

    // NotchShape from DynamicNotchKit/boring.notch: concave top shoulders, rounded bottom corners (layer coords, y up)
    static func notchPath(_ r: NSRect, top t: CGFloat, bottom b: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX + t, y: r.maxY - t), control: CGPoint(x: r.minX + t, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + t, y: r.minY + b))
        p.addQuadCurve(to: CGPoint(x: r.minX + t + b, y: r.minY), control: CGPoint(x: r.minX + t, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - t - b, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - t, y: r.minY + b), control: CGPoint(x: r.maxX - t, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - t, y: r.maxY - t))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.maxX - t, y: r.maxY))
        p.closeSubpath()
        return p
    }

    var closedPath: CGPath {
        let t = NotchView.closedR.top
        return NotchView.notchPath(NSRect(x: notchX - t, y: bounds.height - notch.height, width: notch.width + 2 * t,
                                          height: notch.height), top: t, bottom: NotchView.closedR.bottom)
    }

    var openPath: CGPath {
        let m = NotchView.margin
        return NotchView.notchPath(NSRect(x: m, y: m, width: bounds.width - 2 * m, height: bounds.height - m),
                                   top: NotchView.openR.top, bottom: NotchView.openR.bottom)
    }

    // the card area inside the open panel, below the notch row
    var contentRect: NSRect {
        let inset = NotchView.margin + NotchView.openR.top
        return NSRect(x: inset, y: NotchView.margin, width: bounds.width - 2 * inset,
                      height: bounds.height - notch.height - NotchView.margin)
    }

    func placeContent() {
        let r = contentRect
        content.bounds = CGRect(origin: .zero, size: r.size)
        content.position = CGPoint(x: r.midX, y: r.maxY)
    }

    func setSections(_ sections: [(src: String, name: String, rows: [[String: Any]])]) {
        tiles.sections = sections
        guard expanded else { return }
        renderContent()
    }

    // rasterize the card once per data change; the animation only moves pixels around
    func renderContent() {
        let r = contentRect
        guard r.width > 0, r.height > 0 else { return }
        tiles.frame = NSRect(origin: .zero, size: r.size)
        guard let rep = tiles.bitmapImageRepForCachingDisplay(in: tiles.bounds) else { return }
        NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
            tiles.cacheDisplay(in: tiles.bounds, to: rep)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.contents = rep.cgImage
        placeContent()
        CATransaction.commit()
    }

    // SwiftUI .spring(response:dampingFraction:) expressed as a CASpringAnimation
    static func spring(_ key: String, from: Any?, to: Any?, response: Double, damping: Double) -> CASpringAnimation {
        let a = CASpringAnimation(keyPath: key)
        a.mass = 1
        a.stiffness = pow(2 * .pi / response, 2)
        a.damping = 4 * .pi * damping / response
        a.fromValue = from
        a.toValue = to
        a.duration = min(a.settlingDuration, 0.7)  // the visible motion is over long before full settling
        return a
    }

    func setExpanded(_ on: Bool, completion: (() -> Void)? = nil) {
        guard on != expanded else { return }
        expanded = on
        generation += 1
        let gen = generation
        animating = true
        let from = panel.presentation()?.path ?? panel.path ?? closedPath
        let to = on ? openPath : closedPath
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, gen == self.generation else { return }
            self.animating = false
            if !on {
                self.panel.opacity = 0
                completion?()
            }
        }
        panel.opacity = 1
        panel.removeAnimation(forKey: "path")
        if on {
            panel.add(NotchView.spring("path", from: from, to: to, response: 0.42, damping: 0.8), forKey: "path")
        } else {
            let a = CABasicAnimation(keyPath: "path")
            a.fromValue = from
            a.toValue = to
            a.duration = 0.3
            a.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1)
            panel.add(a, forKey: "path")
        }
        panel.path = to
        for i in 0..<2 {
            let from = meterClosed[i]  // the columns' spot before the ears slide
            if let p = placed[i] {
                place(side: i, logoW: p.logoW, textW: p.textW, showText: p.showText, height: p.h, meterW: p.meterW,
                      animated: true, meters: false)
            }
            layoutMeters(i, open: on, animated: .spring, closedFrom: from)
        }
        if on { tiles.hoverRow = nil; tiles.hoverButton = nil; renderContent() }
        // content: scale 0.8 → 1 from the top plus fade, like boring.notch's .scale(0.8, anchor: .top)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = content.presentation()?.opacity ?? content.opacity
        fade.toValue = on ? 1 : 0
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = (content.presentation()?.value(forKeyPath: "transform.scale") as? Double) ?? (on ? 0.8 : 1)
        scale.toValue = on ? 1 : 0.8
        let group = CAAnimationGroup()
        group.animations = [fade, scale]
        group.duration = on ? 0.35 : 0.18
        group.beginTime = CACurrentMediaTime() + (on ? 0.05 : 0)
        group.fillMode = .backwards
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
        content.removeAnimation(forKey: "show")
        content.add(group, forKey: "show")
        content.opacity = on ? 1 : 0
        content.setValue(on ? 1 : 0.8, forKeyPath: "transform.scale")
        CATransaction.commit()
    }

    // left ear reads [logo][text]|notch, right ear notch|[logo][text]; without text the left logo sits next to the notch
    func place(side i: Int, logoW: CGFloat, textW: CGFloat, showText wantText: Bool, height h: CGFloat, meterW: CGFloat,
               animated: Bool, meters: Bool = true) {
        placed[i] = (logoW, textW, wantText, h, meterW)
        // open: the speed leaves the ear (every row shows it) and its room goes to the limit rows
        let showText = wantText && !expanded
        let y = (bounds.height - notch.height + (notch.height - h) / 2).rounded()
        let logoX: CGFloat, textX: CGFloat
        if i == 0 {
            textX = notchX - NotchView.inner - textW
            logoX = (showText ? textX - NotchView.textGap : notchX - NotchView.inner) - logoW
        } else {
            logoX = notchX + notch.width + NotchView.inner
            textX = logoX + logoW + NotchView.textGap
        }
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.35)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        // explicit from-values: an implicit action would start from the last committed position, which is in the
        // coordinates of the window before a resize in this same pass, so the logo flew in from below
        slide(logos[i], to: NSRect(x: logoX.rounded(), y: y, width: logoW, height: h), animated: animated)
        // limit meters sit on the outer side: left of the left logo, right of the right ear's text
        let mh = CGFloat(Limits.rows) * Limits.cell
        let meterX = i == 0 ? logoX - NotchView.meterGap - meterW
            : (showText ? textX + textW : logoX + logoW) + NotchView.meterGap
        meterClosed[i] = NSPoint(x: meterX.rounded(), y: (bounds.height - notch.height + (notch.height - mh) / 2).rounded())
        // open rows fill the room between the panel's content edge and the logo as it sits when open (no speed
        // text), so the dot count never depends on whether the speed is showing
        let edge = contentRect
        meterSpan[i] = i == 0 ? (edge.minX + 2, notchX - NotchView.inner - logoW - NotchView.meterGap)
            : (notchX + notch.width + NotchView.inner + logoW + NotchView.meterGap, edge.maxX - 2)
        if meters { layoutMeters(i, open: expanded, animated: animated ? .implicit : .none) }
        slide(texts[i], to: NSRect(x: textX.rounded(), y: y, width: textW, height: h), animated: animated)
        texts[i].opacity = showText ? 1 : 0
        CATransaction.commit()
    }
}

extension NotchView {
    func slide(_ l: CALayer, to frame: NSRect, animated: Bool) {
        let old = l.position
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        l.frame = frame
        CATransaction.commit()
        guard animated, old != l.position else { return }
        let a = CABasicAnimation(keyPath: "position")
        a.fromValue = l.animation(forKey: "position") != nil ? (l.presentation()?.position ?? old) : old
        a.toValue = l.position
        a.duration = 0.35
        a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        l.add(a, forKey: "position")
    }

    enum MeterMotion { case none, implicit, spring }

    func setMeters(_ i: Int, limits: [[String: Any]], brand: NSColor) {
        meterLimits[i] = limits
        meterBrand[i] = brand
        layoutMeters(i, open: expanded, animated: .none)
    }

    func setMetersShown(_ i: Int, _ on: Bool, animated: Bool) {
        meterShown[i] = on
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        for d in dots[i] { d.opacity = on ? 1 : 0 }
        if !on { meterLabels[i].opacity = 0 }
        CATransaction.commit()
    }

    // open layout of one side: per row [name] [bar] [LED %] [reset], squeezed to the room between panel edge and logo
    // open layout of one side: per row [NAME] [bar] [NN%] [RESET], all in one small LED font and strict columns,
    // squeezed into the room between the panel edge and the logo
    private func openLayout(_ i: Int) -> (cells: Int, block: NSRect, barX: CGFloat, rowY: [CGFloat], image: NSImage?) {
        let ls = meterLimits[i]
        let c: CGFloat = 1, gap: CGFloat = 5
        let names = ls.map { ($0["name"] as? String ?? "").uppercased() }
        var resets = ls.map { ($0["reset"] as? String ?? "").uppercased() }
        let pcts = ls.map { "\($0["pct"] as? Int ?? 0)%" }
        let pctW = pcts.map { DotFont.width($0, cell: c) }.max() ?? 0
        var nameW = names.map { DotFont.width($0, cell: c) }.max() ?? 0
        var resetW = resets.map { DotFont.width($0, cell: c) }.max() ?? 0
        let room = meterSpan[i].b - meterSpan[i].a
        func cellsFor() -> Int {
            Int((room - (nameW > 0 ? nameW + gap : 0) - gap - pctW - (resetW > 0 ? gap + resetW : 0)) / Limits.openStep)
        }
        // tight on room: the reset shrinks to its leading unit ("2H 23M" → "2H"), then goes; the name stays longest
        if cellsFor() < 8 {
            resets = resets.map { $0.split(separator: " ").first.map(String.init) ?? "" }
            resetW = resets.map { DotFont.width($0, cell: c) }.max() ?? 0
        }
        if cellsFor() < 6 { resetW = 0 }
        if cellsFor() < 6 { nameW = 0 }
        let cells = min(14, max(4, cellsFor()))
        let barW = CGFloat(cells - 1) * Limits.openStep + Limits.cell
        let w = (nameW > 0 ? nameW + gap : 0) + barW + gap + pctW + (resetW > 0 ? gap + resetW : 0)
        let x0 = i == 0 ? meterSpan[i].b - w : meterSpan[i].a
        let h = notch.height, y0 = bounds.height - h
        let mid = y0 + h / 2
        let rowY: [CGFloat] = ls.count == 1 ? [mid] : (0..<ls.count).map { mid + 5.5 - CGFloat($0) * 11 }
        let barX = x0 + (nameW > 0 ? nameW + gap : 0)
        let dim = NSColor.white.withAlphaComponent(0.5)
        let img = ls.isEmpty ? nil : NSImage(size: NSSize(width: w, height: h), flipped: true) { _ in
            for (k, l) in ls.enumerated() {
                let top = (y0 + h - rowY[k]) - 3.5 * c  // flipped: rows measured from the top
                let pct = l["pct"] as? Int ?? 0
                let px = barX - x0 + barW + gap
                if nameW > 0 { DotFont.draw(names[k], at: NSPoint(x: 0, y: top), cell: c, color: dim) }
                // percent right-aligned in its column so "6%" and "36%" end together
                DotFont.draw(pcts[k], at: NSPoint(x: px + pctW - DotFont.width(pcts[k], cell: c), y: top), cell: c,
                             color: pct >= 80 ? .systemRed : .white)
                if resetW > 0 { DotFont.draw(resets[k], at: NSPoint(x: px + pctW + gap, y: top), cell: c, color: dim) }
            }
            return true
        }
        return (cells, NSRect(x: x0, y: y0, width: w, height: h), barX, rowY, img)
    }

    // closed: column k, dot i sits at height i·6/cells (extra dots stack); open: row k, dot i at position i
    func layoutMeters(_ i: Int, open: Bool, animated: MeterMotion, closedFrom: NSPoint? = nil) {
        let ls = meterLimits[i]
        let o = openLayout(i)
        let total = ls.count * o.cells
        while dots[i].count < total {
            let d = CALayer()
            d.contentsScale = 2
            d.actions = ["backgroundColor": NSNull()]
            d.opacity = meterShown[i] ? 1 : 0
            earsView.layer?.addSublayer(d)
            dots[i].append(d)
        }
        while dots[i].count > total { dots[i].removeLast().removeFromSuperlayer() }
        var dimClosed = NSColor.clear.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance { dimClosed = NSColor.labelColor.withAlphaComponent(0.2).cgColor }
        let dimOpen = NSColor.white.withAlphaComponent(0.16).cgColor
        CATransaction.begin()
        CATransaction.setDisableActions(animated != .implicit)
        if animated == .implicit { CATransaction.setAnimationDuration(0.35) }
        for (k, l) in ls.enumerated() {
            let pct = l["pct"] as? Int ?? 0
            let col = Limits.color(pct, brand: meterBrand[i]).cgColor
            let litC = Limits.lit(pct, of: Limits.rows), litO = Limits.lit(pct, of: o.cells)
            for n in 0..<o.cells {
                let d = dots[i][k * o.cells + n]
                let j = n * Limits.rows / o.cells
                let size = open ? 2.5 : Limits.cell * 0.8
                let openPos = CGPoint(x: o.barX + CGFloat(n) * Limits.openStep + 1.25, y: o.rowY[k])
                let closedPos = CGPoint(x: meterClosed[i].x + CGFloat(2 * k) * Limits.cell + Limits.cell * 0.4,
                                        y: meterClosed[i].y + CGFloat(j) * Limits.cell + Limits.cell * 0.4)
                let openColor = n < litO ? col : dimOpen, closedColor = j < litC ? col : dimClosed
                let pos = open ? openPos : closedPos
                let color = open ? openColor : closedColor
                if animated == .spring {
                    // start from the other state's spot: the window was just resized, so the last rendered
                    // frame sits in old coordinates; only a motion already under way continues from where it is
                    let midFlight = d.animation(forKey: "position") != nil
                    let c0 = closedFrom ?? meterClosed[i]
                    let startClosed = CGPoint(x: closedPos.x - meterClosed[i].x + c0.x, y: closedPos.y - meterClosed[i].y + c0.y)
                    let fromPos = midFlight ? (d.presentation()?.position ?? pos) : (open ? startClosed : openPos)
                    let fromColor = midFlight ? (d.presentation()?.backgroundColor ?? color) : (open ? closedColor : openColor)
                    // staggered so the column visibly unrolls; folding back runs the other way, faster
                    let delay = open ? Double(n) * 0.014 + Double(k) * 0.03 : Double(o.cells - n) * 0.006
                    let a = NotchView.spring("position", from: NSValue(point: fromPos), to: NSValue(point: pos),
                                             response: open ? 0.45 : 0.3, damping: open ? 0.72 : 0.9)
                    a.beginTime = CACurrentMediaTime() + delay
                    a.fillMode = .backwards
                    a.isRemovedOnCompletion = true
                    d.add(a, forKey: "position")
                    let c = CABasicAnimation(keyPath: "backgroundColor")
                    c.fromValue = fromColor
                    c.toValue = color
                    c.duration = 0.3
                    c.beginTime = CACurrentMediaTime() + delay
                    c.fillMode = .backwards
                    d.add(c, forKey: "color")
                }
                d.bounds = CGRect(x: 0, y: 0, width: size, height: size)
                d.position = pos
                d.backgroundColor = color
            }
        }
        // labels fade in once the dots have mostly arrived, and leave first when folding
        let lab = meterLabels[i]
        lab.contents = o.image.flatMap { img in
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(img.size.width * 2), pixelsHigh: Int(img.size.height * 2),
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = img.size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            img.draw(in: NSRect(origin: .zero, size: img.size))
            NSGraphicsContext.restoreGraphicsState()
            return rep.cgImage
        }
        lab.frame = o.block
        let target: Float = open && meterShown[i] ? 1 : 0
        if animated == .spring {
            let f = CABasicAnimation(keyPath: "opacity")
            f.fromValue = lab.presentation()?.opacity ?? lab.opacity
            f.toValue = target
            f.duration = open ? 0.25 : 0.1
            f.beginTime = CACurrentMediaTime() + (open ? 0.22 : 0)
            f.fillMode = .backwards
            lab.add(f, forKey: "fade")
        }
        lab.opacity = target
        CATransaction.commit()
    }
}

// LED logos beside the MacBook notch: colored and animated while generating, gray and compact when idle;
// a menu-style card below it on hover
final class NotchController {
    let screen: NSScreen
    let window: NSPanel
    let island: NotchView
    var lines: [String: DotLogo.Line] = [:]
    var data: [String: [String: Any]] = [:]
    var hovered = false
    var closing = false
    var shownLive: [Bool] = [false, false]
    var running: [Bool] = [true, true]
    var textW: [CGFloat] = [0, 0]
    var lastLogos: [NSImage?] = [nil, nil]
    var shrinkWork: DispatchWorkItem?
    var pending: [[String: Any]] = []
    var onAnswer: ((String, Bool) -> Void)?
    private var lastDoc: [String: Any]?
    private var lastAlive: Set<String> = []
    static let logoSize: CGFloat = 16.5

    init(screen: NSScreen) {
        self.screen = screen
        let notch = NSSize(
            width: screen.frame.width - (screen.auxiliaryTopLeftArea?.width ?? 0) - (screen.auxiliaryTopRightArea?.width ?? 0),
            height: screen.safeAreaInsets.top)
        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        island = NotchView(frame: .zero)
        island.notch = notch
        island.autoresizingMask = [.width, .height]
        window.contentView = island
        for p in providers { lines[p.src] = DotLogo.line(src: p.src) }
        island.onHover = { [weak self] on in self?.hover(on) }
        island.onOpen = { [weak self] url in
            NSWorkspace.shared.open(url)
            if self?.hovered == true { self?.setHovered(false) }
        }
        island.onAnswer = { [weak self] id, allow in self?.onAnswer?(id, allow) }
        setFrame(targetFrame())
        placeAll(animated: false)
        window.orderFrontRegardless()
        tick()
    }

    deinit { window.orderOut(nil) }

    var dark: Bool { island.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }

    var hoverCheck: Timer?

    var openWork: DispatchWorkItem?
    static let openDelay = 0.15  // dwell before opening, so a cursor passing by the notch doesn't pop the panel

    // open from the island; while not folding away, the window itself counts too (it lags a size change by 0.4 s)
    var openZone: NSRect { (closing ? closedFrame() : closedFrame().union(window.frame)).insetBy(dx: -2, dy: -2) }

    func hover(_ on: Bool) {
        let mouse = NSEvent.mouseLocation
        if on {
            guard !hovered, openWork == nil, openZone.contains(mouse) else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.openWork = nil
                if self.openZone.contains(NSEvent.mouseLocation) { self.setHovered(true) }
            }
            openWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + NotchController.openDelay, execute: work)
        } else {
            // resizing the window rebuilds the tracking area and can fire a spurious exit; trust the cursor instead
            if window.frame.insetBy(dx: -2, dy: -2).contains(mouse) { return }
            openWork?.cancel()
            openWork = nil
            if hovered { setHovered(false) }
        }
    }

    func setHovered(_ on: Bool) {
        hovered = on
        // tracking areas can miss the exit while the window resizes; poll the cursor only while open
        hoverCheck?.invalidate()
        hoverCheck = nil
        if on {
            hoverCheck = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self else { return }
                if !self.window.frame.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) { self.hover(false) }
            }
        }
        // a light tick on Force Touch trackpads on open and close, like boring.notch; silent elsewhere
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        if on {
            closing = false
            // fresh rows first: the window height is computed from them
            island.tiles.today = todayBySrc
            island.tiles.sections = sections()
            setFrame(targetFrame())  // grow the transparent window first, then spring the panel open inside it
            island.setExpanded(true)
        } else {
            // keep the window large until the card has folded back into the notch
            closing = true
            island.setExpanded(false) { [weak self] in
                guard let self else { return }
                self.closing = false
                self.setFrame(self.targetFrame())
            }
        }
    }

    // a new request ticks the trackpad once; the ear shows an amber lock (plus a count) and the logo blinks until it is answered
    func setPending(_ items: [[String: Any]]) {
        let old = Set(pending.compactMap { $0["id"] as? String })
        // only a request the notch itself has to answer ticks; one already in the chat doesn't
        if items.contains(where: { !old.contains($0["id"] as? String ?? "") && $0["state"] as? String != "chat" }) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        pending = items
        island.tiles.pending = items
        if items.isEmpty { island.cancelHold() }
        if let doc = lastDoc { update(doc, alive: lastAlive) }
    }

    func asks(_ src: String) -> Int { pending.filter { ($0["src"] as? String) == src }.count }

    var todayBySrc: [String: [String: Int]] {
        var out: [String: [String: Int]] = [:]
        for p in providers { out[p.src] = data[p.src]?["today"] as? [String: Int] }
        return out
    }

    func sections() -> [(src: String, name: String, rows: [[String: Any]])] {
        providers.map { (src: $0.src, name: $0.name, rows: data[$0.src]?["rows"] as? [[String: Any]] ?? []) }
    }

    func limits(_ i: Int) -> [[String: Any]] { data[providers[i].src]?["limits"] as? [[String: Any]] ?? [] }
    func meterW(_ i: Int) -> CGFloat { Limits.earWidth(limits(i).count) }

    func earWidth(_ i: Int) -> CGFloat {
        guard running[i] else { return 0 }
        return NotchView.outer + NotchController.logoSize + NotchView.inner
            + (meterW(i) > 0 ? NotchView.meterGap + meterW(i) : 0)
            + (shownLive[i] ? NotchView.textGap + textW[i] : 0)
    }

    // the collapsed island: notch plus visible ears — the only area that opens the panel
    func closedFrame() -> NSRect {
        let n = island.notch, f = screen.frame
        let x = f.midX - n.width / 2 - earWidth(0)
        return NSRect(x: x.rounded(), y: f.maxY - n.height, width: (n.width + earWidth(0) + earWidth(1)).rounded(), height: n.height)
    }

    func targetFrame() -> NSRect {
        let n = island.notch, f = screen.frame
        var x = f.midX - n.width / 2 - earWidth(0)
        var w = n.width + earWidth(0) + earWidth(1)
        var h = n.height
        if hovered || closing {
            // the open panel spans the ears plus room for its shoulders and the spring overshoot
            let half = max(280, n.width / 2 + max(earWidth(0), earWidth(1)) + NotchView.margin + NotchView.openR.top)
            x = f.midX - half
            w = 2 * half
            let cardW = 2 * half - 2 * (NotchView.margin + NotchView.openR.top)
            h += TilesView.height(island.tiles.sections, pending: island.tiles.pending, width: cardW) + NotchView.margin
        }
        return NSRect(x: x.rounded(), y: f.maxY - h, width: w.rounded(), height: h.rounded())
    }

    // ear layers are positioned relative to the notch, so a window resize alone never moves them on screen
    func setFrame(_ frame: NSRect) {
        guard frame != window.frame else { return }
        window.setFrame(frame, display: true, animate: false)
        island.notchX = (screen.frame.midX - island.notch.width / 2).rounded() - frame.minX
        island.layoutSubtreeIfNeeded()
        placeAll(animated: false)
    }

    func placeAll(animated: Bool) {
        for i in 0..<2 {
            island.place(side: i, logoW: NotchController.logoSize, textW: textW[i], showText: shownLive[i] && running[i],
                         height: NotchController.logoSize, meterW: meterW(i), animated: animated)
            CATransaction.begin()
            CATransaction.setDisableActions(!animated)
            CATransaction.setAnimationDuration(0.35)
            island.logos[i].opacity = running[i] ? 1 : 0
            CATransaction.commit()
            island.setMetersShown(i, running[i], animated: animated)
        }
    }

    func update(_ doc: [String: Any], alive: Set<String>) {
        lastDoc = doc
        lastAlive = alive
        let wasRunning = running
        running = providers.map { alive.contains($0.src) }
        for p in providers {
            let d = doc[p.src] as? [String: Any] ?? [:]
            data[p.src] = d
            let n = asks(p.src)
            lines[p.src] = n > 0 ? DotLogo.line(src: p.src, live: true, text: n > 1 ? "🔒\(n)" : "🔒")
                : DotLogo.line(src: p.src, live: d["live"] as? Bool ?? false, text: d["title"] as? String ?? "⚪")
        }
        if hovered {
            island.tiles.pending = pending
            island.tiles.today = todayBySrc
            island.setSections(sections())
        }
        for i in 0..<2 { island.setMeters(i, limits: limits(i), brand: TilesView.brand(providers[i].src)) }
        let wasLive = shownLive
        var texts: [NSImage?] = [nil, nil]
        for (i, p) in providers.enumerated() {
            let l = lines[p.src]!
            var t = l
            t.text = String(l.text.filter { !DotLogo.lamps.contains($0) })
            let img = t.text.isEmpty ? nil : DotFont.cachedTitle(t, size: NotchController.logoSize, phase: -1, dark: dark)
            texts[i] = img
            shownLive[i] = l.live && img != nil
            if let img { textW[i] = img.size.width }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if let img { island.texts[i].contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil) }
            CATransaction.commit()
        }
        // grow the window first, then slide; slide first, then shrink — the island never clips mid-animation
        shrinkWork?.cancel()
        let target = targetFrame()
        if island.animating {
            placeAll(animated: false)  // the open/close completion resizes the window to the latest target
        } else if target.width >= window.frame.width || hovered || closing {
            setFrame(target)
            placeAll(animated: wasLive != shownLive || wasRunning != running)
        } else {
            placeAll(animated: true)
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.setFrame(self.targetFrame())
            }
            shrinkWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        }
        lastLogos = [nil, nil]
        tick()
    }

    func tick() {
        let t = Date().timeIntervalSinceReferenceDate
        let gray = dark ? NSColor(white: 0.62, alpha: 1) : NSColor(white: 0.42, alpha: 1)
        let imgs: [NSImage?] = providers.map { p in
            let l = lines[p.src]!
            if asks(p.src) > 0 {
                return DotLogo.image(p.src, size: NotchController.logoSize, phase: -1, lit: Int(t * 2.5) % 2 == 0)
            }
            return l.live
                ? DotLogo.image(p.src, size: NotchController.logoSize, phase: DotLogo.phase(l, at: t), lit: true)
                : DotLogo.image(p.src, size: NotchController.logoSize, phase: -1, lit: true, mono: gray)
        }
        if zip(imgs, lastLogos).allSatisfy({ $0 === $1 }) { return }
        lastLogos = imgs
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for i in 0..<2 { island.logos[i].contents = imgs[i]?.cgImage(forProposedRect: nil, context: nil, hints: nil) }
        CATransaction.commit()
    }
}

extension NSScreen {
    var hasNotch: Bool { safeAreaInsets.top > 0 && auxiliaryTopLeftArea != nil }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var items: [ProviderItem] = []
    var notch: NotchController?
    var poll: Timer?
    var animTimer: Timer?
    var running = false
    var anyLive = false
    let permissions = Permissions()
    // collect.py 与二进制同目录:仓库 clone 到哪都能跑,无硬编码路径
    let script = URL(fileURLWithPath: Bundle.main.executablePath ?? CommandLine.arguments[0])
        .resolvingSymlinksInPath().deletingLastPathComponent()
        .appendingPathComponent("collect.py").path

    func applicationDidFinishLaunching(_ notification: Notification) {
        permissions.onChange = { [weak self] items in
            guard let self else { return }
            self.notch?.setPending(items)
            self.setAnimating(self.anyLive || !items.isEmpty)
        }
        setupMode()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.setupMode()
            self?.refresh()  // fill the new UI now instead of showing ⚪ until the next poll
        }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) { Permissions.announce(false) }

    // notch island on a notched built-in display; status-bar icons otherwise; only the notch answers permission requests
    func setupMode() {
        defer { if notch != nil { Permissions.announce(true) } }
        if let screen = NSScreen.screens.first(where: { $0.hasNotch }) {
            if notch?.screen != screen || notch == nil {
                items = []
                notch = NotchController(screen: screen)
                notch?.onAnswer = { [weak self] id, allow in self?.permissions.answer(id, allow: allow) }
                notch?.setPending(permissions.items)
            }
        } else if notch != nil || items.isEmpty {
            notch = nil
            Permissions.announce(false)
            // created right-to-left: the last item sits leftmost, so Codex goes first to land on the right
            items = providers.reversed().map { ProviderItem(src: $0.src, name: $0.name) }
            items.forEach { $0.draw() }
        }
    }

    // animation timer only runs while something is generating
    func setAnimating(_ on: Bool) {
        if on, animTimer == nil {
            animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.notch?.tick()
                self.items.forEach { $0.draw() }
            }
        } else if !on, let t = animTimer {
            t.invalidate()
            animTimer = nil
        }
    }

    func schedule() {
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: anyLive ? 3 : 10, repeats: false) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        if running { return }  // 上一轮没跑完就跳过,避免堆积
        running = true
        let wantsAlive = notch != nil  // process scan only feeds the notch ears
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let process = Process()
            // 经 env 找 python3,兼容 Homebrew/pyenv 等非系统安装
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", self.script, "--menu-json"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            var data = Data()
            do {
                try process.run()
                data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
            } catch {}
            let doc = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            // demo fixture: both providers count as running
            let demo = ProcessInfo.processInfo.environment["CLAUDE_SPEED_DEMO"] != nil
            let alive = !wantsAlive ? [] : demo ? Set(providers.map(\.src)) : Running.scan()
            DispatchQueue.main.async {
                if let doc {
                    self.anyLive = providers.contains { (doc[$0.src] as? [String: Any])?["live"] as? Bool ?? false }
                    self.notch?.update(doc, alive: alive)
                    for item in self.items { item.update(doc[item.src] as? [String: Any] ?? [:]) }
                }
                self.setAnimating(self.anyLive || !self.permissions.items.isEmpty)
                self.running = false
                self.schedule()
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // 不占 Dock,只驻菜单栏
let delegate = AppDelegate()
app.delegate = delegate
app.run()
