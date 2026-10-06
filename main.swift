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
    ]

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
            NSColor.labelColor.setFill()
            let top = (rows - 7) / 2
            for (g, gx) in cols {
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
        out.append(NSAttributedString(string: "проект · модель\tскорость\tTTFT\tкэш\tкогда", attributes: [
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
        if let t = r["ttft"] as? Double { add("\t\(Int(t.rounded())) с", base) } else { add("\t—", dim) }
        if let c = r["cache"] as? Int {
            add("\t\(c)%" + ((r["cold"] as? Bool ?? false) ? "❄" : ""), base)
        } else { add("\t—", dim) }
        if let w = r["wait"] as? Int {
            add("\tждёт \(w)с", warn)
        } else {
            add("\t" + (r["ago"] as? String ?? "—"), dim)
        }
        return s
    }
}

// subscription windows (5-hour / weekly) as pixel meters: brand color, red once 80% is used
enum Limits {
    static func color(_ pct: Int, brand: NSColor) -> NSColor { pct >= 80 ? .systemRed : brand }

    // horizontal meter for the card header: `cells` squares, lit share = used share
    static func drawBar(_ pct: Int, at p: NSPoint, cells: Int, cell: CGFloat, brand: NSColor) {
        let lit = Int((Double(pct) / 100 * Double(cells)).rounded())
        for i in 0..<cells {
            (i < lit ? color(pct, brand: brand) : NSColor.labelColor.withAlphaComponent(0.12)).setFill()
            NSRect(x: p.x + CGFloat(i) * cell, y: p.y, width: cell * 3 / 4, height: cell * 3 / 4 * 1.6).fill()
        }
    }

    // vertical mini meters for the ears: one column per window, 6 cells tall
    static let rows = 6, cell: CGFloat = 2.5
    static func earWidth(_ n: Int) -> CGFloat { n == 0 ? 0 : CGFloat(2 * n - 1) * cell }

    static func earImage(_ limits: [[String: Any]], brand: NSColor) -> NSImage? {
        guard !limits.isEmpty else { return nil }
        let w = earWidth(limits.count), h = CGFloat(rows) * cell
        return NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            for (k, l) in limits.enumerated() {
                let pct = l["pct"] as? Int ?? 0
                let lit = pct > 0 ? max(1, Int((Double(pct) / 100 * Double(rows)).rounded())) : 0
                for j in 0..<rows {
                    (j < lit ? color(pct, brand: brand) : NSColor.labelColor.withAlphaComponent(0.2)).setFill()
                    NSRect(x: CGFloat(2 * k) * cell, y: CGFloat(j) * cell, width: cell * 0.8, height: cell * 0.8).fill()
                }
            }
            return true
        }
    }
}

let noSessions = "нет активных сессий за 2 ч"

func sessionCount(_ n: Int) -> String {
    let word = n % 10 == 1 && n % 100 != 11 ? "сессия"
        : (2...4).contains(n % 10) && !(12...14).contains(n % 100) ? "сессии" : "сессий"
    return "\(n) \(word)"
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

// hover card, scoreboard rows: chat title over a mono details line, mini speed history and LED speed on the right
final class TilesView: NSView {
    var sections: [(src: String, name: String, rows: [[String: Any]])] = [] { didSet { needsDisplay = true } }
    var limits: [String: [[String: Any]]] = [:]
    // rows that open their chat, in this view's flipped coordinates; filled while drawing
    private(set) var links: [(rect: NSRect, url: URL)] = []
    var hoverRow: Int? = nil
    static let pad: CGFloat = 14, headH: CGFloat = 26, rowH: CGFloat = 40, sepH: CGFloat = 14, emptyH: CGFloat = 20
    static let digitCell: CGFloat = 2.6, histCell: CGFloat = 3.5, histRows = 7

    override var isFlipped: Bool { true }

    static func height(_ sections: [(src: String, name: String, rows: [[String: Any]])]) -> CGFloat {
        var h = pad - 2
        for (i, s) in sections.enumerated() {
            if i > 0 { h += sepH }
            h += headH + (s.rows.isEmpty ? emptyH : CGFloat(s.rows.count) * rowH)
        }
        return h + pad
    }

    static func brand(_ src: String) -> NSColor {
        src == "claude" ? DotLogo.claudeColor
            : (DotLogo.codexFrom.blended(withFraction: 0.45, of: DotLogo.codexTo) ?? DotLogo.codexFrom)
    }

    func link(at p: NSPoint) -> (index: Int, url: URL)? {
        links.firstIndex { $0.rect.contains(p) }.map { ($0, links[$0].url) }
    }

    override func draw(_ dirtyRect: NSRect) {
        links = []
        let w = bounds.width
        var y = Self.pad - 2
        let sec = NSColor.secondaryLabelColor
        for (i, s) in sections.enumerated() {
            if i > 0 { y += Self.sepH }
            DotLogo.image(s.src, size: 14, phase: -1, lit: true)?.draw(
                in: NSRect(x: Self.pad, y: y + 3, width: 14, height: 14), from: .zero, operation: .sourceOver,
                fraction: 1, respectFlipped: true, hints: nil)
            DotFont.draw(s.name.uppercased(), at: NSPoint(x: Self.pad + 22, y: y + 3), cell: 2, color: .labelColor)
            if let ls = limits[s.src], !ls.isEmpty {
                // right-aligned "5ч ▮▮▮▯▯ 42%  нед ▮▯▯▯▯ 28%"; it replaces the session count
                let mono = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
                var x = w - Self.pad
                for l in ls.reversed() {
                    let pct = l["pct"] as? Int ?? 0
                    let num = text("\(pct)%", mono, pct >= 80 ? .systemRed : .labelColor)
                    x -= num.size().width
                    num.draw(at: NSPoint(x: x, y: y + 3))
                    x -= 5 + 10 * 4
                    Limits.drawBar(pct, at: NSPoint(x: x, y: y + 6), cells: 10, cell: 4, brand: Self.brand(s.src))
                    let name = text(l["name"] as? String ?? "", mono, sec)
                    x -= 5 + name.size().width
                    name.draw(at: NSPoint(x: x, y: y + 3))
                    x -= 12
                }
            } else {
                let cnt = text(sessionCount(s.rows.count), .systemFont(ofSize: 11.5), sec)
                cnt.draw(at: NSPoint(x: w - Self.pad - cnt.size().width, y: y + 2))
            }
            y += Self.headH
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
        if chat.isEmpty { chat = "Без названия" }
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
        if let t = r["ttft"] as? Double { parts.append("TTFT \(Int(t.rounded()))с") }
        if let c = r["cache"] as? Int { parts.append("кэш \(c)%" + ((r["cold"] as? Bool ?? false) ? "❄" : "")) }
        if let a = r["agents"] as? Int, a > 0 { parts.append("агент \(a)") }
        d.append(text(parts.map { " · " + $0 }.joined(), mono, sec))
        if let e = r["errs"] as? Int, e > 0 { d.append(text(" · ⚠\(e)", mono, .systemRed)) }
        if let wt = r["wait"] as? Int {
            d.append(text(" · ждёт \(wt)с", mono, .systemYellow))
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
    let meters = [CALayer(), CALayer()]
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
        for l in logos + texts + meters {
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
        if !expanded { onHover?(true) } else { setHoverRow(tiles.link(at: tilesPoint(event))?.index) }
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }  // the panel never becomes key
    var onOpen: ((URL) -> Void)?

    override func mouseDown(with event: NSEvent) {
        guard expanded, !animating, let hit = tiles.link(at: tilesPoint(event)) else { return }
        onOpen?(hit.url)
    }

    // window point → TilesView (flipped) point inside the card raster
    func tilesPoint(_ event: NSEvent) -> NSPoint {
        let p = convert(event.locationInWindow, from: nil), r = contentRect
        return NSPoint(x: p.x - r.minX, y: r.maxY - p.y)
    }

    func setHoverRow(_ i: Int?) {
        guard i != tiles.hoverRow else { return }
        tiles.hoverRow = i
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
        if on { tiles.hoverRow = nil; renderContent() }
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
    func place(side i: Int, logoW: CGFloat, textW: CGFloat, showText: Bool, height h: CGFloat, meterW: CGFloat,
               animated: Bool) {
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
        logos[i].frame = NSRect(x: logoX.rounded(), y: y, width: logoW, height: h)
        // limit meters sit on the outer side: left of the left logo, right of the right ear's text
        let mh = CGFloat(Limits.rows) * Limits.cell
        let meterX = i == 0 ? logoX - NotchView.meterGap - meterW
            : (showText ? textX + textW : logoX + logoW) + NotchView.meterGap
        meters[i].frame = NSRect(x: meterX.rounded(), y: (bounds.height - notch.height + (notch.height - mh) / 2).rounded(),
                                 width: meterW, height: mh)
        texts[i].frame = NSRect(x: textX.rounded(), y: y, width: textW, height: h)
        texts[i].opacity = showText ? 1 : 0
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
            island.tiles.limits = limitsBySrc
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

    func sections() -> [(src: String, name: String, rows: [[String: Any]])] {
        providers.map { (src: $0.src, name: $0.name, rows: data[$0.src]?["rows"] as? [[String: Any]] ?? []) }
    }

    func limits(_ i: Int) -> [[String: Any]] { data[providers[i].src]?["limits"] as? [[String: Any]] ?? [] }
    func meterW(_ i: Int) -> CGFloat { Limits.earWidth(limits(i).count) }
    var limitsBySrc: [String: [[String: Any]]] {
        Dictionary(uniqueKeysWithValues: providers.indices.map { (providers[$0].src, limits($0)) })
    }

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
            h += TilesView.height(island.tiles.sections) + NotchView.margin
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
            island.meters[i].opacity = running[i] ? 1 : 0
            CATransaction.commit()
        }
    }

    func update(_ doc: [String: Any], alive: Set<String>) {
        let wasRunning = running
        running = providers.map { alive.contains($0.src) }
        for p in providers {
            let d = doc[p.src] as? [String: Any] ?? [:]
            data[p.src] = d
            lines[p.src] = DotLogo.line(src: p.src, live: d["live"] as? Bool ?? false, text: d["title"] as? String ?? "⚪")
        }
        if hovered {
            island.tiles.limits = limitsBySrc
            island.setSections(sections())
        }
        // ear meters: two tiny images re-rendered per poll
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for i in 0..<2 {
            var cg: CGImage?
            if let img = Limits.earImage(limits(i), brand: TilesView.brand(providers[i].src)) {
                // rasterize at 2x so the 2.5 pt squares stay crisp
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(img.size.width * 2), pixelsHigh: Int(img.size.height * 2),
                                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                rep.size = img.size
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                island.effectiveAppearance.performAsCurrentDrawingAppearance { img.draw(in: NSRect(origin: .zero, size: img.size)) }
                NSGraphicsContext.restoreGraphicsState()
                cg = rep.cgImage
            }
            island.meters[i].contents = cg
        }
        CATransaction.commit()
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
    // collect.py 与二进制同目录:仓库 clone 到哪都能跑,无硬编码路径
    let script = URL(fileURLWithPath: Bundle.main.executablePath ?? CommandLine.arguments[0])
        .resolvingSymlinksInPath().deletingLastPathComponent()
        .appendingPathComponent("collect.py").path

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMode()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.setupMode()
            self?.refresh()  // fill the new UI now instead of showing ⚪ until the next poll
        }
        refresh()
    }

    // notch island on a notched built-in display; status-bar icons otherwise
    func setupMode() {
        if let screen = NSScreen.screens.first(where: { $0.hasNotch }) {
            if notch?.screen != screen || notch == nil {
                items = []
                notch = NotchController(screen: screen)
            }
        } else if notch != nil || items.isEmpty {
            notch = nil
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
            let alive = wantsAlive ? Running.scan() : []
            DispatchQueue.main.async {
                if let doc {
                    self.anyLive = providers.contains { (doc[$0.src] as? [String: Any])?["live"] as? Bool ?? false }
                    self.notch?.update(doc, alive: alive)
                    for item in self.items { item.update(doc[item.src] as? [String: Any] ?? [:]) }
                }
                self.setAnimating(self.anyLive)
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
