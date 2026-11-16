import '../core/network/http_client.dart';

/// 通知中心条目
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.readFlag,
    required this.createTime,
  });

  final String id;
  final String type;
  final String title;
  final String content;
  final int readFlag; // 0 未读 1 已读
  final String createTime;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      readFlag: json['readFlag'] is int ? json['readFlag'] as int : 0,
      createTime: json['createTime']?.toString() ?? '',
    );
  }
}

/// 通知中心 API（后端 notification 模块既有端点）
class NotificationApi {
  NotificationApi._();

  /// /notification/list 的查询参数拼装（分页测试锚定）
  static Map<String, dynamic> listQuery({int limit = 50}) => {'limit': limit};

  static NotificationApi? _instance;

  factory NotificationApi.instance() => _instance ??= NotificationApi._();

  /// 通知列表（倒序）
  Future<List<NotificationItem>> list({int limit = 50}) async {
    final res = await HttpClient.instance.request<List<dynamic>>(
      '/notification/list',
      query: listQuery(limit: limit),
      dataDecoder: (json) => json as List<dynamic>,
    );
    return res
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 未读数
  Future<int> unreadCount() async {
    final res = await HttpClient.instance.request<dynamic>(
      '/notification/unread/count',
      dataDecoder: (json) => json,
    );
    return (res is num) ? res.toInt() : 0;
  }

  /// 标记单条已读
  Future<void> markRead(String id) async {
    await HttpClient.instance.request<dynamic>(
      '/notification/read/$id',
      method: 'PUT',
      dataDecoder: (json) => json,
    );
  }

  /// 全部已读
  Future<void> markAllRead() async {
    await HttpClient.instance.request<dynamic>(
      '/notification/read/all',
      method: 'PUT',
      dataDecoder: (json) => json,
    );
  }
}
