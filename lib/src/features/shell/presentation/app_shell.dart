import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/app_storage.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.currentPath, required this.child, super.key});

  final String currentPath;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath == widget.currentPath) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(isGroupManagerProvider);
      if (widget.currentPath == '/profile') {
        ref.read(authRevisionProvider.notifier).bump();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGroupManager = ref
        .watch(isGroupManagerProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);
    final tabs = <_ShellTab>[
      const _ShellTab(
        '首页',
        '/',
        'assets/static/tab-1-1.png',
        'assets/static/tab-1.png',
      ),
      const _ShellTab(
        '团优惠',
        '/discounts',
        'assets/static/tab-2-2.png',
        'assets/static/tab-2.png',
      ),
      const _ShellTab(
        '会员',
        '/member',
        'assets/static/tab-4-4.png',
        'assets/static/tab-4.png',
      ),
      if (isGroupManager)
        const _ShellTab(
          '店铺管理',
          '/shop-manager',
          'assets/static/tab-5-5.png',
          'assets/static/tab-5.png',
        ),
      const _ShellTab(
        '我的',
        '/profile',
        'assets/static/tab-3-3.png',
        'assets/static/tab-3.png',
      ),
    ];
    final index = tabs.indexWhere((tab) => tab.path == widget.currentPath);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index < 0 ? 0 : index,
        onTap: (value) async {
          final tab = tabs[value];
          if ((tab.path == '/discounts' || tab.path == '/member') &&
              !await ref.read(appStorageProvider).isSignedIn()) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('未登录，请先登录')));
            context.push('/login');
            return;
          }
          if (context.mounted) context.go(tab.path);
        },
        items: [
          for (final tab in tabs)
            BottomNavigationBarItem(
              icon: _TabIcon(asset: tab.iconPath),
              activeIcon: _TabIcon(asset: tab.activeIconPath),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Image.asset(asset, width: 22, height: 22, fit: BoxFit.contain),
    );
  }
}

class _ShellTab {
  const _ShellTab(this.label, this.path, this.iconPath, this.activeIconPath);

  final String label;
  final String path;
  final String iconPath;
  final String activeIconPath;
}
