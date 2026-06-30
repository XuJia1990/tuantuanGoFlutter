import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/discounts/presentation/discounts_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/home/presentation/search_page.dart';
import '../../features/member/presentation/member_page.dart';
import '../../features/profile/presentation/profile_page.dart';
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
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
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
