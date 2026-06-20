// Views/FileExportSupport.swift — 可靠导出：先写临时文件，再用文档选择器导出真实文件
import SwiftUI
import UIKit

enum FileExport {
    /// 把数据写到临时目录的真实文件，返回其 URL（失败 nil）
    static func writeTemp(_ data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }
}

/// 用于 .sheet(item:) 的可标识 URL
struct ExportURL: Identifiable { let url: URL; var id: String { url.path } }

/// 导出已存在文件的系统保存面板（forExporting，App 拥有该文件，无权限问题）
struct ExportFilePicker: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
}

/// 导出流程封装：转圈写临时文件 → 写完弹保存框。挂到任意 View 上：
/// `.exportFlow(state: $exportState)`，业务侧调用 `exportState.begin(filename:) { 生成Data }`
@Observable
final class ExportState {
    var preparing = false
    var item: ExportURL?
    var alert: String?

    /// makeData 在后台执行（避免大文件阻塞 UI）；调用前请在主线程把所需数据取好后传进闭包
    func begin(filename: String, makeData: @Sendable @escaping () -> Data?) {
        preparing = true
        Task.detached {
            let url = makeData().flatMap { FileExport.writeTemp($0, filename: filename) }
            await MainActor.run {
                self.preparing = false
                if let url { self.item = ExportURL(url: url) } else { self.alert = "导出失败" }
            }
        }
    }
}

extension View {
    func exportFlow(_ state: ExportState) -> some View {
        self
            .overlay {
                if state.preparing {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("正在导出…").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .sheet(item: Binding(get: { state.item }, set: { state.item = $0 })) { ExportFilePicker(url: $0.url) }
            .alert(state.alert ?? "", isPresented: Binding(
                get: { state.alert != nil }, set: { if !$0 { state.alert = nil } }
            )) { Button("好的", role: .cancel) {} }
    }
}
