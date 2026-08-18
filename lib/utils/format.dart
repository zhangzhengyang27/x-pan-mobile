/// 通用格式化工具
library;

/// 文件大小格式化，对齐前端 translateFileSize
/// 输出如 "1.50K" / "2.00M" / "3.50G"
String translateFileSize(num fileSize) {
  const unit = 1024;
  var size = fileSize / unit;
  var suffix = 'K';
  if (size >= unit) {
    size = size / unit;
    suffix = 'M';
  }
  if (size >= unit) {
    size = size / unit;
    suffix = 'G';
  }
  return '${size.toStringAsFixed(2)}$suffix';
}

/// 解析文件大小字符串（兼容 string | number 字段）
num parseFileSize(dynamic raw) {
  if (raw == null) return 0;
  if (raw is num) return raw;
  return num.tryParse(raw.toString()) ?? 0;
}
