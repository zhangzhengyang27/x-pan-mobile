import 'dart:async';

import 'package:app_links/app_links.dart';

/// 邀请深链服务
///
/// 支持：
/// - 自定义协议：xpan://join?code=XXXX
/// - 网页链接（配置 Universal Links / App Links 后）：https://host/join?code=XXXX
///
/// 未登录时先暂存邀请码，登录进入首页后再由 HomePage 消费。
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final StreamController<String> _controller = StreamController.broadcast();

  String? _pendingInviteCode;
  bool _initialized = false;

  /// 解析到新的邀请码时通知（登录后由首页处理）
  Stream<String> get inviteCodeStream => _controller.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        _handleUri(initial);
      }
    } catch (_) {
      // 冷启动无深链/平台不支持时忽略
    }
    appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (_) {},
    );
  }

  void _handleUri(Uri uri) {
    final code = extractInviteCode(uri);
    if (code == null || code.isEmpty) return;
    _pendingInviteCode = code;
    _controller.add(code);
  }

  /// 取出待处理邀请码（取出后清空）
  String? takePendingCode() {
    final code = _pendingInviteCode;
    _pendingInviteCode = null;
    return code;
  }

  /// 未登录时把邀请码放回待处理队列
  void restorePendingCode(String code) {
    if (code.isEmpty) return;
    _pendingInviteCode = code;
  }

  /// 从 URI 中提取邀请码
  static String? extractInviteCode(Uri uri) {
    if (uri.scheme == 'xpan' && uri.host == 'join') {
      final code = uri.queryParameters['code'];
      return _normalize(code);
    }
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.path.endsWith('/join')) {
      return _normalize(uri.queryParameters['code']);
    }
    return null;
  }

  /// 兼容用户直接粘贴完整链接或纯邀请码
  static String? parseInviteInput(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri != null && (uri.hasScheme || text.contains('code='))) {
      final code = uri.queryParameters['code'];
      final normalized = _normalize(code);
      if (normalized != null) return normalized;
    }
    return _normalize(text);
  }

  static String? _normalize(String? code) {
    if (code == null) return null;
    final value = code.trim().toUpperCase();
    return value.isEmpty ? null : value;
  }
}
