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
  });
}
