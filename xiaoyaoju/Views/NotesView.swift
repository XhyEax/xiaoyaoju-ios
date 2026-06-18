// Views/NotesView.swift — Tab 1: 首页（逍遥居笔记）
import SwiftUI

struct NotesView: View {
    var preview = false   // 预览/审核模式：隐藏右上角眼睛与设置
    private let mpURL = URL(string: "https://mp.weixin.qq.com/s/fgDR9CJ38TJCd8Q5z2mV5g")!
    @State private var showSettings = false
    @AppStorage("appColorScheme") private var colorSchemeIndex = 0
    @AppStorage("hideNotes") private var hideNotes = false   // 阅读模式：隐藏笔记/注释/译文
    @State private var readingToast = false
    @State private var readingToastText = ""

    private var colorSchemeIcon: String {
        switch colorSchemeIndex {
        case 1: return "sun.max.fill"
        case 2: return "moon.stars.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    private func showReadingToast(_ text: String) {
        readingToastText = text
        withAnimation { readingToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { readingToast = false } }
    }

    /// App 版本号（取自 Info.plist）："版本号：1.0"
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "版本号：\(v)"
    }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 24)
                VStack(spacing: 0) {
                    Image("Xiaoyao")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
                    Text("逍遥居笔记")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(3)
                        .padding(.top, 22)
                    Text("国学经典与古籍研读")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.top, 8)
                    VStack(spacing: 12) {
                        Text("诸子经典 · 名家注疏")
                        Text("字里乾坤 · 卷中天地")
                        Text("致虚守静 · 心斋坐忘")
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.top, 28)
                }
                Spacer()
                VStack(spacing: 8) {
                    Link("公众号：南冥有熊也", destination: mpURL)
                        .font(.footnote)
                    Text("仅供学习和阅读参考")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("学习经典古籍，弘扬传统文化")
                        .font(.caption).foregroundStyle(.tertiary).tracking(1)
                        .padding(.top, 6)
                    Text(appVersion)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("逍遥居笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { colorSchemeIndex = (colorSchemeIndex + 1) % 3 } label: {
                        Image(systemName: colorSchemeIcon)
                    }
                }
                if !preview {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        // 阅读模式：眼睛，置于设置左边
                        Button {
                            hideNotes.toggle()
                            showReadingToast(hideNotes ? "阅读模式已开启，只显示原文" : "阅读模式已关闭")
                        } label: {
                            Image("IconEye").renderingMode(.template)
                                .foregroundStyle(hideNotes ? Color.accentColor : .secondary)
                        }
                        Button { showSettings = true } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) { BookSettingsView() }
            .overlay(alignment: .top) {
                if readingToast {
                    Text(readingToastText)
                        .font(.subheadline).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 11)
                        .background(.black.opacity(0.8), in: Capsule())
                        .padding(.top, 8)
                        .transition(.opacity)
                }
            }
        }
    }
}

#Preview { NotesView() }
