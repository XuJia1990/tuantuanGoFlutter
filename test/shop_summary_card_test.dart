import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_go_flutter/src/features/home/data/home_models.dart';
import 'package:tuantuan_go_flutter/src/features/home/presentation/shop_summary_card.dart';

void main() {
  testWidgets('shows shop distance in kilometers', (tester) async {
    const shop = ShopSummary(
      shopId: '1',
      name: '测试店铺',
      imageUrl: '',
      categoryName: '餐饮',
      rating: 5,
      distance: 8273447,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopSummaryCard(shop: shop, onTap: _ignoreTap),
        ),
      ),
    );

    expect(find.text('8273.4km'), findsOneWidget);
    expect(find.text('8273447m'), findsNothing);
  });
}

void _ignoreTap() {}
