import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:x_pan_mobile/pages/notification_page.dart';
import 'package:x_pan_mobile/providers/notification_provider.dart';
import 'package:x_pan_mobile/services/notification_service.dart';

Widget _wrap(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: NotificationPage()),
  );
}

void main() {
  testWidgets('空通知时显示"暂无通知"', (tester) async {
    final container = ProviderContainer(
      overrides: [
        notificationProvider.overrideWith((ref) => NotificationManager()),
      ],
    );
    await tester.pumpWidget(_wrap(container));

    expect(find.text('暂无通知'), findsOneWidget);
    expect(find.text('实时通知未连接'), findsOneWidget);

    container.dispose();
  });

  testWidgets('有通知时展示通知列表并可清空', (tester) async {
    final container = ProviderContainer(
      overrides: [
        notificationProvider.overrideWith((ref) {
          final manager = NotificationManager();
          manager.testInjectNotice('系统通知', '系统升级', 'info');
          return manager;
        }),
      ],
    );
    await tester.pumpWidget(_wrap(container));

    expect(find.text('系统通知'), findsOneWidget);
    expect(find.text('系统升级'), findsOneWidget);

    // 点击清空按钮
    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pump();

    expect(find.text('暂无通知'), findsOneWidget);

    container.dispose();
  });
}
