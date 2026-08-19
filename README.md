# X-Pan Mobile

X-Pan 个人分布式存储 —— 移动端 App（Flutter 版）。

> 📘 完整开发文档见 [DEVELOPMENT.md](DEVELOPMENT.md)（架构、模块、接口契约、测试、发布）

## 技术栈

| 层 | 选型 |
|----|------|
| 框架 | Flutter 3.35（Dart 3.9） |
| 状态管理 | Riverpod（`flutter_riverpod`） |
| 网络请求 | Dio（统一拦截器 + 认证） |
| 本地存储 | SharedPreferences（Token） |
| 路由 | go_router |

## 目录结构

```
lib/
├── main.dart                  # 入口
├── core/
│   ├── config/app_config.dart # API 地址、超时、分片大小等
│   ├── theme/app_theme.dart   # 明暗主题（对齐前端 #0070f3）
│   ├── network/http_client.dart # Dio 封装 + 拦截器
│   └── storage/token_storage.dart # Token 本地存储
├── models/                    # 后端数据结构（R<T>/FileVO/UserInfo）
├── services/                  # API 服务层（UserService/FileService）
├── providers/                 # Riverpod 状态（auth/file）
├── router/app_router.dart     # 路由 + 登录态守卫
├── pages/                     # 页面（login/register/home）
├── widgets/                   # 通用组件
└── utils/format.dart          # 格式化工具
```

## 与后端 API 契约对齐

移动端独立维护，仅共享后端 HTTP API 契约（已对齐前端 `src/types/index.ts` 与 `src/api/*`）：

- 统一响应 `R<T>` = `{ code, message, data }`，`code === 0` 成功，`code === 10` 需重新登录
- 认证：登录后请求头携带 `Authorization: <token>`，响应头 `new-access-token` 自动续期
- 分片上传：5MB 分片（`/file/sec-upload` 秒传 + `/file/merge` 合并）

## 运行

### 配置后端地址

默认 `http://localhost:8081`，按调试环境通过 `--dart-define` 覆盖：

```bash
# iOS 模拟器 / 桌面
flutter run --dart-define=X_PAN_API_BASE_URL=http://localhost:8081

# Android 模拟器（访问宿主机）
flutter run --dart-define=X_PAN_API_BASE_URL=http://10.0.2.2:8081

# 真机（改为局域网 IP）
flutter run --dart-define=X_PAN_API_BASE_URL=http://192.168.x.x:8081
```

### 常用命令

```bash
flutter pub get      # 安装依赖
flutter analyze      # 静态检查
flutter test         # 测试
flutter run          # 运行
```

### 启动模拟器

先安装对应平台依赖，再启动模拟器，最后运行 App。

#### 1. 查看可用模拟器 / 设备

```bash
flutter devices
```

#### 2. 启动 iOS 模拟器

```bash
# 启动默认 iOS 模拟器（需 macOS）
open -a Simulator

# 指定设备名启动（用 flutter devices 列出的名称）
xcrun simctl boot "iPhone 16 Pro"
open -a Simulator
```

#### 3. 启动 Android 模拟器

```bash
# 列出已创建的 AVD
flutter emulators

# 启动指定 AVD（用上面的 id，如 emulator-5554）
flutter emulators --launch emulator-5554

# 或用 Android SDK 自带命令
emulator -avd Pixel_7_API_34
```

#### 4. 在模拟器上运行 App

```bash
# 自动选择已启动的模拟器运行
flutter run

# 指定设备运行（用 flutter devices 列出的 id）
flutter run -d "iPhone 16 Pro"
flutter run -d emulator-5554
flutter run -d C94642E9-D87B-4462-8048-07755E79F275

# 指定设备 + 覆盖后端地址（iOS 模拟器访问宿主机）
flutter run -d "iPhone 16 Pro" --dart-define=X_PAN_API_BASE_URL=http://localhost:8081

# Android 模拟器访问宿主机需用 10.0.2.2
flutter run -d emulator-5554 --dart-define=X_PAN_API_BASE_URL=http://10.0.2.2:8081
```

#### 5. 关闭模拟器

```bash
# iOS
xcrun simctl shutdown "iPhone 16 Pro"

# Android
adb emu kill
```

## 已实现

- 登录 / 注册 / 退出登录
- 登录态持久化与路由守卫
- 文件列表（面包屑导航、进入子文件夹、返回上级、下拉刷新）
- 新建文件夹
- 文件重命名 / 删除 / 移动 / 复制（文件夹树选择目标）
- 文件上传（分片 + 秒传 + 进度条 + 断点续传）
- 文件下载（下载到本地并打开）
- 文件搜索
- 图片预览（左右滑动切换）
- 视频预览（video_player + chewie）
- 音频预览（just_audio）
- PDF 预览（flutter_pdfview）
- Office 预览（webview 加载异步转换任务直链）
- 文本 / 代码 / Markdown 预览（flutter_markdown + 后端 text-extract）
- 多选与批量操作（批量删除 / 移动 / 复制 / 分享）
- 列表 / 网格视图切换（图片缩略图）
- 回收站（列表 / 恢复 / 彻底删除）
- 分享（创建 / 列表 / 复制链接 / 取消）
- 分享详情（提取码验证、保存到网盘）
- 离线下载（创建 / 列表 / 取消 / 删除）
- 断点续传持久化（跨 App 重启恢复上传进度）
- 文件版本历史（查看 / 回滚 / 删除版本）
- 缩略图懒加载优化（内存缓存尺寸限制 + 预加载范围控制）
- 收藏 / 星标（批量收藏 + 收藏视图）
- 在线解压（异步任务 + 进度轮询）
- 隐私保险箱（设置 / 解锁 / 锁定 / 移入移出）
- 文件标签（后端规则自动打标 + 手动标签）
- 设备管理 + 修改密码 / 忘记密码
- 文件去重（分组 + 可释放空间统计 + 一键释放）
- 存储统计仪表盘
- 最近访问记录
- CSV 表格渲染预览
- 上传任务面板（队列 / 暂停 / 取消 / 重试）
- XMind 思维导图预览（ZIP 解压 + content.json 解析）
- AI 助手（DeepSeek 接入，自然语言搜索 / 闲聊）
- AI 文件摘要 / 重命名建议（选中文件上下文 + LLM）
- 实时通知中心（WebSocket 推送：离线任务 / 上传完成 / 分享动态 / 系统通知）
- 本地系统推送（`flutter_local_notifications`，后台时提醒）
- 大文件 MD5 isolate 后台计算（不阻塞 UI）
- 单元测试 + 页面级 widget 测试（mock 网络层）

## 安全与稳定性

- **Token / API Key 加密存储**：使用 `flutter_secure_storage`（iOS Keychain / Android Keystore）
- **上传 token 续期**：分片上传/断点检测统一走拦截器，长文件上传自动续期
- **WebSocket 自动重连**：断线指数退避重连 + 重连时刷新 token，登出断开
- **通知节流**：相同通知 10s 内不重复推送
- **下载进度回调**：局部参数传递，避免与上传全局回调冲突

## 国内镜像源

Android 已配置阿里云 Maven 镜像（`android/settings.gradle.kts` 与 `android/build.gradle.kts`），解决境外仓库 TLS/网络问题。

## 待实现（后续迭代）

- 文件评论（需后端新增 comment 模块，当前后端未提供）
- 通知推送的离线消息历史（需后端持久化通知）
