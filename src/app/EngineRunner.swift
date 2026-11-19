import Foundation

// MARK: - 运行环境

/// 应用自带的一切：引擎位置、数据目录、日志、探测。
/// 转换时直接调用内置的 LibreOffice 引擎（libreoffice-kit 的 dsoffice），
/// 不需要 Node.js、不需要 DeepSeek Harness。
enum Runner {
    static let supportDirectory = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/PDFQuick", isDirectory: true)

    static var logURL: URL { supportDirectory.appendingPathComponent("client.log") }

    /// 内置引擎：Contents/Resources/engine/{bin/dsoffice, program/...}
    struct Engine {
        let executable: URL
        let program: URL
        let root: URL
    }

    static var engine: Engine? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let root = resources.appendingPathComponent("engine", isDirectory: true)
        let executable = root.appendingPathComponent("bin/dsoffice")
        let program = root.appendingPathComponent(
            "program/LibreOfficeDev.app/Contents/Resources", isDirectory: true)
        let manager = FileManager.default
        guard manager.isExecutableFile(atPath: executable.path),
              manager.fileExists(atPath: program.path) else { return nil }
        return Engine(executable: executable, program: program, root: root)
    }

    static var unavailableMessage: String {
        "应用不完整：没有找到内置的转换引擎。请重新安装「秒转 PDF」。"
    }

    private static let logQueue = DispatchQueue(label: "com.qiji.pdfquick.log")

    /// 轻量日志，出问题时可以从界面里打开：~/Library/Application Support/PDFQuick/client.log
    static func log(_ message: String) {
        logQueue.async {
            let formatter = ISO8601DateFormatter()
            let line = "\(formatter.string(from: Date())) \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            try? FileManager.default.createDirectory(
                at: supportDirectory, withIntermediateDirectories: true)
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}

// MARK: - 转换

struct EngineError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum EngineRunner {
    /// 单个文件的上限，和引擎参数保持一致。
    static let maxInputBytes = 512 * 1024 * 1024
    static let maxOutputBytes = 512 * 1024 * 1024
    static let timeout: TimeInterval = 10 * 60

    /// 调用内置引擎把 input 转成 output。
    /// - 引擎参数来自 libreoffice-kit 的原生协议（dsoffice 的 CLI）。
    static func convert(input: URL, output: URL, profile: URL) throws {
        guard let engine = Runner.engine else {
            throw EngineError(message: Runner.unavailableMessage)
        }

        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: input.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw EngineError(message: "文件不存在或无法读取")
        }
        let size = (try? manager.attributesOfItem(atPath: input.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0 else { throw EngineError(message: "文件是空的") }
        guard size <= maxInputBytes else { throw EngineError(message: "文件太大，超出转换上限") }
        try validateContainer(input)

        try? manager.createDirectory(at: profile, withIntermediateDirectories: true)
        if manager.fileExists(atPath: output.path) {
            try? manager.removeItem(at: output)
        }

        let process = Process()
        process.executableURL = engine.executable
        process.arguments = [
            "--program-directory", engine.program.path,
            "--input-path", input.path,
            "--output-path", output.path,
            "--profile-directory", profile.path,
            "--max-output-bytes", String(maxOutputBytes),
            "--max-image-resolution", "144",
            "--format", "pdf",
            "--recalculate", "false",
        ]
        process.standardInput = FileHandle.nullDevice

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // 两个管道都要持续读，否则引擎写满缓冲区会卡住。
        var stdout = Data()
        var stderr = Data()
        let readers = DispatchGroup()
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            readers.leave()
        }
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            readers.leave()
        }

        do {
            try process.run()
        } catch {
            throw EngineError(message: "无法启动转换引擎：\(error.localizedDescription)")
        }

        let watchdog = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)

        readers.wait()
        process.waitUntilExit()
        watchdog.cancel()

        let stderrText = String(data: stderr, encoding: .utf8) ?? ""

        // 成功 / 失败都以一行 JSON 返回。
        if let json = try? JSONSerialization.jsonObject(with: stdout) as? [String: Any] {
            if (json["ok"] as? Bool) == true {
                let info = try manager.attributesOfItem(atPath: output.path)
                let bytes = (info[.size] as? NSNumber)?.intValue ?? 0
                guard bytes > 5 else {
                    throw EngineError(message: "生成的 PDF 为空")
                }
                let missing = (json["missingFonts"] as? [String]) ?? []
                Runner.log("ok \(input.lastPathComponent) -> \(output.lastPathComponent) \(bytes) bytes"
                    + (missing.isEmpty ? "" : " missingFonts=\(missing.joined(separator: ","))"))
                return
            }
            let message = friendly(code: json["code"] as? String, error: json["error"] as? String,
                                   stderr: stderrText)
            Runner.log("error \(input.lastPathComponent): \(message)")
            throw EngineError(message: message)
        }

        // 没有 JSON：超时被终止，或者引擎直接崩了。
        if !process.isRunning, process.terminationStatus == 15 {
            Runner.log("timeout \(input.lastPathComponent)")
            throw EngineError(message: "转换超时，文件可能过大")
        }
        let fallback = stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
        Runner.log("crash \(input.lastPathComponent) exit=\(process.terminationStatus) \(fallback.prefix(200))")
        throw EngineError(message: friendly(code: nil, error: fallback, stderr: stderrText))
    }

    /// 先看一眼文件头：后缀是 docx 却不是 zip（或者 doc 却不是 OLE），
    /// 说明文件损坏或被改过后缀，直接给出明确提示，不让引擎去猜。
    private static func validateContainer(_ input: URL) throws {
        let ext = input.pathExtension.lowercased()
        let zipBased: Set<String> = ["docx", "pptx", "xlsx", "odt", "odp", "ods"]
        let oleBased: Set<String> = ["doc", "ppt", "xls"]
        guard zipBased.contains(ext) || oleBased.contains(ext) else { return }

        let handle = try? FileHandle(forReadingFrom: input)
        let head = (try? handle?.read(upToCount: 4)) ?? nil
        try? handle?.close()
        guard let head, head.count == 4 else {
            throw EngineError(message: "文件已损坏、有密码，或格式无法解析")
        }
        let bytes = [UInt8](head)
        if zipBased.contains(ext), !(bytes[0] == 0x50 && bytes[1] == 0x4B) {
            throw EngineError(message: "文件已损坏、有密码，或格式无法解析")
        }
        if oleBased.contains(ext), !(bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11 && bytes[3] == 0xE0) {
            throw EngineError(message: "文件已损坏、有密码，或格式无法解析")
        }
    }

    // MARK: 文案

    private static func friendly(code: String?, error: String?, stderr: String) -> String {
        let raw = (error?.isEmpty == false ? error! : stderr)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.range(of: "password|encrypted|Encryption", options: [.regularExpression, .caseInsensitive]) != nil {
            return "文件有密码保护，无法转换"
        }
        switch code {
        case "input-too-large": return "文件太大，超出转换上限"
        case "output-too-large": return "生成的 PDF 过大"
        case "invalid-document": return "文件已损坏、有密码，或格式无法解析"
        case "unsupported-format": return "暂不支持此格式"
        case "timeout": return "转换超时，文件可能过大"
        case "unavailable": return Runner.unavailableMessage
        default: break
        }
        if raw.contains("已损坏") || raw.isEmpty {
            return "转换失败"
        }
        if raw.range(of: "[\\u4e00-\\u9fff]", options: .regularExpression) != nil {
            return raw
        }
        return String(raw.prefix(200))
    }
}
