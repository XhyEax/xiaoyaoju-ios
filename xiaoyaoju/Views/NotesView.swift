// Views/NotesView.swift — Tab 1: 首页（逍遥居笔记）
import SwiftUI

struct NotesView: View {
    private let mpURL = URL(string: "https://mp.weixin.qq.com/s/fgDR9CJ38TJCd8Q5z2mV5g")!

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
                }
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("逍遥居笔记")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview { NotesView() }
