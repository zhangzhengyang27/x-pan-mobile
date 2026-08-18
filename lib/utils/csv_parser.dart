/// 轻量 CSV 解析器（对齐网页版 parseCsv 逻辑）
///
/// 支持引号包裹字段、转义双引号、逗号/制表符/分号分隔。
List<List<String>> parseCsv(String text) {
  final result = <List<String>>[];
  var row = <String>[];
  var field = '';
  var inQuotes = false;
  var i = 0;
  final n = text.length;

  while (i < n) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < n && text[i + 1] == '"') {
          field += '"';
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field += ch;
      i++;
      continue;
    }

    if (ch == '"') {
      inQuotes = true;
      i++;
      continue;
    }
    if (ch == ',' || ch == '\t' || ch == ';') {
      row.add(field);
      field = '';
      i++;
      continue;
    }
    if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < n && text[i + 1] == '\n') i++;
      row.add(field);
      field = '';
      if (row.any((c) => c.isNotEmpty)) result.add(row);
      row = <String>[];
      i++;
      continue;
    }
    field += ch;
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field);
    if (row.any((c) => c.isNotEmpty)) result.add(row);
  }
  return result;
}
