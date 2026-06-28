import '../../../shared/widgets/module_placeholder_page.dart';

class DiscountsPage extends ModulePlaceholderPage {
  const DiscountsPage({super.key})
    : super(
        title: '团优惠',
        sourcePages: const [
          'pages/centerDiscount/centerDiscount.vue',
          'pages/detail/discountDetail.vue',
          'pages/detail/commodityDetail.vue',
          'pages/submitOrder/submitOrder.vue',
          'pages/detail/handleDiscountDetail.vue',
        ],
      );
}
