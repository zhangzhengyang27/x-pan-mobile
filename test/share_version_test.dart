import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/models/file_version.dart';
import 'package:x_pan_mobile/services/share_service.dart';

void main() {
  group('ShareVO', () {
    test('解析分享列表项', () {
      final vo = ShareVO.fromJson({
        'shareId': 's1',
        'shareName': '测试分享',
        'shareUrl': 'http://x/s1',
        'shareCode': '1234',
        'shareStatus': 0,
        'shareType': 2,
        'shareDayType': 0,
        'shareEndTime': null,
        'createTime': '2026-01-01',
      });
      expect(vo.shareId, 's1');
      expect(vo.shareName, '测试分享');
      expect(vo.shareCode, '1234');
      expect(vo.shareType, 2);
    });

    test('shareCode 缺失时为空', () {
      final vo = ShareVO.fromJson({
        'shareId': 's1',
        'shareName': 'n',
        'shareUrl': '',
        'shareStatus': 0,
        'shareType': 1,
        'shareDayType': 0,
        'createTime': '',
      });
      expect(vo.shareCode, '');
    });
  });

  group('ShareDetail', () {
    test('解析分享详情（含文件列表）', () {
      final detail = ShareDetail.fromJson({
        'shareId': 's1',
        'shareName': '分享',
        'createTime': '2026-01-01',
        'shareDay': 0,
        'downloadCount': 3,
        'downloadLimit': 0,
        'xPanUserFileVOList': [
          {'fileId': 'f1', 'filename': 'a.txt', 'fileType': 1, 'folderFlag': 0, 'parentId': '', 'createTime': '', 'updateTime': ''},
        ],
        'shareUserInfoVO': {'userId': 'u1', 'username': 'zhang'},
      });
      expect(detail.files.length, 1);
      expect(detail.files.first.filename, 'a.txt');
      expect(detail.shareUserInfo.username, 'zhang');
      expect(detail.downloadCount, 3);
    });

    test('文件列表缺失时为空', () {
      final detail = ShareDetail.fromJson({
        'shareId': 's1',
        'shareName': 'n',
        'createTime': '',
        'shareDay': 0,
        'shareUserInfoVO': {},
      });
      expect(detail.files, isEmpty);
    });
  });

  group('ShareSimpleDetail', () {
    test('解析简单详情（含 hasShareCode）', () {
      final simple = ShareSimpleDetail.fromJson({
        'shareId': 's1',
        'shareName': '分享',
        'hasShareCode': true,
        'downloadLimit': 0,
        'shareUserInfoVO': {'userId': 'u1', 'username': 'zhang'},
      });
      expect(simple.hasShareCode, isTrue);
      expect(simple.shareName, '分享');
    });
  });

  group('FileVersion', () {
    test('解析版本信息', () {
      final v = FileVersion.fromJson({
        'id': 'v1',
        'fileId': 'f1',
        'versionNumber': 2,
        'filename': 'doc.txt',
        'fileSize': '1024',
        'realPath': '/data/doc.txt',
        'identifier': 'md5',
        'operation': 'UPLOAD',
        'operatorId': 'u1',
        'current': true,
        'createTime': '2026-01-01',
      });
      expect(v.versionNumber, 2);
      expect(v.current, isTrue);
      expect(v.operationText, '上传');
      expect(v.fileSize, '1024');
    });

    test('回滚操作中文映射', () {
      final v = FileVersion.fromJson({
        'id': 'v1',
        'fileId': 'f1',
        'versionNumber': 1,
        'filename': 'x',
        'fileSize': '1',
        'realPath': '',
        'identifier': '',
        'operation': 'ROLLBACK',
        'operatorId': '',
        'current': false,
        'createTime': '',
      });
      expect(v.operationText, '回滚');
    });
  });
}
