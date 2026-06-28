import '../../../shared/widgets/module_placeholder_page.dart';

class ShopManagerPage extends ModulePlaceholderPage {
  const ShopManagerPage({super.key})
    : super(
        title: '店铺管理',
        sourcePages: const [
          'pages/shopManageTabbar/shopManageTabbar.vue',
          'pages/my/shopManage.vue',
          'pages/member/memberDetailList.vue',
          'pages/member/memberStatic.vue',
        ],
      );
}
