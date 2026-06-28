import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuantuan_go_flutter/src/app/app.dart';

void main() {
  testWidgets('renders app shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: TuanTuanGoApp()));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsWidgets);
    expect(find.text('团优惠'), findsOneWidget);
    expect(find.text('会员'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
