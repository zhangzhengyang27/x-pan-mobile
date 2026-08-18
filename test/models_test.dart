import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/models/api_response.dart';
import 'package:x_pan_mobile/models/file_vo.dart';
import 'package:x_pan_mobile/models/user_info.dart';

void main() {
  group('ApiResponse', () {
    test('成功响应', () {
      final resp = ApiResponse.fromJson(
        {'code': 0, 'message': 'ok', 'data': {'id': '1'}},
        (json) => json,
      );
      expect(resp.isSuccess, isTrue);
      expect(resp.needRelogin, isFalse);
      expect(resp.data, isNotNull);
    });

    test('需要重新登录（code == 10）', () {
      final resp = ApiResponse.fromJson(
        {'code': 10, 'message': '登录失效', 'data': null},
        null,
      );
      expect(resp.isSuccess, isFalse);
      expect(resp.needRelogin, isTrue);
    });

    test('未知错误默认 code = -1', () {
      final resp = ApiResponse.fromJson({'message': 'x'}, null);
      expect(resp.code, -1);
      expect(resp.isSuccess, isFalse);
    });

    test('data 为 null 时 decoder 不被调用', () {
      final resp = ApiResponse.fromJson(
        {'code': 0, 'data': null},
        (_) => fail('不应调用 decoder'),
      );
      expect(resp.data, isNull);
    });
  });

  group('PageVO', () {
    test('解析记录列表', () {
      final page = PageVO.fromJson(
        {
          'total': 2,
          'pageSize': 10,
          'pageNum': 1,
          'records': [
            {'fileId': '1', 'filename': 'a.txt'},
            {'fileId': '2', 'filename': 'b.txt'},
          ],
        },
        (json) => FileVO.fromJson(json as Map<String, dynamic>),
      );
      expect(page.total, 2);
      expect(page.records.length, 2);
      expect(page.records[0].filename, 'a.txt');
    });

    test('records 缺失时为空列表', () {
      final page = PageVO.fromJson(
        {'total': 0, 'pageSize': 10, 'pageNum': 1},
        (json) => json,
      );
      expect(page.records, isEmpty);
    });
  });

  group('FileVO', () {
    test('解析文件字段（fileSize 兼容字符串和数字）', () {
      final vo = FileVO.fromJson({
        'fileId': 'f1',
        'parentId': 'p1',
        'filename': 'test.pdf',
        'fileType': 5, // PDF
        'fileSize': '2048',
        'folderFlag': 0,
        'createTime': '2026-01-01',
        'updateTime': '2026-01-02',
      });
      expect(vo.fileId, 'f1');
      expect(vo.fileType, FileType.pdf);
      expect(vo.fileSize, '2048');
      expect(vo.isFolder, isFalse);
    });

    test('文件夹识别', () {
      final vo = FileVO.fromJson({
        'fileId': 'f1',
        'parentId': 'p1',
        'filename': 'folder',
        'fileType': 0, // 文件夹
        'folderFlag': 1,
        'createTime': '',
        'updateTime': '',
      });
      expect(vo.isFolder, isTrue);
      expect(vo.fileType, FileType.folder);
    });

    test('未知文件类型回退为 normal', () {
      final vo = FileVO.fromJson({
        'fileId': 'f1',
        'parentId': 'p1',
        'filename': 'x',
        'fileType': 999,
        'folderFlag': 0,
        'createTime': '',
        'updateTime': '',
      });
      expect(vo.fileType, FileType.normal);
    });
  });

  group('UserInfo', () {
    test('解析用户信息', () {
      final user = UserInfo.fromJson({
        'userId': 'u1',
        'username': 'zhang',
        'rootFileId': 'root',
        'rootFilename': '全部文件',
        'usedSize': 100,
        'totalSize': 1000,
      });
      expect(user.username, 'zhang');
      expect(user.rootFileId, 'root');
      expect(user.usedSize, 100);
      expect(user.totalSize, 1000);
    });
  });
}
