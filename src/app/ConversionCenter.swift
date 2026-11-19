import AppKit
import Foundation

// MARK: - 一个待转换的文件

struct Job: Identifiable {
    enum State: Equatable {
        case queued
        case preparing
        case running
        case done
        case failed(String)
        case skipped(String)

        var isTerminal: Bool {
            switch self {
            case .queued, .preparing, .running: return false
            case .done, .failed, .skipped: return true
            }
        }

        var isActive: Bool {
            switch self {
            case .queued, .preparing, .running: return true
            case .done, .failed, .skipped: return false
            }
        }
    }

    let id: String
    let url: URL
    var state: State = .queued
    var output: URL?
    var milliseconds: Int?

    var ext: String { url.pathExtension.lowercased() }
}

// MARK: - 转换中心

final class ConversionCenter: ObservableObject {
    static let shared = ConversionCenter()

    static let supportedExtensions: Set<String> = [
        "doc", "docx", "odt",
        "ppt", "pptx", "odp",
        "xls", "xlsx", "ods",
        "png", "jpg", "jpeg", "heic", "heif", "tif", "tiff", "bmp", "gif", "webp",
    ]

    @Published private(set) var jobs: [Job] = []
    @Published var engineError: String?
    @Published private(set) var batchSeconds: Double?

    @Published var overwriteExisting: Bool = UserDefaults.standard.bool(forKey: "overwriteExisting") {
        didSet { UserDefaults.standard.set(overwriteExisting, forKey: "overwriteExisting") }
    }

    /// 转换是串行的：同一时间只跑一个引擎实例，避免多个 LibreOffice 冷启动互相抢资源。
    private let conversionQueue = DispatchQueue(label: "com.qiji.pdfquick.convert", qos: .userInitiated)
    private var batchStart: Date?
    private var reservedDestinations: Set<String> = []

    private var workRoot: URL {
        Runner.supportDirectory.appendingPathComponent("Work", isDirectory: true)
    }

    private init() {
        if Runner.engine == nil { engineError = Runner.unavailableMessage }
        cleanStaleWork()
    }

    // MARK: 对外操作

    func enqueue(urls: [URL]) {
        guard !urls.isEmpty else { return }
        if Runner.engine == nil {
            engineError = Runner.unavailableMessage
            return
        }
        engineError = nil

        let files = expand(urls)
        guard !files.isEmpty else { return }

        if !jobs.contains(where: { $0.state.isActive }) {
            // 新的一批开始：先把上一批的结果收起来，界面只保留当前这批。
            jobs.removeAll { $0.state.isTerminal }
            batchStart = Date()
            batchSeconds = nil
        }

        var newJobs: [Job] = []
        for url in files {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                newJobs.append(Job(id: UUID().uuidString, url: url, state: .skipped("已经是 PDF 了")))
                continue
            }
            guard Self.supportedExtensions.contains(ext) else {
                newJobs.append(Job(id: UUID().uuidString, url: url,
                                   state: .skipped("暂不支持 .\(ext.isEmpty ? "?" : ext) 格式")))
                continue
            }
            if jobs.contains(where: { $0.url == url && $0.state.isActive }) { continue }
            newJobs.append(Job(id: UUID().uuidString, url: url))
        }

        guard !newJobs.isEmpty else { return }
        jobs.append(contentsOf: newJobs)
        for job in newJobs where job.state.isActive {
            prepare(job)
        }
        checkBatchFinished()
    }

    func clearFinished() {
        jobs.removeAll { $0.state.isTerminal }
    }

    func reveal(_ job: Job) {
        guard let output = job.output else { return }
        NSWorkspace.shared.activateFileViewerSelecting([output])
    }

    func revealOutputs() {
        let urls = jobs.compactMap { $0.state == .done ? $0.output : nil }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func openLog() {
        if FileManager.default.fileExists(atPath: Runner.logURL.path) {
            NSWorkspace.shared.open(Runner.logURL)
        } else {
            NSWorkspace.shared.open(Runner.supportDirectory)
        }
    }

    var isBusy: Bool { jobs.contains { $0.state.isActive } }

    var summary: String {
        if jobs.isEmpty { return "PDF 会保存在原文件旁边" }
        let total = jobs.count
        let done = jobs.filter { $0.state == .done }.count
        let finished = jobs.filter { $0.state.isTerminal }.count
        if finished < total {
            return "正在转换 \(finished + 1)/\(total)"
        }
        var text = "已生成 \(done) 个 PDF"
        let skipped = jobs.filter { if case .skipped = $0.state { return true }; return false }.count
        if skipped > 0 { text += "，跳过 \(skipped) 个" }
        let failed = jobs.filter { if case .failed = $0.state { return true }; return false }.count
        if failed > 0 { text += "，\(failed) 个失败" }
        if let seconds = batchSeconds, done > 0 {
            text += String(format: " · 用时 %.1f 秒", seconds)
        }
        return text
    }

    // MARK: 把源文件复制到自己的工作目录
    //
    // 引擎在后台进程里跑。如果直接让它读「文稿 / 桌面」里的文件，系统会把权限弹窗
    // 算到后台进程头上，而且没人点「允许」时会一直卡住。所以由应用自己完成和用户
    // 文件夹的读写：先复制进来，转换完再把 PDF 搬回原文件夹。

    private func prepare(_ job: Job) {
        let id = job.id
        let source = job.url
        let workDirectory = workRoot.appendingPathComponent(id, isDirectory: true)
        let tempInput = workDirectory.appendingPathComponent(source.lastPathComponent)
        let tempOutput = workDirectory.appendingPathComponent(
            source.deletingPathExtension().lastPathComponent + ".pdf")

        setState(id, .preparing)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fileManager = FileManager.default
            do {
                try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: tempInput.path) {
                    try fileManager.removeItem(at: tempInput)
                }
                try fileManager.copyItem(at: source, to: tempInput)
            } catch {
                DispatchQueue.main.async {
                    self?.setState(id, .failed(Self.readable(error)))
                    Self.removeDirectory(workDirectory)
                }
                return
            }
            DispatchQueue.main.async {
                guard let self, self.jobs.first(where: { $0.id == id })?.state == .preparing else { return }
                self.setState(id, .running)
                let profile = workDirectory.appendingPathComponent("profile", isDirectory: true)
                let started = Date()
                self.conversionQueue.async {
                    do {
                        try EngineRunner.convert(input: tempInput, output: tempOutput, profile: profile)
                        let elapsed = Int(Date().timeIntervalSince(started) * 1000)
                        DispatchQueue.main.async {
                            self.complete(id, tempOutput: tempOutput, milliseconds: elapsed,
                                           workDirectory: workDirectory)
                        }
                    } catch {
                        let message = Self.readable(error)
                        DispatchQueue.main.async {
                            self.fail(id, message: message, workDirectory: workDirectory)
                        }
                    }
                }
            }
        }
    }

    private func complete(_ jobID: String, tempOutput: URL, milliseconds: Int, workDirectory: URL) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[index].milliseconds = milliseconds
        moveToDestination(tempOutput, jobIndex: index, workDirectory: workDirectory)
        if jobs[index].state.isTerminal {
            Self.removeDirectory(workDirectory)
        }
        checkBatchFinished()
    }

    private func fail(_ jobID: String, message: String, workDirectory: URL) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[index].state = .failed(message)
        Self.removeDirectory(workDirectory)
        checkBatchFinished()
    }

    /// 把后台生成的 PDF 搬回源文件所在的文件夹。
    private func moveToDestination(_ tempPDF: URL, jobIndex: Int, workDirectory: URL) {
        let job = jobs[jobIndex]
        let folder = job.url.deletingLastPathComponent()
        let base = job.url.deletingPathExtension().lastPathComponent
        let fileManager = FileManager.default

        var destination = folder.appendingPathComponent(base + ".pdf")
        if overwriteExisting {
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
        } else {
            var index = 1
            while fileManager.fileExists(atPath: destination.path) || reservedDestinations.contains(destination.path) {
                destination = folder.appendingPathComponent("\(base) (\(index)).pdf")
                index += 1
            }
        }
        reservedDestinations.insert(destination.path)

        do {
            do {
                try fileManager.moveItem(at: tempPDF, to: destination)
            } catch {
                // 跨磁盘时 moveItem 可能失败，改成复制再删除。
                try fileManager.copyItem(at: tempPDF, to: destination)
                try? fileManager.removeItem(at: tempPDF)
            }
            try? fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destination.path)
            jobs[jobIndex].output = destination
            jobs[jobIndex].state = .done
        } catch {
            jobs[jobIndex].state = .failed("无法写入原文件夹：\(Self.readable(error))")
        }
        reservedDestinations.remove(destination.path)
    }

    // MARK: 状态

    private func setState(_ id: String, _ state: Job.State) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = state
    }

    private func checkBatchFinished() {
        guard !jobs.isEmpty, jobs.allSatisfy({ $0.state.isTerminal }) else { return }
        guard batchStart != nil else { return }
        if let start = batchStart {
            batchSeconds = Date().timeIntervalSince(start)
        }
        batchStart = nil
        if jobs.contains(where: { $0.state == .done }) {
            NSSound(named: "Glass")?.play()
        }
    }

    // MARK: 文件辅助

    private func expand(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                result.append(url)
                continue
            }
            if isDirectory.boolValue {
                let contents = (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])) ?? []
                let supported = contents.filter {
                    Self.supportedExtensions.contains($0.pathExtension.lowercased())
                        || $0.pathExtension.lowercased() == "pdf"
                }
                if supported.isEmpty {
                    result.append(url)
                } else {
                    result.append(contentsOf: supported.sorted { $0.lastPathComponent < $1.lastPathComponent })
                }
            } else {
                result.append(url)
            }
        }
        return result
    }

    private func cleanStaleWork() {
        let root = workRoot
        DispatchQueue.global(qos: .utility).async {
            Self.removeDirectory(root)
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
    }

    private static func removeDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func readable(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == 257 {
            return "没有权限读取这个文件。请在系统提示里允许「秒转 PDF」访问，"
                + "或到 系统设置 → 隐私与安全性 → 文件与文件夹 中开启。"
        }
        if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(EPERM) {
            return "没有权限读取这个文件。请在系统设置 → 隐私与安全性 中允许访问。"
        }
        return error.localizedDescription
    }
}
