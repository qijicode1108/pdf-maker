import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var center: ConversionCenter
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            dropZone
                .padding(.horizontal, 22)
                .padding(.top, 18)

            Text("右键文件 →「快速操作」→ 秒转 PDF，也可以直接把文件拖到这里")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .padding(.top, 8)

            if let message = center.engineError {
                errorBanner(message)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
            }

            if center.jobs.isEmpty {
                Spacer(minLength: 0)
            } else {
                jobList
            }

            footer
        }
        .frame(width: 620, height: 448)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: 拖放区域

    private var dropZone: some View {
        VStack(spacing: 7) {
            Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                .font(.system(size: 30, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
            Text(isTargeted ? "松手，开始转换" : "把文件拖到这里")
                .font(.system(size: 15, weight: .semibold))
            Text("Word · PPT · Excel · 图片  →  PDF")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 126)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(isTargeted ? 0.13 : 0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    Color.accentColor.opacity(isTargeted ? 0.85 : 0.35),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.2,
                                       dash: isTargeted ? [] : [6, 5])
                )
        )
        .scaleEffect(isTargeted ? 1.01 : 1)
        .animation(.easeOut(duration: 0.14), value: isTargeted)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: chooseFiles)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted, perform: handleDrop)
        .help("点击选择文件，或把文件、文件夹拖进来")
    }

    // MARK: 任务列表

    private var jobList: some View {
        ScrollView {
            LazyVStack(spacing: 3) {
                ForEach(center.jobs) { job in
                    JobRow(job: job) {
                        if job.state == .done { center.reveal(job) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("查看日志") { center.openLog() }
                .controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.10)))
    }

    // MARK: 底栏

    private var footer: some View {
        HStack(spacing: 8) {
            Text(center.summary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if center.jobs.contains(where: { $0.state == .done }) {
                Button("在 Finder 中显示") { center.revealOutputs() }
                    .controlSize(.small)
            }
            if !center.isBusy && center.jobs.contains(where: { $0.state.isTerminal }) {
                Button("清空") { center.clearFinished() }
                    .controlSize(.small)
            }
            Menu {
                Toggle("覆盖同名 PDF", isOn: $center.overwriteExisting)
                Divider()
                Button("打开转换日志") { center.openLog() }
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("选项")
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: 交互

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = "选择要转成 PDF 的文件"
        panel.prompt = "转换"
        panel.message = "支持 Word、PowerPoint、Excel、常见图片格式"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            center.enqueue(urls: panel.urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let value = item as? URL {
                    url = value
                } else if let string = item as? String {
                    url = URL(fileURLWithPath: string)
                }
                if let url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            center.enqueue(urls: urls.sorted { $0.path < $1.path })
        }
        return true
    }
}

// MARK: - 单个任务行

struct JobRow: View {
    let job: Job
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            typeBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(job.url.lastPathComponent)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(hovering ? Color.primary.opacity(0.055) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onTap)
        .help(helpText)
    }

    private var typeBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(badgeColor.opacity(0.14))
            Image(systemName: badgeSymbol)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(badgeColor)
        }
        .frame(width: 28, height: 28)
    }

    @ViewBuilder private var trailing: some View {
        switch job.state {
        case .queued:
            Text("排队")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        case .preparing:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)
        case .running:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)
        case .done:
            HStack(spacing: 5) {
                if let milliseconds = job.milliseconds {
                    Text(secondsText(milliseconds))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            }
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        case .skipped:
            Image(systemName: "minus.circle")
                .foregroundStyle(.tertiary)
        }
    }

    private var detail: String {
        switch job.state {
        case .queued: return "等待转换"
        case .preparing: return "正在读取文件…"
        case .running: return "正在生成 PDF…"
        case .done: return "已保存 " + (job.output?.lastPathComponent ?? "PDF")
        case .failed(let message): return message
        case .skipped(let message): return message
        }
    }

    private var detailColor: Color {
        switch job.state {
        case .failed: return .orange
        case .done: return .secondary
        default: return .secondary
        }
    }

    private var helpText: String {
        switch job.state {
        case .done:
            return job.output?.path ?? ""
        case .failed(let message):
            return message
        default:
            return job.url.path
        }
    }

    private var badgeSymbol: String {
        switch job.ext {
        case "doc", "docx", "odt": return "doc.text.fill"
        case "ppt", "pptx", "odp": return "play.rectangle.fill"
        case "xls", "xlsx", "ods": return "tablecells.fill"
        case "png", "jpg", "jpeg", "heic", "heif", "tif", "tiff", "bmp", "gif", "webp":
            return "photo.fill"
        default: return "doc.fill"
        }
    }

    private var badgeColor: Color {
        switch job.ext {
        case "doc", "docx", "odt": return Color(red: 0.18, green: 0.42, blue: 0.85)
        case "ppt", "pptx", "odp": return Color(red: 0.85, green: 0.36, blue: 0.16)
        case "xls", "xlsx", "ods": return Color(red: 0.10, green: 0.55, blue: 0.32)
        case "png", "jpg", "jpeg", "heic", "heif", "tif", "tiff", "bmp", "gif", "webp":
            return Color(red: 0.55, green: 0.32, blue: 0.80)
        default: return Color(red: 0.45, green: 0.48, blue: 0.55)
        }
    }

    private func secondsText(_ milliseconds: Int) -> String {
        if milliseconds < 1000 { return "0.\(max(1, milliseconds / 100)) 秒" }
        return String(format: "%.1f 秒", Double(milliseconds) / 1000)
    }
}
