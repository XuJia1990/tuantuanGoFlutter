import '../../../shared/widgets/module_placeholder_page.dart';

class HomePage extends ModulePlaceholderPage {
  const HomePage({super.key})
    : super(
        title: '首页',
        sourcePages: const [
          'pages/index/index.vue',
          'pages/searchContent/searchContent.vue',
          'pages/detail/shopDetail.vue',
          'pages/handleScore/handleScore.vue',
        ],
      );
}
