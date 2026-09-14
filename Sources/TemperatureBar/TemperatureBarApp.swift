import AppKit
import SwiftUI

@main
struct TemperatureBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Status item is owned by AppDelegate (MenuBarExtra labels often stop
        // invalidating on macOS — FB11857447). Settings scene keeps the App alive.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = TemperatureStore()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installStatusItem()
        installPopover()
        store.onSample = { [weak self] in
            self?.refreshStatusTitle()
        }
        refreshStatusTitle()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    private func installPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 280, height: 200)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environment(store)
        )
        self.popover = popover
    }

    private func refreshStatusTitle() {
        guard let button = statusItem?.button else { return }
        button.title = store.menuBarText
        button.contentTintColor = statusTintColor
    }

    private var statusTintColor: NSColor? {
        guard let temp = store.current else { return nil }
        if temp >= 90 { return .systemRed }
        if temp >= 80 { return .systemOrange }
        return nil
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        // Keep status item unhighlighted after dismiss.
        statusItem?.button?.highlight(false)
    }
}
