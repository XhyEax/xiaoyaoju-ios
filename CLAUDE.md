# 逍遥居笔记（xiaoyaoju）— iOS

国学经典阅读 + 六爻/易经起卦。SwiftUI + SwiftData。主 App target `xiaoyaoju` + Widget 扩展 target `XiaoyaojuWidgetsExtension`。

## 构建（本机仅命令行工具，用 Xcode-beta）

```bash
cd /Users/xhy/Documents/git/xiaoyaoju
export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
xcodebuild -scheme xiaoyaoju -destination 'generic/platform=iOS Simulator' build
```

> 编辑器里的 SourceKit「Cannot find type / No such module 'UIKit'」是工程外单文件解析噪音，以 `** BUILD SUCCEEDED **` 为准。无法跑模拟器，交互需在 Xcode 手动验证。

## ⚠️ 版本号：改 App 版本时必须同步改 Widget（否则上传报 ITMS-90473）

Widget 扩展和主 App 的版本号/构建号必须一致，否则 App Store Connect 校验失败：
`ITMS-90473 CFBundleShortVersionString 扩展值 与 App 不匹配`。

`project.pbxproj` 里**共 4 处**（App 的 Debug/Release + Widget 的 Debug/Release）：
- `MARKETING_VERSION`（= CFBundleShortVersionString，如 `1.0.1`）
- `CURRENT_PROJECT_VERSION`（= CFBundleVersion 构建号，如 `10100`）

改版本号时四处一起改成相同值（或在 Xcode 里把两个 target 的 Version/Build 设成一样）。

## 同步存储（iCloud）

- **收藏**：iCloud KVS（`NSUbiquitousKeyValueStore`，每条一个 key，本地 `UserDefaults` 也留一份）。
- **笔记 / 历史**：CloudKit。`NoteRecord` / `CastRecord` 同在一个 SwiftData 库（App Group `group.com.xhy.shared` 的 `CastRecords.store`）+ CloudKit 私有容器 `iCloud.com.xhy.xiaoyaoju` 镜像。
- **不变量（重要）**：`SharedStore.makeContainer()` 永远固定在 App Group 同一个 store 文件；CloudKit 打开失败时**只回退到同一文件的纯本地 `.none`**，绝不打开「默认位置的空库」——否则会造成历史数据观感丢失（曾踩坑）。
- CloudKit 模型要求每个属性可选或有默认值（`CastRecord`/`NoteRecord` 都补了默认值）。
- 发布前在 CloudKit Console 把 schema 从 Development 部署到 Production。

## Widget（XiaoyaojuWidgets/）

- 三个：每日一卦 / 每日一句 / 快速起卦（「最近一卦」已删）。
- 数据用脚本从 `xiaoyaoju/Data/guadata.json`、`daodejing.json` 生成精简 `widget_gua.json` / `widget_quotes.json` 打进扩展，离线按日确定性选取。
- 画廊里的分组名 = 主 App 显示名（`CFBundleDisplayName`「逍遥居笔记」），无法给 widget 单独设；各小组件名用 `.configurationDisplayName`。
- deep link URL（`xiaoyaoju://...`）已设但 App 端未注册 scheme/路由，目前点按仅打开 App。

## 数据备份（设置→数据）

`BackupData` 信封：`{ version, favorites:{kind:[Int]}, notes:[NoteDTO], records:[RecordDTO] }`，与 Android `BackupTransfer` 对齐，**iOS↔Android 互通**（历史记录 iOS 用 `date` ISO8601；Android 同时写 `date`+`id`）。导入为合并：历史按时间去重、收藏并集、笔记同标识覆盖；导入结果用 alert 展示。

## 关键文件

- `Models/SharedStore.swift` 容器（CloudKit + 安全回退）
- `Models/CastRecord.swift` / `Notes.swift`(NoteRecord+NotesStore) / `Favorites.swift`(KVS) / `RecordTransfer.swift`(DTO+BackupData+纯逻辑)
- `Views/RecordsView.swift`(容器) → `NotesPane` / `RecordsListPane` / `RecordDetailView` / `FavoritesView`
- `Views/FileExportSupport.swift` 导出：先转圈写临时文件，再 `UIDocumentPicker(forExporting:)`（避免 FileDocument 偶发权限错误）
- `Views/BookTabs.swift` 设置页（典籍 tab / 字号 / 爻一爻开关 / 全部数据导入导出）

## 工作约定

- git push 仅在用户明确指示时执行，不自动推送。
