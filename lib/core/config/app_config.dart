/// 应用级配置
///
/// 对应前端 `VITE_API_BASE_URL`：后端服务完整地址。
/// 说明：
/// - 默认指向公网生产地址（发布包开箱即用）
/// - 本地开发用 `--dart-define` 覆盖：
///   iOS 模拟器/macOS：`flutter run --dart-define=X_PAN_API_BASE_URL=http://127.0.0.1:8081`
///   Android 模拟器访问宿主机：`--dart-define=X_PAN_API_BASE_URL=http://10.0.2.2:8081`
///   真机调试改为局域网 IP，如 `http://192.168.x.x:8081`
class AppConfig {
  AppConfig._();

  /// 后端 API 基础地址（不带末尾斜杠）
  static const String apiBaseUrl = String.fromEnvironment(
    'X_PAN_API_BASE_URL',
    defaultValue: 'https://pan.zhangzhengyang.com',
  );

  /// 请求超时（毫秒），对齐前端 60s
  static const int requestTimeoutMs = 1000 * 60;

  /// 分片大小：5MB（对齐后端 MinIO composeObject 合并要求）
  static const int chunkSize = 1024 * 1024 * 5;

  /// 最大文件大小：3GB
  static const int maxFileSize = 1024 * 1024 * 1024 * 3;
}
