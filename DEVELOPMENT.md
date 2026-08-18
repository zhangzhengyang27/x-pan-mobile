# X-Pan 移动端开发文档

X-Pan 个人分布式存储网盘的移动端 App，基于 **Flutter 3.35 / Dart 3.9**，仅面向 iOS + Android。

本文档面向开发者，涵盖架构设计、目录结构、模块说明、开发规范、测试与发布。

---

## 1. 技术栈

| 层 | 选型 | 说明 |
|----|------|------|
| 框架 | Flutter 3.35 | 单代码库编译 iOS + Android |
| 状态管理 | Riverpod（`flutter_riverpod` 2.x） | StateNotifier + Provider |
| 网络 | Dio 5.x | 统一拦截器 + 认证 + 分片上传 |
| 本地存储 | SharedPreferences | Token / 上传任务 / 最近访问 / AI Key |
| 路由 | go_router 14.x | 声明式路由 + 登录态守卫 |
| 异步 | Future / Stream | 预览、WebSocket |

### 核心依赖

| 用途 | 包 |
|------|-----|
| 文件选择 / 下载 / 打开 | `file_picker` / `path_provider` / `open_filex` |
| 图片缓存 | `cached_network_image` |
| 视频 / 音频 | `video_player` + `chewie` / `just_audio` |
| PDF 预览 | `flutter_pdfview` |
| Office 预览 | `webview_flutter` |
| Markdown / XMind | `flutter_markdown` / `archive` |
| WebSocket 通知 | `web_socket_channel` |
| 加密（MD5 秒传） | `crypto` |

---

## 2. 目录结构

```
lib/
├── main.dart                    # 入口（ProviderScope + XPanApp）
├── core/
│   ├── config/app_config.dart   # API 地址 / 超时 / 分片大小
│   ├── theme/app_theme.dart     # 明暗主题（品牌色 #0070f3）
│   ├── network/http_client.dart # Dio 封装 + 认证/续期/异常拦截
│   └── storage/                 # Token / 上传任务 / 最近访问
├── models/                      # 后端数据结构
│   ├── api_response.dart        # R<T> 统一响应 / PageVO
│   ├── file_vo.dart             # FileVO + FileType 枚举
│   ├── file_version.dart        # 文件版本
│   ├── folder_node.dart         # 文件夹树（移动/复制）
│   └── user_info.dart           # 用户信息
├── services/                    # API 服务层（每模块一个）
│   ├── user_service.dart        # 用户 + 文件 + 版本
│   ├── share_service.dart       # 分享
│   ├── upload_service.dart      # 分片上传 / 秒传 / 断点续传
│   ├── download_service.dart    # 下载
│   ├── favorite_service.dart    # 收藏
│   ├── dedup_service.dart       # 去重
│   ├── vault_service.dart       # 保险箱
│   ├── device_service.dart      # 设备管理
│   ├── extract_service.dart     # 在线解压
│   ├── offline_service.dart     # 离线下载
│   ├── recycle_service.dart     # 回收站
│   ├── preview_service.dart     # 文档预览任务
│   ├── file_tag_service.dart    # 文件标签
│   ├── llm_service.dart         # DeepSeek LLM
│   ├── ai_file_service.dart     # AI 摘要/重命名
│   └── notification_service.dart# WebSocket 通知
├── providers/                   # Riverpod 状态
│   ├── auth_provider.dart       # 认证状态
│   ├── file_provider.dart       # 文件列表 + 导航栈
│   ├── upload_provider.dart     # 上传队列
│   └── notification_provider.dart # 通知中心
├── router/app_router.dart       # 路由 + 登录守卫
├── pages/                       # 页面
├── widgets/                     # 通用组件
│   ├── file_type_icon.dart      # 文件类型图标
│   ├── folder_picker_dialog.dart# 文件夹选择器
│   └── tag_dialog.dart          # 标签编辑
└── utils/
    ├── format.dart              # 文件大小格式化
    └── csv_parser.dart          # CSV 解析器
```

---

## 3. 核心架构

### 3.1 网络层（`core/network/http_client.dart`）

统一入口 `HttpClient.instance.request<T>()`：

- **认证注入**：请求头自动携带 `Authorization`，并从 `TokenStorage` 读取
- **Token 续期**：响应头 `new-access-token` 自动更新
- **统一响应**：`code == 0` 成功返回 `data`；`code == 10` 抛 `NeedReloginException`；其余抛 `ApiException`
- **额外请求头**：`extraHeaders` 参数支持分享等场景的 `Share-Token`

```dart
await HttpClient.instance.request<T>(
  '/path',
  method: 'POST',
  query: {...},
  data: {...},
  dataDecoder: (json) => T.fromJson(json),
);
```

### 3.2 认证流（`auth_provider.dart` + `router/app_router.dart`）

- `AuthNotifier.bootstrap()`：启动时读取 Token 恢复登录态
- go_router 通过 `redirect` 根据 `AuthStatus` 拦截未登录访问
- 登录成功 → `state = authenticated` → 路由自动跳主页

### 3.3 上传（`upload_provider.dart` + `upload_service.dart`）

- **分片**：5MB，`POST /file/chunk-upload`
- **秒传**：`POST /file/sec-upload`（MD5 命中直接完成）
- **断点续传**：GET `/file/chunk-upload` 返回 `uploadedChunks`，跳过已上传分片
- **跨重启恢复**：任务元信息持久化到 SharedPreferences，启动时检测提示恢复
- **队列**：`UploadManager` 串行处理，支持取消/重试/移除

### 3.4 预览分发（`home_page.dart` `_openFile`）

按 `FileType` + 扩展名路由：

| 类型 | 页面 |
|------|------|
| image | `ImagePreviewPage` |
| video / audio | `VideoPreviewPage` / `AudioPreviewPage` |
| pdf | `PDFPreviewPage` |
| csv | `CsvPreviewPage` |
| txt / code | `TextPreviewPage` |
| word / excel / ppt | `OfficePreviewPage`（webview + 异步转换任务） |
| .xmind | `XmindPreviewPage`（解压 content.json） |
| 其他 | 下载后打开 |

### 3.5 WebSocket 通知（`notification_service.dart`）

- 连接：`ws://host/ws/notification?token=xxx`（从 API base URL 推导）
- 心跳：客户端 25s ping，收到服务端 ping 回 PONG
- 重连：指数退避，最多 8 次
- 消息类型：`SYSTEM_NOTICE` / `UPLOAD_FINISHED` / `OFFLINE_TASK_UPDATE` / `OFFLINE_TASK_REMOVED` / `SHARE_STATS_UPDATE`

---

## 4. 与后端 API 契约对齐

移动端独立维护，**仅共享后端 HTTP API 契约**（对应前端 `src/types/index.ts` 与 `src/api/*`）。

### 统一约定

- 统一响应 `R<T> = { code, message, data }`
- `code == 0` 成功，`code == 10` 需重新登录
- 多 ID 用 `__,__` 分隔（如 `fileIds`）
- 认证：请求头 `Authorization`，续期 `new-access-token`

### 关键接口速查

| 功能 | 方法 / 路径 |
|------|------------|
| 登录 / 注册 / 退出 | POST `/user/login` `/user/register` `/user/exit` |
| 密码修改 / 找回 | POST `/user/password/change` `/user/answer/check` `/user/password/reset` |
| 文件列表 / 搜索 | GET `/files` `/file/search` |
| 分片上传 | POST `/file/chunk-upload` `/file/sec-upload` `/file/merge` |
| 预览直链 | POST `/file/preview/url?fileId=` |
| 分享 | GET `/share` POST `/share` `/share/save` `/share/code/check` |
| 分享 Token | 请求头 `Share-Token` |
| 回收站 | GET `/recycles` PUT `/recycle/restore` DELETE `/recycle` |
| 离线下载 | POST `/offline/create` GET `/offline/list` |
| 在线解压 | POST `/file/extract` GET `/file/extract/progress` |
| 版本历史 | GET `/file/versions` POST `/file/rollback` |
| 收藏 | POST `/favorite/add` `/favorite/remove` GET `/favorite/list` |
| 去重 | GET `/file/dedup/list` `/file/dedup/stat` POST `/file/dedup/release` |
| 保险箱 | GET `/vault/status` POST `/vault/setup` `/vault/unlock` `/vault/lock` `/vault/move` |
| 设备 | GET `/device/list` POST `/device/logout` |
| 标签 | POST `/file/auto-tag` GET `/file/{id}/tags` |
| 文档预览任务 | POST `/preview/office/{id}` GET `/preview/url/{taskId}` |
| 文本提取 | GET `/file/{id}/text-extract` |

---

## 5. 开发指南

### 环境准备

```bash
# 安装 Flutter 3.35+
flutter --version

# 安装依赖
cd x-pan-mobile
flutter pub get
```

### 配置后端地址

通过 `--dart-define` 传入（默认 `http://localhost:8081`）：

```bash
# iOS 模拟器
flutter run --dart-define=X_PAN_API_BASE_URL=http://localhost:8081

# Android 模拟器（宿主机）
flutter run --dart-define=X_PAN_API_BASE_URL=http://10.0.2.2:8081

# 真机（局域网 IP）
flutter run --dart-define=X_PAN_API_BASE_URL=http://192.168.x.x:8081
```

> 后端为 `http://` 明文时，Android 需 `android:usesCleartextTraffic="true"`，iOS 需 ATS 例外（均已配置）。

### 常用命令

```bash
flutter pub get      # 安装依赖
flutter analyze      # 静态检查
flutter test         # 运行测试
flutter run          # 运行（debug）
flutter build apk    # Android 打包
flutter build ios    # iOS 打包
flutter test --coverage  # 测试覆盖率
```

### 新增一个 API 服务

1. 在 `services/` 新建 `xxx_service.dart`，实现为**单例**
2. 用 `HttpClient.instance.request<T>()` 封装接口
3. 在 `models/` 添加对应的 `fromJson`
4. 在页面调用 `XxxService.instance.xxx()`

示例：

```dart
class XxxService {
  XxxService._();
  static final XxxService instance = XxxService._();
  final HttpClient _http = HttpClient.instance;

  Future<Xxx> list() {
    return _http.request<Xxx>(
      '/xxx/list',
      dataDecoder: (json) => Xxx.fromJson(json as Map<String, dynamic>),
    );
  }
}
```

### 新增一个页面

1. 在 `pages/` 创建页面
2. 页面用 `ConsumerStatefulWidget` 或 `ConsumerWidget` 读取 Riverpod 状态
3. 普通导航用 `Navigator.push`（如预览页）；一级导航在主页 Drawer 或 AppBar 添加入口

---

## 6. 测试

### 测试覆盖范围

| 测试文件 | 覆盖 |
|---------|------|
| `test/models_test.dart` | `ApiResponse` / `PageVO` / `FileVO` / `UserInfo` 解析 |
| `test/utils_test.dart` | 文件大小格式化 / 数值解析 |
| `test/csv_parser_test.dart` | CSV 解析（引号/转义/分隔符/换行） |
| `test/share_version_test.dart` | `ShareVO` / `ShareDetail` / `FileVersion` 解析 |
| `test/notification_test.dart` | 通知消息解析 |
| `test/md5_hash_test.dart` | isolate MD5 计算（含跨分块大文件） |
| `test/notification_throttle_test.dart` | 通知节流（去重窗口 / 超时恢复 / 不同通知） |
| `test/widget_test.dart` | App smoke test |
| `test/login_page_test.dart` | 登录页（渲染 / 表单校验 / mock 登录 / 错误提示 / 密码可见性 / 跳转） |
| `test/notification_page_test.dart` | 通知中心（空态 / 列表 / 清空） |

### 页面级测试（mock 网络）

页面级测试通过 **Riverpod override** 注入 mock 依赖，不触发真实网络：

```dart
// 例：登录页测试，override authProvider 为 FakeNotifier
final container = ProviderContainer(
  overrides: [
    authProvider.overrideWith((ref) => fakeAuth),
  ],
);
await tester.pumpWidget(
  UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: LoginPage()),
  ),
);
```

- Service 层构造函数已调整为公开（便于测试子类化），如 `UserService()`
- 测试辅助方法用 `@visibleForTesting` 标注（如 `NotificationManager.testInjectNotice`）

### 运行

```bash
flutter test                # 全部测试
flutter test test/models_test.dart  # 单文件
flutter test --coverage     # 覆盖率
```

### 新增测试规范

- 模型测试：验证 `fromJson` 对字段缺失、类型兼容（如 `fileSize` 字符串/数字）、默认值的处理
- 工具测试：纯函数边界值（0、大数、非法输入）
- 不依赖网络的测试：用纯 Dart 数据驱动，避免真实网络

---

## 7. 构建与发布

### Android

```bash
flutter build apk --release          # APK
flutter build appbundle --release    # AAB（上架 Google Play）
```

签名配置在 `android/app/build.gradle.kts`（默认 debug 签名，发布需配置 release keystore）。

### iOS

```bash
flutter build ios --release
# 用 Xcode 打开 ios/Runner.xcworkspace 进行签名与上传 App Store
```

### 版本号

`pubspec.yaml` 的 `version: 1.0.0+1`：
- `1.0.0` → versionName / CFBundleShortVersionString
- `1` → versionCode / CFBundleVersion

---

## 8. 国内镜像（Android 构建）

由于境外 Maven 仓库网络不稳定，已在 `android/settings.gradle.kts` 与 `android/build.gradle.kts` 配置阿里云镜像：

```kotlin
maven { url = uri("https://maven.aliyun.com/repository/google") }
maven { url = uri("https://maven.aliyun.com/repository/central") }
maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
```

如网络恢复，可移除这些镜像加快解析。

---

## 9. 已知限制与后续规划

### 已实现（详见 README.md）
完整覆盖：文件管理、9 类预览、分片上传/秒传/断点续传/队列、下载、收藏、去重、版本历史、标签、保险箱、设备管理、密码、分享（提取码/保存）、回收站、离线下载、AI 助手（搜索/摘要/重命名）、实时通知 + 本地系统推送。

### 待实现
- **文件评论**：后端无 comment 模块，需后端先开发
- **离线消息历史**：需后端持久化通知
- **通知推送的本地通知增强**：已实现基础版，可扩展通知点击跳转、通知分组等

### 架构注意事项
- `UploadService` / `DownloadService` 是单例，**全局回调 `onProgress` 是共享的**，多任务并发时应通过 `UploadManager` 队列管理，避免回调冲突
- 大文件 MD5 计算已通过 `Isolate.run` 在后台 isolate 执行（见 `lib/utils/md5_hash.dart`），不阻塞 UI
- `LocalNotificationService` 在 `main()` 初始化，登录后请求权限；WebSocket 收到通知时触发系统推送
- **Android 通知权限**：已在 AndroidManifest 添加 `POST_NOTIFICATIONS`（Android 13+）与 `VIBRATE`
- **widget 测试**：页面级测试通过 Riverpod override mock 网络层，Service 构造已公开便于子类化
