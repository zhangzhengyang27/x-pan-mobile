# X-Pan 桌面端适配计划

> 项目：X-Pan 个人分布式存储网盘 —— 移动端 App（Flutter）
> 目标：在现有 iOS/Android 代码基础上，扩展支持 **macOS / Windows / Linux** 桌面端
> 文档版本：v1.0　创建日期：2026-08-18

---

## 1. 背景与目标

### 1.1 现状
- 当前仅支持 iOS + Android，移动端单列布局 + 抽屉导航。
- 业务逻辑层（`services/`、`models/`、`providers/`、`utils/`）基本为纯 Dart，可高度复用。
- 依赖了若干 **仅支持移动端** 的平台插件（PDF 预览、WebView 在线预览、音视频播放后端等）。

### 1.2 适配目标
- **范围**：优先 macOS（与 iOS 生态接近，插件兼容性最好），再依次扩展 Windows、Linux。
- **原则**：业务逻辑零改动；平台插件差异收敛到薄封装层；UI 做响应式适配而非重写。
- **验收**：在桌面端可完成登录、文件浏览、上传/下载、各类型文件预览、实时通知等核心链路。

### 1.3 不纳入范围（本次）
- Web 端（`flutter_secure_storage`、通知、分片上传在 Web 支持有限）。
- Fuchsia / 嵌入式。

---

## 2. 现状盘点（已调研）

### 2.1 可复用部分（预计零改动）
| 模块 | 说明 |
|------|------|
| `models/` | 全部 `fromJson` 数据模型，纯 Dart |
| `services/`（API 服务） | 通过 `HttpClient.request`，Dio 跨平台 |
| `providers/` | Riverpod 状态，纯 Dart |
| `utils/` | format / csv_parser / md5_hash，纯 Dart |
| `core/network/` | Dio 封装 + 拦截器 + 续期，跨平台 |
| `core/theme/` | 主题，跨平台 |

### 2.2 需改造的平台插件
| 插件 | 用途 | 桌面支持现状 | 处理策略 |
|------|------|-------------|---------|
| `flutter_secure_storage` | Token/API Key | ✅ macOS/Windows/Linux | 仅需加桌面初始化 |
| `flutter_local_notifications` | 系统推送 | ✅ macOS/Linux/Windows | 加桌面初始化参数 |
| `file_picker` | 文件选择 | ✅ 全平台 | 低工作量 |
| `path_provider` | 路径 | ✅ 全平台 | 低工作量 |
| `open_filex` | 打开外部文件 | ⚠️ 桌面部分支持 | 封装 + 降级 |
| `cached_network_image` | 图片缓存 | ✅ 全平台 | 低工作量 |
| `just_audio` | 音频播放 | ⚠️ 桌面需换后端 | 封装 + 换 `media_kit` |
| `video_player` + `chewie` | 视频播放 | ⚠️ 桌面需换后端 | 封装 + 换 `video_player_media_kit` |
| `webview_flutter` | Office 在线预览 | ❌ 仅移动端 | **替换为桌面方案** |
| `flutter_pdfview` | PDF 预览 | ❌ 仅移动端 | **替换为 `syncfusion_flutter_pdfviewer`/`pdfx`** |

---

## 3. 实施路线图（分阶段）

### 阶段 0：环境与骨架准备（0.5 天）
1. 升级 Flutter 稳定版并启用桌面支持。
2. 生成平台骨架：
   ```bash
   flutter create --platforms=macos,windows,linux .
   ```
3. 确认各平台能 `flutter run -d macos` 跑通现有移动代码（暂时忽略预览崩溃）。
4. 建立桌面端统一 `Platform` 分支判断工具类（`utils/platform_utils.dart`）。
5. 配置 macOS 沙盒 / 网络权限（见 §4.4）。

**验收**：桌面端能启动 App 并进入登录页。

---

### 阶段 1：核心链路打通（安全/存储/网络/通知/文件选择）（2-3 天）

#### 1.1 安全存储（低）
- `TokenStorage` / `llm_service` 的 `FlutterSecureStorage` 在桌面端已原生支持，无需改调用代码。
- macOS 需在 `macos/Runner/*.entitlements` 配置 Keychain 访问（`keychain-access-groups`）。

#### 1.2 本地通知（低）
- `local_notification_service.dart` 的 `InitializationSettings` 增加 macOS/Linux 参数。
- macOS 需在 entitlements 声明通知权限。

#### 1.3 文件选择与下载（中）
- `file_picker` 桌面端可用；`home_page.dart` 上传入口需适配桌面目录选择。
- `download_service.dart` 直接使用了 `dio.download`（绕过了 `HttpClient.request`）——**桌面端同样存在 token 续期丢失风险**，建议本次一并收敛到 `HttpClient.request` 的流式下载封装。
- `open_filex` 桌面支持有限：封装 `FileOpener`，macOS 用 `open` 命令 / `url_launcher` 降级，Windows 用 `Process.start('start')`，失败时回退为「在文件管理器定位」。

**验收**：桌面端可登录、浏览、上传、下载并打开本地文件。

---

### 阶段 2：预览类插件替换（3-5 天）—— 工作量最大

#### 2.1 PDF 预览（高）
- 现状：`pdf_preview_page.dart` 用 `flutter_pdfview`（仅移动端）。
- 方案：替换为 `syncfusion_flutter_pdfviewer`（跨 macOS/Win/Linux，API 成熟）或 `pdfx`（轻量，支持桌面）。
- 封装 `PdfViewerFactory`，按平台返回对应实现；页面保持统一接口。

#### 2.2 Office 在线预览（高）
- 现状：`office_preview_page.dart` 用 `webview_flutter`（仅移动端）加载后端 office→pdf 预览直链。
- 方案（三选一，推荐先定 Windows 或 macOS）：
  - `desktop_webview_window`（跨桌面，Windows 需 WebView2 Runtime，macOS 用 WKWebView）
  - `webview_windows`（仅 Windows）
  - **降级兜底**：Office 预览本质是把后端转换出的 PDF 塞进 WebView，桌面端可直接改为「调用后端预览直链 → 交给 PDF 预览器渲染」或「下载后用系统默认 Office 打开」。
- 封装 `WebViewHost`，屏蔽平台差异；不支持的平台走兜底逻辑。

#### 2.3 视频播放（中）
- 现状：`chewie` + `video_player`（桌面端 `video_player` 支持有限）。
- 方案：封装 `VideoPlayerFactory`，桌面端切换到 `video_player_media_kit` / `media_kit`。

#### 2.4 音频播放（中）
- 现状：`just_audio`（桌面端需换后端）。
- 方案：封装 `AudioPlayerFactory`，桌面端用 `just_audio_media_kit` 或 `just_audio_windows` / `just_audio_mpv`。

#### 2.5 其余预览（低）
- 图片（`cached_network_image`）、文本/CSV/Markdown/XMind、均纯 Dart，直接复用。

**验收**：桌面端各文件类型均可正常预览，预览页行为与移动端一致。

---

### 阶段 3：响应式 UI 适配（3-5 天）

#### 3.1 布局框架
- 移动端：`Drawer` 抽屉导航 + 单列。
- 桌面端：引入 `LayoutBuilder` / `MediaQuery` 判断宽屏，宽屏切换为：
  - 左侧**侧边导航栏**（替换 Drawer）
  - 文件列表支持**多列网格**
  - 页面内容居中、留白合理，最大内容宽度限制（如 1200px）
- 建议引入自适应断点工具（如 `adaptive_navigation` / 自建 `ResponsiveLayout`）。

#### 3.2 逐页适配清单
| 页面 | 主要改动 |
|------|---------|
| `home_page.dart` | 导航抽屉 → 侧边栏；文件列表多列；上传入口适配桌面 |
| `login_page.dart` / `register_page.dart` | 卡片居中、限制宽度 |
| `dashboard_page.dart` | 卡片网格自适应 |
| 各 preview 页 | 全屏居中 + 工具栏适配 |
| `upload_task_page.dart` | 任务列表宽度自适应 |
| `settings_page.dart` | 表单/设置项宽度适配 |

#### 3.3 输入与交互
- 桌面端需支持键盘快捷键（回车提交、方向键导航、Delete 删除）。
- 鼠标右键菜单（可选增强）。
- 窗口尺寸变化时布局自适应。

**验收**：桌面端窗口缩放流畅、无布局溢出，主要页面宽屏体验合理。

---

### 阶段 4：平台构建与发布（2-3 天）

#### 4.1 macOS
- 配置 `DebugProfile.entitlements` / `Release.entitlements`：
  - 网络（`com.apple.security.network.client`）
  - Keychain 访问
  - 通知
  - 沙盒权限
- 配置 App 签名、图标（`Assets.xcassets`）。
- 打包：`flutter build macos` → `.app` / dmg。

#### 4.2 Windows
- 配置图标、应用名、窗口尺寸。
- 打包：`flutter build windows` → 安装包（Inno Setup / MSIX）。

#### 4.3 Linux
- 配置 `linux/` 相关（图标、desktop 文件）。
- 打包：`flutter build linux` → AppImage / deb。

#### 4.4 CI/CD
- 新增 macOS/Windows/Linux 构建流水线。
- 国内镜像：桌面构建同样依赖阿里云 Maven 镜像（已配置，需验证在桌面构建生效）。

**验收**：三个平台均可产出可分发安装包。

---

### 阶段 5：测试与回归（2 天）

1. 补充平台相关单元测试（如 `Platform` 分支、封装工厂）。
2. 在桌面端跑通核心链路 smoke test。
3. 移动端回归：确保引入的封装层不破坏 iOS/Android 行为。
4. `flutter analyze` 保持 0 错误；测试按文件分组运行。

---

## 4. 平台特有注意事项

### 4.1 下载 token 续期风险
- `download_service.dart` 目前直接用 `dio.download`，绕过了 `HttpClient.request` 的 token 续期能力。
- **建议在阶段 1 一并修复**：将下载也收敛到 `HttpClient.request` 的流式封装，避免桌面长文件下载 token 过期失败。

### 4.2 沙盒与文件访问
- macOS App Store 沙盒对文件系统访问受限，需合理使用 `path_provider` 的受支持目录。
- `open_filex` 打开外部文件在沙盒下可能受限，封装层需处理权限弹窗。

### 4.3 通知桌面差异
- Windows 通知依赖系统设置；Linux 需要通知服务（libnotify）。
- macOS 通知需用户在系统设置授权。

### 4.4 插件版本与兼容
- 涉及替换的插件需确认与当前 Dart/Flutter 版本（3.35 / 3.9）兼容。
- `flutter_secure_storage` 建议升级到支持桌面稳定版（如 ^10.x，需验证 API 兼容）。

---

## 5. 依赖变更清单

**新增依赖（桌面用）**
```yaml
dependencies:
  # PDF 预览替换（阶段2）
  syncfusion_flutter_pdfviewer: ^x   # 或 pdfx
  # Office 预览 WebView 替换（阶段2）
  desktop_webview_window: ^x         # 或 webview_windows
  # 音视频播放桌面后端（阶段2）
  media_kit: ^x
  media_kit_video: ^x
  media_kit_libs_video: ^x
  media_kit_libs_audio: ^x
  # 降级打开文件（阶段1）
  url_launcher: ^x
```

**移除/降级（桌面条件下不加载）**
- `flutter_pdfview`（移动端保留，桌面走替换）
- `webview_flutter`（同上）

> ⚠️ 上述版本号 `^x` 为占位，实施时需根据当前 pub 版本确认，并验证与 Flutter 3.35 / Dart 3.9 的兼容性。

---

## 6. 风险与降级预案

| 风险 | 影响 | 预案 |
|------|------|------|
| Office WebView 桌面替换难 | 高 | 直接「下载后用系统 Office 打开」或「渲染后端 PDF 直链」降级 |
| PDF 渲染库体积/性能 | 中 | 评估 `syncfusion`（功能全、体积大）vs `pdfx`（轻量） |
| 桌面插件后端不统一 | 中 | 统一用 `media_kit`（跨桌面）作为音视频后端 |
| macOS 沙盒权限复杂 | 中 | 先做非沙盒 Debug 版本，发布时再处理 |
| 响应式重构影响移动端 | 中 | 用 `LayoutBuilder` 分支而非重写，移动端逻辑零改动 |

---

## 7. 里程碑与排期（单人估算）

| 阶段 | 内容 | 工期 | 依赖 |
|------|------|------|------|
| 阶段 0 | 骨架与环境 | 0.5 天 | — |
| 阶段 1 | 核心链路（存储/通知/文件/下载） | 2-3 天 | 阶段 0 |
| 阶段 2 | 预览插件替换 | 3-5 天 | 阶段 1 |
| 阶段 3 | 响应式 UI | 3-5 天 | 阶段 2（可并行） |
| 阶段 4 | 平台构建与发布 | 2-3 天 | 阶段 3 |
| 阶段 5 | 测试与回归 | 2 天 | 全部 |

**合计：约 2.5 ~ 4 周（1 名 Flutter 开发）**

若仅做 **macOS**：可压缩至约 **1.5 ~ 2.5 周**。

---

## 8. 推荐的执行顺序（务实路线）

1. **先跑通 macOS**（插件兼容性最好，Keychain/AVPlayer 天然支持）。
2. **优先攻坚 PDF + Office 预览**（最大风险点，先验证可行性再铺开）。
3. 再做音视频后端替换与响应式 UI。
4. 最后扩展到 Windows / Linux 的构建发布。

---

## 9. 参考文档
- Flutter 官方桌面支持：`docs.flutter.dev/platform-integration/desktop`
- 插件桌面支持矩阵：`pub.dev` 各插件 README
- 项目开发规范：`AGENTS.md`
- 后端接口契约：`DEVELOPMENT.md`

---

## 10. 实施记录（2026-08-18 已完成）

### 本次实际适配范围
- **平台**：macOS + Windows（按用户决策，不含 Linux）
- **验收状态**：macOS 构建通过、全项目 analyze 0 错误、全部测试通过；Windows 需在 Windows 机器验证编译

### 已完成的改动清单
| 阶段 | 改动 |
|------|------|
| 0 骨架 | 生成 `macos/`、`windows/` 平台目录；macOS entitlements（网络 client/server + Keychain）；macOS Info.plist ATS 例外 |
| 1 核心链路 | 通知服务补充 macOS 初始化与权限；`flutter_secure_storage`/`file_picker`/`open_filex` 桌面开箱即用 |
| 2 预览 | 新增 `pdfx` 依赖；`PdfPreviewView` 组件（macOS `PdfViewPinch`/Windows `PdfView`）；PDF/Office 预览改 pdfx；视频/音频 macOS 正常、Windows 降级为「下载后系统打开」 |
| 3 响应式 | 新增 `responsive.dart`（`isDesktop`/`ResponsiveContent`）；home 桌面 NavigationRail 侧边栏；14 个二级页面居中限宽 |
| 4 构建配置 | macOS/Windows 应用名统一 "R Pan"；Windows 窗口标题/产品名/图标描述 |

### 已知限制（按用户决策保留）
- **Windows 通知**：当前 `flutter_local_notifications` 17.2.4 不支持 Windows（需升级插件到 19.0+ 且要求 Flutter 3.38+），待后续升级 Flutter 后补齐
- **Windows 视频/音频内嵌播放**：官方插件不直接支持，已降级为「下载后用系统播放器打开」
- **Windows 编译**：需在 Windows 环境执行 `flutter build windows` 验证

### 待办（后续迭代）
1. Windows 上验证编译与运行
2. 升级 Flutter 3.38+ 后补齐 Windows 通知
3. 可选：引入 `media_kit` 实现 Windows 内嵌音视频播放
4. 平台图标定制（macOS/Windows 应用图标）
