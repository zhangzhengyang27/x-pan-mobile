import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:x_pan_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: XPanApp()));
    // 等待首帧渲染
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    // 弱网恢复逻辑会在启动时重试拉取用户信息（Dio 超时定时器）——
    // 推进虚拟时钟让后台请求完成，避免测试结束后残留 pending timer
    await tester.pump(const Duration(seconds: 30));
  });
}
