# Better 图标实验室规格

## 目标

让用户在 Better 内逐个比较已生成的品牌图标，并即时替换当前运行中的应用图标。选择跨启动保留，任何候选都必须经过统一的 macOS squircle 处理，避免再次出现方形插画直接作为 App Icon 的问题。

同时新增一个“活星微光”候选。它保留 C1 的星星轮廓、配色和左下生长意象，只增加克制的边缘微光和极少星尘，不使用火焰、复杂纹理或会破坏 32px 识别度的细节。

## 范围

- 新增侧边栏“图标实验室”页面。
- 展示 A1、A2、B1、B2、C1、C2 原稿，六个极光/磁场/晨雾效果候选，以及 C1 macOS squircle 和活星微光，共十四个候选。
- 点击候选后立即更新当前进程的 Dock 图标和 Better 内品牌图标。
- 使用 `UserDefaults` 保存候选 ID；下次启动恢复。
- 原始方形候选在运行时统一放入带透明外角的 squircle 安全框；已经是 macOS squircle 的候选保持原样。
- 构建 `Better.app` 时把受控候选目录复制到 Bundle。

## 不做

- 不让用户选择任意外部文件。
- 不重写已签名 App Bundle 的 `Better.icns`；Finder 中的静态应用文件图标继续使用正式默认图标。
- 不改变 `better.json`、押注、焦点或提醒数据。
- 不把特效做成动画、火焰或持续占用资源的渲染。

## 接口

- `AppIconOption`：候选 ID、名称、说明、资源文件名和渲染方式。
- `AppIconCatalog`：唯一候选清单与默认候选。
- `AppIconController`：加载资源、统一渲染、应用图标、持久化选择和暴露错误。
- `AppIconLabView`：分析说明、候选预览和选择操作。

## 错误行为

- 资源缺失、无法解码或无法渲染时，选择失败并在页面显示明确错误；不得静默回退成错误图标。
- 已保存的候选 ID 不再存在时，恢复正式默认候选并暴露说明。

## 验收标准

- 候选 ID 和资源文件名唯一，默认候选存在于目录中。
- 选择候选后 `NSApplication.applicationIconImage` 立即改变，侧边栏预览同步更新。
- 重新启动 Better 后恢复上次选择。
- 原始方图候选应用后具有透明外角和一致的 squircle 安全框。
- `dist/Better.app/Contents/Resources/IconCandidates` 包含目录中的候选 PNG。
- 图标选择不修改 `better.json`。
- 核心检查、Swift 构建、App Bundle 签名和现场切换验证通过。
