import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/services/share_service.dart';

void main() {
  test('ShareDetail 兼容后端 xpanUserFileVOList 小写字段并解析 e2ee', () {
    final detail = ShareDetail.fromJson({
      'shareId': 'share-1',
      'shareName': '加密文件',
      'createTime': '2026-11-20 16:00:00',
      'shareDay': 0,
      'e2ee': 1,
      'xpanUserFileVOList': [
        {
          'fileId': 'file-1',
          'parentId': '-3',
          'filename': 'report.xpan',
          'fileType': 1,
          'folderFlag': 0,
          'createTime': '2026-11-20 15:00:00',
          'updateTime': '2026-11-20 15:00:00',
          'fileSize': '1024',
        }
      ],
      'shareUserInfoVO': {'userId': 'u1', 'username': 'alice'},
    });
    expect(detail.e2ee, isTrue);
    expect(detail.files, hasLength(1));
    expect(detail.files.first.filename, 'report.xpan');
    expect(detail.files.first.parentId, '-3');
  });

  test('ShareVO 解析列表中的 e2ee 标记', () {
    final vo = ShareVO.fromJson({
      'shareId': 'share-2',
      'shareName': '普通文件',
      'shareUrl': 'https://pan.example.com/share/share-2',
      'shareStatus': 0,
      'shareType': 1,
      'shareDayType': 0,
      'createTime': '2026-11-20 16:00:00',
      'e2ee': 0,
    });
    expect(vo.e2ee, isFalse);
    expect(vo.shareId, 'share-2');
  });
}
