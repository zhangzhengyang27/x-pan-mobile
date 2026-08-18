import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 本地通知服务
///
/// 将 WebSocket 实时通知映射为系统级推送（应用在前台/后台时均可提醒）。
/// Android 使用默认通道，iOS 使用 Darwin 初始化。
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance =
      LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 初始化（App 启动时调用）
  Future<void> init() async {
    if (_initialized) return;

    // Android 初始化
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS / macOS 初始化（Darwin 设置共享）
    // 说明：Windows 通知暂不支持（当前插件 17.2.4 仅支持 macOS/Linux，
    // Windows 支持需升级到 19.0+ 且要求 Flutter 3.38+，待升级后补齐）。
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// 请求通知权限
  Future<void> requestPermissions() async {
    await init();
    // iOS / macOS
    await _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    // Android
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// 检查通知权限
  Future<bool> areNotificationsEnabled() async {
    await init();
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    if (android != null) return android;
    // iOS / macOS / 其他：权限状态未知时视为已启用
    return true;
  }

  /// 显示本地通知
  Future<void> show({
    required String id,
    required String title,
    required String body,
  }) async {
    await init();

    // Android 通知通道
    const androidDetails = AndroidNotificationDetails(
      'xpan_notifications',
      'X-Pan 通知',
      channelDescription: '文件上传、离线下载、分享等实时通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    // iOS / macOS 通知（Darwin 设置共享）
    const darwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(
      id.hashCode,
      title,
      body,
      details,
      payload: id,
    );
  }
}
