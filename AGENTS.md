# AGENTS.md — AI 助手 / 代理开发指南

本文档为在此项目中工作的 AI 助手 / 编码代理提供必要的项目上下文、约定与操作指引。**在修改代码前请先阅读本文档。**

项目：**X-Pan 个人分布式存储网盘 —— 移动端 App**（Flutter，仅 iOS + Android）

---

## 1. 快速开始

```bash
cd /Users/zhangzhengyang/Desktop/x-pan/x-pan-mobile

flutter pub get          # 安装依赖
flutter analyze          # 静态检查（改动后必跑）
flutter test             # 运行测试（改动后必跑）
flutter run              # 运行（默认 http://localhost:8081）
```

**注意**：`flutter test` 全量运行可能超时，建议**按文件分组运行**：
```bash
flutter test test/models_test.dart test/utils_test.dart
```

---

## 2. 技术栈与依赖

| 层 | 选型 |
|----|------|
| 框架 | Flutter 3.35 / Dart 3.9 |
| 状态管理 | Riverpod（`flutter_riverpod` 2.x，StateNotifier + Provider） |
| 网络 | Dio 5.x（统一拦截器 + 认证续期） |
| 本地存储 | `flutter_secure_storage`（Token / API Key，Keychain/Keystore 加密） |
| 路由 | go_router 14.x |
| 通知 | `web_socket_channel` + `flutter_local_notifications` |
| 上传 | 分片（5MB）+ 秒传（MD5）+ 断点续传（`Isolate.run`） |

完整依赖见 `pubspec.yaml`。

---

## 3. 目录结构速览

```
lib/
├── main.dart                # 入口（初始化本地通知 + ProviderScope）
├── core/
│   ├── config/app_config.dart    # API 地址/超时/分片大小
│   ├── theme/app_theme.dart      # 明暗主题（品牌色 #0070f3）
│   ├── network/http_client.dart  # Dio 封装（拦截器/异常/续期）
│   └── storage/                  # Token / 上传任务 / 最近访问
├── models/                 # 后端数据结构（fromJson）
├── services/               # API 服务层（每模块一文件，单例）
├── providers/              # Riverpod 状态（auth/file/upload/notification）
├── router/app_router.dart  # 路由 + 登录守卫
├── pages/                  # 页面
├── widgets/                # 通用组件
└── utils/                  # format / csv_parser / md5_hash
```

---

## 4. 核心架构约定

### 4.1 网络层（`core/network/http_client.dart`）

**所有 API 请求必须通过 `HttpClient.instance.request<T>()`**，它会自动：
- 注入 `Authorization`（从 secure storage 读取）
- 处理 `new-access-token` 续期
- 统一响应校验（`code==0` 成功；`code==10` 抛 `NeedReloginException`；其余抛 `ApiException`）

```dart
await HttpClient.instance.request<T>(
  '/path',
  method: 'POST',
  query: {...},
  data: {...},
  dataDecoder: (json) => T.fromJson(json),
);
```

> ⚠️ **不要绕过 `request`** 直接用 `dio.get/post/download`。否则会丢失 token 续期能力（曾因此导致长上传/下载 token 过期失败）。

### 4.2 Service 单例模式

```dart
class XxxService {
  XxxService();                     // 公开构造（便于测试子类化）
  static final XxxService instance = XxxService();
  final HttpClient _http = HttpClient.instance;
}
```

### 4.3 上传（`providers/upload_provider.dart` + `services/upload_service.dart`）

- 上传任务统一走 `UploadManager`（Riverpod StateNotifier）**串行队列**
- 通过 `uploadManagerProvider` 添加/取消/重试
- **不要直接调用 `UploadService.instance.uploadFile()`**（会绕过队列，且全局回调 `onProgress`/`onCheckCancel` 与队列冲突）

### 4.4 认证与通知

- `authProvider`：登录态；`logout()` 会断开 WebSocket 并清 token
- 登出时必须在 UI 层调用 `ref.read(notificationProvider.notifier).stop()`（复位，使下次登录可重连）
- WebSocket 已实现自动重连 + 重连时刷新 token

### 4.5 安全约定

- **Token / API Key 禁止存入 SharedPreferences**，必须用 `flutter_secure_storage`
- 多 ID 参数用 `__,__` 分隔（如 `fileIds`）

---

## 5. 开发规范

### 新增一个 API 服务
1. `services/` 新建 `xxx_service.dart`（单例）
2. `models/` 添加 `Xxx.fromJson`
3. 所有请求走 `HttpClient.request`，多 ID 用 `__,__`

### 新增一个页面
1. `pages/` 创建页面（`ConsumerStatefulWidget`/`ConsumerWidget`）
2. 一级导航在 `home_page.dart` 的 Drawer 或 AppBar 添加入口
3. 预览类页面用 `Navigator.push`

### 预览分发
`home_page.dart` 的 `_openFile` 按 `FileType` 路由，`.xmind` 按扩展名判断。

---

## 6. 测试

新增/修改代码后**必须**跑相关测试，并尽可能补充测试。

| 测试文件 | 覆盖 |
|---------|------|
| `test/models_test.dart` | 模型 `fromJson` |
| `test/utils_test.dart` | 文件大小格式化 |
| `test/csv_parser_test.dart` | CSV 解析 |
| `test/share_version_test.dart` | Share / FileVersion |
| `test/notification_test.dart` | 通知消息解析 |
| `test/notification_throttle_test.dart` | 通知节流 |
| `test/md5_hash_test.dart` | isolate MD5 |
| `test/widget_test.dart` | App smoke test |
| `test/login_page_test.dart` | 登录页 widget（mock Riverpod） |
| `test/notification_page_test.dart` | 通知中心 widget |

### 页面级测试（mock 网络）
用 **Riverpod override** 注入 mock 依赖，不触发真实网络：

```dart
final container = ProviderContainer(
  overrides: [authProvider.overrideWith((ref) => fakeAuth)],
);
await tester.pumpWidget(
  UncontrolledProviderScope(container: container, child: ...),
);
```

---

## 7. 平台配置

- **Android**：`android/app/src/main/AndroidManifest.xml` 已含 `INTERNET`、`POST_NOTIFICATIONS`（Android 13+）、`VIBRATE`、`usesCleartextTraffic`（开发期 http）
- **iOS**：`Info.plist` 已含 ATS 例外（允许 http）
- **国内镜像**：`android/settings.gradle.kts` 与 `android/build.gradle.kts` 配置了阿里云 Maven 镜像（解决境外仓库网络问题）

---

## 8. 常见问题

| 问题 | 处理 |
|------|------|
| `flutter analyze` 报错 | 修复后重跑，保持 0 错误 |
| `flutter test` 全量超时 | 按文件分组运行 |
| Android 构建 TLS 失败 | 检查阿里云镜像是否生效 |
| 后端地址变化 | 用 `--dart-define=X_PAN_API_BASE_URL=...` 覆盖 |
| 真机连不上后端 | 用局域网 IP，Android 模拟器用 `10.0.2.2` |

---

## 9. 后端接口契约要点

- 统一响应 `R<T> = { code, message, data }`
- `code == 0` 成功，`code == 10` 需重新登录
- 认证：请求头 `Authorization`，续期 `new-access-token`
- 分享类接口：额外请求头 `Share-Token`
- 完整接口速查见 `DEVELOPMENT.md` 第 4 节
