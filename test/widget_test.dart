import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:atma_book/app.dart';
import 'package:atma_book/state/guides_provider.dart';
import 'package:atma_book/state/settings_provider.dart';

void main() {
  testWidgets('首页冒烟测试：应用可渲染攻略卡片', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => GuidesProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const AtmaBookApp(),
      ),
    );
    await tester.pump(); // 本地化 delegates 装载帧

    expect(find.text('AtmaBook'), findsOneWidget);
    expect(find.text('杭州两日游'), findsOneWidget);
    expect(find.text('新增'), findsOneWidget);
  });
}
