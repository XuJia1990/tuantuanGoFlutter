import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/discounts/presentation/discounts_page.dart';
import '../../features/home/presentation/coupon_detail_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/home/presentation/search_page.dart';
import '../../features/home/presentation/shop_detail_page.dart';
import '../../features/member/presentation/member_page.dart';
import '../../features/member/presentation/member_recharge_page.dart';
import '../../features/member/presentation/member_record_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/profile_sub_pages.dart';
import '../../features/shop_manager/presentation/shop_manager_page.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/splash/presentation/ad_webview_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(currentPath: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: '/discounts',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DiscountsPage()),
          ),
          GoRoute(
            path: '/member',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MemberPage()),
          ),
          GoRoute(
            path: '/shop-manager',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ShopManagerPage()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return LoginPage(messageType: state.uri.queryParameters['type']);
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forget-password',
        builder: (context, state) {
          return ForgetPasswordPage(
            type: state.uri.queryParameters['type'] ?? 'resetPassword',
          );
        },
      ),
      GoRoute(
        path: '/set-password',
        builder: (context, state) {
          return SetPasswordPage(
            type: state.uri.queryParameters['type'] ?? 'register',
            mobile: state.uri.queryParameters['mobile'] ?? '',
            code: state.uri.queryParameters['code'] ?? '',
          );
        },
      ),
      GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: '/purchased-coupons',
        builder: (context, state) => const PurchasedCouponsPage(),
      ),
      GoRoute(
        path: '/my-collection',
        builder: (context, state) => const MyCollectionPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/about-us',
        builder: (context, state) => const AboutUsPage(),
      ),
      GoRoute(
        path: '/service',
        builder: (context, state) => const ServicePage(),
      ),
      GoRoute(
        path: '/member-code',
        builder: (context, state) => const MemberCodePage(),
      ),
      GoRoute(
        path: '/pay-code',
        builder: (context, state) => const PayCodePage(),
      ),
      GoRoute(
        path: '/scan-code',
        builder: (context, state) => const ScanCodePage(),
      ),
      GoRoute(
        path: '/create-member',
        builder: (context, state) {
          return ScanTargetPlaceholderPage(
            title: '创建会员',
            sourcePage: 'pages/member/createMember.vue',
            params: state.uri.queryParameters,
          );
        },
      ),
      GoRoute(
        path: '/member-consumption',
        builder: (context, state) {
          return ScanTargetPlaceholderPage(
            title: '会员消费',
            sourcePage: 'pages/member/memberConsumption.vue',
            params: state.uri.queryParameters,
          );
        },
      ),
      GoRoute(
        path: '/member-recharge',
        builder: (context, state) {
          return MemberRechargePage(params: state.uri.queryParameters);
        },
      ),
      GoRoute(
        path: '/member-record',
        builder: (context, state) {
          return MemberRecordPage(params: state.uri.queryParameters);
        },
      ),
      GoRoute(
        path: '/privacy-agreement',
        builder: (context, state) {
          return PrivacyAgreementPage(
            type: int.tryParse(state.uri.queryParameters['type'] ?? '4') ?? 4,
          );
        },
      ),
      GoRoute(
        path: '/shop/:shopId',
        builder: (context, state) {
          return ShopDetailPage(shopId: state.pathParameters['shopId'] ?? '');
        },
      ),
      GoRoute(
        path: '/coupon/:couponId',
        builder: (context, state) {
          return CouponDetailPage(
            couponId: state.pathParameters['couponId'] ?? '',
            title: state.uri.queryParameters['title'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/ad',
        builder: (context, state) {
          return AdWebViewPage(url: state.uri.queryParameters['url'] ?? '');
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('团团go')),
      body: Center(child: Text(state.error?.message ?? '页面不存在')),
    ),
  );
});
