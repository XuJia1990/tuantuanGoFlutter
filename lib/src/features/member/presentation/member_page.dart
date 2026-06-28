import '../../../shared/widgets/module_placeholder_page.dart';

class MemberPage extends ModulePlaceholderPage {
  const MemberPage({super.key})
    : super(
        title: '会员',
        sourcePages: const [
          'pages/member/memberList.vue',
          'pages/member/createMember.vue',
          'pages/member/recharge.vue',
          'pages/member/memberConsumption.vue',
          'pages/member/memberConsumptionShopPay.vue',
          'pages/member/record.vue',
          'pages/member/code.vue',
          'pages/member/payCode.vue',
          'pages/member/setPayPassword.vue',
        ],
      );
}
