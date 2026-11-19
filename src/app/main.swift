import AppKit
import SwiftUI

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        showWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 从 Finder 右键快速操作、拖到 Dock 图标、`open -a` 进来的文件都走这里。
    func application(_ application: NSApplication, open urls: [URL]) {
        showWindow()
        ConversionCenter.shared.enqueue(urls: urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    // MARK: 菜单

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "秒转 PDF")
        appMenu.addItem(withTitle: "关于 秒转 PDF",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())

        let openItem = NSMenuItem(title: "打开文件…", action: #selector(openDocument), keyEquivalent: "o")
        openItem.target = self
        appMenu.addItem(openItem)

        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 秒转 PDF",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 秒转 PDF",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func openDocument() {
        let panel = NSOpenPanel()
        panel.title = "选择要转成 PDF 的文件"
        panel.prompt = "转换"
        panel.message = "支持 Word、PowerPoint、Excel、常见图片格式"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            ConversionCenter.shared.enqueue(urls: panel.urls)
        }
    }

    // MARK: 窗口

    private func showWindow() {
        if window == nil { createWindow() }
        NSApp.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func createWindow() {
        let content = ContentView().environmentObject(ConversionCenter.shared)
        let hosting = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 448),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "秒转 PDF"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
    }
}

// MARK: - 入口

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.regular)
application.run()
