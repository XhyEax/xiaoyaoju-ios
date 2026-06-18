# 逍遥居笔记 · iOS

国学经典阅读器 + 六爻（易经）起卦工具的 iOS 客户端（SwiftUI + SwiftData）。

> 本仓库是「逍遥居笔记」四端之一。一个产品、四端（微信小程序 / H5 `book.html` / iOS / Android）共用同一套领域模型与存储约定，功能需保持同步。

## 功能

- **典籍阅读**：道德经、庄子、列子、坛经、金刚经等；原文 / 注释 / 译文逐段对照，注释与译文可一键隐藏，全文搜索并高亮，章节收藏。
- **章节 / 段落笔记**：原文卡片右上角铅笔添加笔记，显示于原文下方；支持记录页汇总、跳转定位、批量导入导出、复制到剪贴板。
- **易经**：六十四卦查卦（卦辞 / 大象传 / 爻辞 / 变卦，可逐卦浏览），卦象笔记，正文可选中复制。
- **起卦**：点选六爻 / 摇一摇起卦，自动推演本卦、变卦、动爻，起卦记录（历史）可补记问题与心得、导入导出。
- **设置**：底部 Tab 可配置 1–3 部典籍、正文字号、夜间模式（手动切换）、阅读模式（只显示原文）。

## 技术

- SwiftUI + SwiftData（起卦记录），目标 iOS 17+，支持 iPad 横屏双栏与 Mac（Designed for iPad）。
- 数据：随包 JSON 兜底 + 远端 `config.json` / `<id>.json`（ETag 条件刷新），书单只增不减。
- 共享历史走 App Group，与独立六爻 App 互通。

## 目录结构

```
xiaoyaoju/
  xiaoyaojuApp.swift / ContentView.swift   # @main + 底部 TabView
  Models/   ClassicsDatabase 典籍/配置 · GuaDatabase/Hexagram/Divination 易经
            FavoritesStore 收藏 · NotesStore 笔记 · CastRecord(SwiftData)/RecordTransfer 记录
  Components/  ReadOnlyTextEditor（可选中只读文本）· EditableTextView
  Views/    NotesView 首页 · BooksView 书目/章节 · LookupView 查卦 · HexagramDetailView 卦详情
            RecordsView 收藏/笔记/历史 · CastingContent 起卦 · BookTabs 设置 · NoteEditorView 笔记编辑 …
```

## 构建

用 Xcode 打开 `xiaoyaoju.xcodeproj`，选 `xiaoyaoju` scheme 运行（iOS 17+ 设备 / 模拟器）。

## 存储约定（四端一致）

- 收藏 `fav_<bookId>`（易经 `bookId="yj"`）。
- 笔记 `note_<bookId>` → `{ 标识: 文本 }`；标识：单章 `<章>`、分段 `<章>-<段>`、易经 `<卦>-judgment/-image/-yao<行>`。
- 笔记导入导出 DTO：`{ book, key, text, title }`。

---

仅供学习与阅读参考 · 公众号「南冥有熊也」
