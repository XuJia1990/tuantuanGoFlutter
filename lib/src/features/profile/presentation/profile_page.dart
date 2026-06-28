import '../../../shared/widgets/module_placeholder_page.dart';

class ProfilePage extends ModulePlaceholderPage {
  const ProfilePage({super.key})
    : super(
        title: '我的',
        sourcePages: const [
          'pages/my/my.vue',
          'pages/my/myCardRoll.vue',
          'pages/my/myCollection.vue',
          'pages/my/mySetting.vue',
          'pages/my/myAboutOur.vue',
          'pages/my/privacyAgreement.vue',
          'pages/my/service.vue',
          'pages/my/updataOurIns.vue',
        ],
      );
}
