import AppKit
import WebKit

struct SessionState {
    var isActive = false
    var pendingHelpCalls: Set<String> = []
    var lastCompletedAt: Date?
    var lastActivityAt: Date?
}

final class CodexStatusMonitor {
    var onStateChange: ((String) -> Void)?

    private let sessionsRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".trae/cli/sessions")
    private var offsets: [URL: UInt64] = [:]
    private var remainders: [URL: String] = [:]
    private var sessionStates: [URL: SessionState] = [:]
    private var timer: DispatchSourceTimer?
    private let monitorQueue = DispatchQueue(label: "local.codex.pixelkitty.monitor", qos: .utility)
    private var lastEmittedState = ""
    private let dateParser: ISO8601DateFormatter = {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        return parser
    }()
    private let fractionalDateParser: ISO8601DateFormatter = {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser
    }()

    func start() {
        guard timer == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: monitorQueue)
        source.schedule(deadline: .now(), repeating: .milliseconds(800))
        source.setEventHandler { [weak self] in
            self?.poll()
        }
        timer = source
        source.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func poll() {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            emit("idle")
            return
        }

        let recentCutoff = Date().addingTimeInterval(-48 * 60 * 60)
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt >= recentCutoff,
                  let fileSize = values.fileSize else {
                continue
            }
            process(fileURL, fileSize: UInt64(fileSize))
        }
        emit(resolvedState())
    }

    private func process(_ fileURL: URL, fileSize: UInt64) {
        let initialWindow: UInt64 = 32_000_000
        let isInitialRead = offsets[fileURL] == nil
        var offset = offsets[fileURL] ?? (fileSize > initialWindow ? fileSize - initialWindow : 0)
        if fileSize < offset {
            offset = 0
            remainders[fileURL] = nil
            sessionStates[fileURL] = SessionState()
        }
        guard fileSize > offset,
              let handle = try? FileHandle(forReadingFrom: fileURL) else {
            offsets[fileURL] = fileSize
            return
        }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: offset)
            let data = try handle.readToEnd() ?? Data()
            offsets[fileURL] = fileSize
            guard var chunk = String(data: data, encoding: .utf8) else { return }
            if isInitialRead, offset > 0, let newline = chunk.firstIndex(of: "\n") {
                chunk = String(chunk[chunk.index(after: newline)...])
            }
            let combined = (remainders[fileURL] ?? "") + chunk
            var lines = combined.split(separator: "\n", omittingEmptySubsequences: false)
            remainders[fileURL] = lines.last.map(String.init) ?? ""
            if !combined.hasSuffix("\n") {
                lines.removeLast()
            } else {
                remainders[fileURL] = ""
            }
            for line in lines where !line.isEmpty {
                parse(String(line), from: fileURL)
            }
        } catch {
            offsets[fileURL] = offset
        }
    }

    private func parse(_ line: String, from fileURL: URL) {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let topType = object["type"] as? String,
              let payload = object["payload"] as? [String: Any] else {
            return
        }

        var state = sessionStates[fileURL] ?? SessionState()
        let eventDate = timestamp(from: object) ?? Date()
        state.lastActivityAt = eventDate
        if topType == "event_msg", let eventType = payload["type"] as? String {
            switch eventType {
            case "task_started":
                state.isActive = true
                state.pendingHelpCalls.removeAll()
            case "task_complete":
                state.isActive = false
                state.pendingHelpCalls.removeAll()
                state.lastCompletedAt = eventDate
            case "user_message":
                state.pendingHelpCalls.removeAll()
            default:
                break
            }
        }

        if topType == "response_item", let itemType = payload["type"] as? String {
            if itemType == "function_call" || itemType == "custom_tool_call" {
                let name = payload["name"] as? String ?? ""
                let arguments = payload["arguments"] as? String ?? ""
                let needsHelp = [
                    "AskUserQuestion",
                    "request_user_input",
                    "request_permissions"
                ].contains(name)
                    || arguments.contains("\"sandbox_permissions\":\"require_escalated\"")
                    || arguments.contains("\"sandbox_permissions\": \"require_escalated\"")
                if needsHelp {
                    let callID = payload["call_id"] as? String ?? "\(fileURL.path)-pending"
                    state.pendingHelpCalls.insert(callID)
                }
            }
            if itemType == "function_call_output" || itemType == "custom_tool_call_output" {
                if let callID = payload["call_id"] as? String {
                    state.pendingHelpCalls.remove(callID)
                }
            }
            if itemType == "message", payload["role"] as? String == "user" {
                state.pendingHelpCalls.removeAll()
            }
        }
        sessionStates[fileURL] = state
    }

    private func timestamp(from object: [String: Any]) -> Date? {
        guard let value = object["timestamp"] as? String else { return nil }
        return fractionalDateParser.date(from: value) ?? dateParser.date(from: value)
    }

    private func resolvedState() -> String {
        let now = Date()
        let activeTimeout: TimeInterval = 60
        let activeSessions = sessionStates.values.filter { state in
            guard state.isActive else { return false }
            guard let lastActivityAt = state.lastActivityAt else { return false }
            return now.timeIntervalSince(lastActivityAt) < activeTimeout
        }
        if activeSessions.contains(where: { !$0.pendingHelpCalls.isEmpty }) {
            return "help"
        }
        if !activeSessions.isEmpty {
            return "working"
        }
        let newestCompletion = sessionStates.values.compactMap(\.lastCompletedAt).max()
        if let newestCompletion, Date().timeIntervalSince(newestCompletion) < 4 {
            return "done"
        }
        return "idle"
    }

    private func emit(_ state: String) {
        guard state != lastEmittedState else { return }
        lastEmittedState = state
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?(state)
        }
    }
}

final class PetWebView: WKWebView {
    private enum Interaction {
        case dragging
        case resizing
    }

    private let aspectRatio: CGFloat = 214.0 / 240.0
    private let resizeHandleSize: CGFloat = 18
    private let minimumWidth: CGFloat = 90
    private let maximumWidth: CGFloat = 360
    private var interaction: Interaction?
    private var dragStart: NSPoint?
    private var windowStart: NSPoint?
    private var windowStartSize: NSSize?
    private var hoverTrackingArea: NSTrackingArea?
    var onHoverChange: ((Bool) -> Void)?

    private var resizeHandleRect: NSRect {
        NSRect(
            x: bounds.maxX - resizeHandleSize,
            y: isFlipped ? bounds.maxY - resizeHandleSize : bounds.minY,
            width: resizeHandleSize,
            height: resizeHandleSize
        )
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(resizeHandleRect, cursor: .resizeLeftRight)
    }

    override func updateTrackingAreas() {
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        updatePetHover(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updatePetHover(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }

    private func updatePetHover(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onHoverChange?(isPointInsideKitty(point))
    }

    private func isPointInsideKitty(_ point: NSPoint) -> Bool {
        guard bounds.width > 0, bounds.height > 0 else { return false }
        if resizeHandleRect.contains(point) {
            return false
        }

        let topY = isFlipped ? point.y : bounds.height - point.y
        let svgX = point.x / bounds.width * 240
        let svgY = topY / bounds.height * 214

        let head = pow((svgX - 112) / 88, 2) + pow((svgY - 82) / 70, 2) <= 1
        let bow = svgX >= 132 && svgX <= 210 && svgY >= 10 && svgY <= 66
        let bodyAndLaptop = svgX >= 46 && svgX <= 176 && svgY >= 104 && svgY <= 194
        let leftArm = svgX >= 54 && svgX <= 106 && svgY >= 110 && svgY <= 152
        let rightArm = svgX >= 132 && svgX <= 160 && svgY >= 118 && svgY <= 154

        return head || bow || bodyAndLaptop || leftArm || rightArm
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin
        windowStartSize = window?.frame.size
        let point = convert(event.locationInWindow, from: nil)
        interaction = resizeHandleRect.contains(point) ? .resizing : .dragging
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart, let windowStart, let windowStartSize, let window else { return }
        let current = NSEvent.mouseLocation
        switch interaction {
        case .resizing:
            let nextWidth = min(max(windowStartSize.width + current.x - dragStart.x, minimumWidth), maximumWidth)
            let nextSize = NSSize(width: nextWidth, height: round(nextWidth * aspectRatio))
            window.setFrame(
                NSRect(
                    x: windowStart.x,
                    y: windowStart.y + windowStartSize.height - nextSize.height,
                    width: nextSize.width,
                    height: nextSize.height
                ),
                display: true
            )
        case .dragging, nil:
            let next = NSPoint(
                x: windowStart.x + current.x - dragStart.x,
                y: windowStart.y + current.y - dragStart.y
            )
            window.setFrameOrigin(next)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if let frame = window?.frame {
            UserDefaults.standard.set(frame.origin.x, forKey: "petWindowX")
            UserDefaults.standard.set(frame.origin.y, forKey: "petWindowY")
            UserDefaults.standard.set(frame.width, forKey: "petWindowWidth")
        }
        interaction = nil
        dragStart = nil
        windowStart = nil
        windowStartSize = nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var window: NSPanel!
    private var webView: PetWebView!
    private var statusItem: NSStatusItem!
    private var stateItems: [String: NSMenuItem] = [:]
    private var automaticItem: NSMenuItem!
    private let monitor = CodexStatusMonitor()
    private var currentState = "idle"
    private var automaticMode = true
    private var isHoveringPet = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildWindow()
        buildStatusMenu()
        loadPet()
        monitor.onStateChange = { [weak self] state in
            guard let self, self.automaticMode else { return }
            self.applyState(state)
        }
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    private func buildWindow() {
        let defaultWidth: CGFloat = 120
        let aspectRatio: CGFloat = 214.0 / 240.0
        let savedWidth = UserDefaults.standard.object(forKey: "petWindowWidth") as? CGFloat
        let width = savedWidth ?? defaultWidth
        let size = NSSize(width: width, height: round(width * aspectRatio))
        let savedX = UserDefaults.standard.object(forKey: "petWindowX") as? CGFloat
        let savedY = UserDefaults.standard.object(forKey: "petWindowY") as? CGFloat
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let defaultOrigin = NSPoint(
            x: visible.maxX - size.width - 24,
            y: visible.minY + 24
        )
        let origin = NSPoint(x: savedX ?? defaultOrigin.x, y: savedY ?? defaultOrigin.y)

        window = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView = PetWebView(frame: NSRect(origin: .zero, size: size), configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.onHoverChange = { [weak self] isHovering in
            self?.setHoveringPet(isHovering)
        }
        window.contentView = webView
        window.acceptsMouseMovedEvents = true
        window.orderFrontRegardless()
    }

    private func buildStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Pixel Kitty")
            button.toolTip = "Pixel Kitty"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Pixel Kitty · Codex", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        automaticItem = NSMenuItem(
            title: "自动跟随 Codex",
            action: #selector(toggleAutomatic),
            keyEquivalent: ""
        )
        automaticItem.target = self
        automaticItem.state = .on
        menu.addItem(automaticItem)
        menu.addItem(.separator())

        addStateItem("休息 · idle", state: "idle", menu: menu)
        addStateItem("工作 · working", state: "working", menu: menu)
        addStateItem("完成 · done", state: "done", menu: menu)
        addStateItem("协助 · help", state: "help", menu: menu)

        menu.addItem(.separator())
        let showItem = NSMenuItem(title: "显示 Kitty", action: #selector(showPet), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        let hideItem = NSMenuItem(title: "隐藏 Kitty", action: #selector(hidePet), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出 Pixel Kitty", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateChecks()
    }

    private func addStateItem(_ title: String, state: String, menu: NSMenu) {
        let item = NSMenuItem(title: title, action: #selector(selectState(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = state
        stateItems[state] = item
        menu.addItem(item)
    }

    private func loadPet() {
        let appURL = Bundle.main.bundleURL
        let pageURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("hellokitty-pixel-pet.html")
        var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "desktop", value: "1")]
        webView.loadFileURL(components.url!, allowingReadAccessTo: pageURL.deletingLastPathComponent())
    }

    @objc private func selectState(_ sender: NSMenuItem) {
        guard let state = sender.representedObject as? String else { return }
        automaticMode = false
        automaticItem.state = .off
        applyState(state)
    }

    @objc private func toggleAutomatic() {
        automaticMode.toggle()
        automaticItem.state = automaticMode ? .on : .off
        if automaticMode {
            monitor.stop()
            monitor.start()
        }
    }

    private func applyState(_ state: String) {
        currentState = state
        UserDefaults.standard.set(state, forKey: "currentState")
        UserDefaults.standard.set(Date(), forKey: "stateUpdatedAt")
        renderCurrentState()
        updateChecks()
        if let button = statusItem.button {
            button.toolTip = "Pixel Kitty · \(state)"
        }
        window.orderFrontRegardless()
    }

    private func renderCurrentState() {
        let renderedState = currentState == "idle" && isHoveringPet ? "greet" : currentState
        webView.evaluateJavaScript("setPetState('\(renderedState)')")
    }

    private func setHoveringPet(_ isHovering: Bool) {
        guard isHoveringPet != isHovering else { return }
        isHoveringPet = isHovering
        if currentState == "idle" {
            renderCurrentState()
        }
    }

    private func updateChecks() {
        for (state, item) in stateItems {
            item.state = state == currentState ? .on : .off
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyState(currentState)
    }

    @objc private func showPet() {
        window.orderFrontRegardless()
    }

    @objc private func hidePet() {
        window.orderOut(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

if CommandLine.arguments.contains("--probe") {
    let monitor = CodexStatusMonitor()
    monitor.onStateChange = { state in
        print(state)
        fflush(stdout)
        exit(0)
    }
    monitor.start()
    DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
        print("unknown")
        fflush(stdout)
        exit(2)
    }
    RunLoop.main.run()
} else {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
