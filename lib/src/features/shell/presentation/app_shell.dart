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
  bool _isGroupManager = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final isGroupManager = await ref.read(appStorageProvider).isGroupManager();
    if (mounted) setState(() => _isGroupManager = isGroupManager);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <_ShellTab>[
      const _ShellTab('首页', '/', Icons.home_outlined, Icons.home),
      const _ShellTab(
        '团优惠',
        '/discounts',
        Icons.local_offer_outlined,
        Icons.local_offer,
      ),
      const _ShellTab(
        '会员',
        '/member',
        Icons.card_membership_outlined,
        Icons.card_membership,
      ),
      if (_isGroupManager)
        const _ShellTab(
          '店铺管理',
          '/shop-manager',
          Icons.storefront_outlined,
          Icons.storefront,
        ),
      const _ShellTab('我的', '/profile', Icons.person_outline, Icons.person),
    ];
    final index = tabs.indexWhere((tab) => tab.path == widget.currentPath);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index < 0 ? 0 : index,
        onTap: (value) => context.go(tabs[value].path),
        items: [
          for (final tab in tabs)
            BottomNavigationBarItem(
              icon: Icon(tab.icon),
              activeIcon: Icon(tab.activeIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab(this.label, this.path, this.icon, this.activeIcon);

  final String label;
  final String path;
  final IconData icon;
  final IconData activeIcon;
}
