import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/ui/app_toast.dart';
import '../../home/data/home_models.dart';

class ShopManagerPage extends ConsumerStatefulWidget {
  const ShopManagerPage({super.key});

  @override
  ConsumerState<ShopManagerPage> createState() => _ShopManagerPageState();
}

class _ShopManagerPageState extends ConsumerState<ShopManagerPage> {
  static const _pageSize = 10;

  final _items = <ManagedShop>[];
  int _pageNo = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      _pageNo = 1;
      _total = 0;
    }
    if (mounted) {
      setState(() {
        if (reset) {
          _loading = true;
        } else {
          _loadingMore = true;
        }
      });
    }
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.managerGroupList,
            data: {'pageNo': _pageNo, 'pageSize': _pageSize},
          );
      final envelope = ApiEnvelope.parse<PagedResult<ManagedShop>>(
        raw,
        (data) => PagedResult.parse(data, ManagedShop.fromJson),
      );
      if (!mounted) return;
      if (!envelope.isSuccess || envelope.data == null) {
        _toast(envelope.message ?? '获取失败,请检查网络连接');
        setState(() {
          if (reset) _items.clear();
          _loading = false;
          _loadingMore = false;
        });
        return;
      }
      final page = envelope.data!;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.list);
        _total = page.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      _toast('获取失败,请检查网络连接');
      setState(() {
        if (reset) _items.clear();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _maybeLoadMore(ScrollNotification notification) {
    if (_loading || _loadingMore || _items.length >= _total) return;
    if (notification.metrics.extentAfter > 160) return;
    _pageNo += 1;
    _load(reset: false);
  }

  Future<void> _selectShop(ManagedShop shop) async {
    final storage = ref.read(appStorageProvider);
    final raw = await storage.getUserDetail();
    final data = <String, dynamic>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data.addAll(Map<String, dynamic>.from(decoded));
      } catch (_) {}
    }
    data
      ..['shopId'] = shop.shopId
      ..['shopName'] = shop.name
      ..['avatar'] = shop.zipImageUrl.isNotEmpty
          ? shop.zipImageUrl
          : shop.imageUrl;
    await storage.saveUserDetail(jsonEncode(data));
  }

  Future<void> _scan(ManagedShop shop) async {
    await _selectShop(shop);
    if (!mounted) return;
    context.push(
      Uri(
        path: '/scan-code',
        queryParameters: {
          'mode': 'shop',
          'shopId': shop.shopId,
          'shopName': shop.name,
          'avatar': shop.zipImageUrl.isNotEmpty
              ? shop.zipImageUrl
              : shop.imageUrl,
        },
      ).toString(),
    );
  }

  Future<void> _goManage(ManagedShop shop) async {
    await _selectShop(shop);
    if (!mounted) return;
    context.push(
      Uri(
        path: '/shop-manage-detail',
        queryParameters: {
          'shopId': shop.shopId,
          'shopName': shop.name,
          'avatar': shop.zipImageUrl.isNotEmpty
              ? shop.zipImageUrl
              : shop.imageUrl,
        },
      ).toString(),
    );
  }

  void _toast(String message) {
    AppToast.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        title: const Text(
          '店铺管理',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _maybeLoadMore(notification);
              return false;
            },
            child: RefreshIndicator(
              color: AppTheme.brand,
              onRefresh: () => _load(reset: true),
              child: _items.isEmpty && !_loading
                  ? const _ShopManagerEmpty()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _items.length + (_items.isEmpty ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return _LoadMoreText(
                            loadingMore: _loadingMore,
                            noMore: _items.length >= _total,
                          );
                        }
                        final shop = _items[index];
                        return _ManagedShopCard(
                          shop: shop,
                          onScan: () => _scan(shop),
                          onManage: () => _goManage(shop),
                        );
                      },
                    ),
            ),
          ),
          if (_loading) const _ManagerLoading(),
        ],
      ),
    );
  }
}

class ShopManageDetailPage extends ConsumerStatefulWidget {
  const ShopManageDetailPage({required this.params, super.key});

  final Map<String, String> params;

  @override
  ConsumerState<ShopManageDetailPage> createState() =>
      _ShopManageDetailPageState();
}

class _ShopManageDetailPageState extends ConsumerState<ShopManageDetailPage> {
  String get _shopName => widget.params['shopName'] ?? '';
  String get _shopId => widget.params['shopId'] ?? '';
  String get _avatar => widget.params['avatar'] ?? '';

  void _scanCreateMember() {
    context.push(
      Uri(
        path: '/scan-code',
        queryParameters: {
          'mode': 'shop',
          'shopId': _shopId,
          'shopName': _shopName,
          'avatar': _avatar,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, size: 34),
        ),
        title: Text(
          _shopName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ManageMenuCard(
            children: [
              _ManageMenuItem(
                title: '创建会员',
                trailing: _GradientSmallButton(
                  text: '创建',
                  onTap: _scanCreateMember,
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF7F7F7)),
              _ManageMenuItem(
                title: '会员详情',
                onTap: () => context.push(
                  Uri(
                    path: '/member-detail-list',
                    queryParameters: {
                      'shopId': _shopId,
                      'shopName': _shopName,
                      'allowRefund': '1',
                    },
                  ).toString(),
                ),
              ),
            ],
          ),
          _ManageMenuCard(
            children: [
              _ManageMenuItem(
                title: '会员消费账单',
                onTap: () => context.push(
                  Uri(
                    path: '/member-static',
                    queryParameters: {'shopName': _shopName, 'shopId': _shopId},
                  ).toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagedShopCard extends StatelessWidget {
  const _ManagedShopCard({
    required this.shop,
    required this.onScan,
    required this.onManage,
  });

  final ManagedShop shop;
  final VoidCallback onScan;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: shop.imageUrl.isEmpty
                ? const Icon(
                    Icons.storefront_outlined,
                    color: Color(0xFFAAAAAA),
                  )
                : Image.network(
                    shop.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.storefront_outlined,
                      color: Color(0xFFAAAAAA),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _PillActionButton(
                        text: '扫码核销',
                        icon: Image.asset(
                          'assets/static/image/s-code.png',
                          width: 17,
                          height: 17,
                        ),
                        gradient: AppTheme.brandGradient,
                        onTap: onScan,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PillActionButton(
                        text: '店铺管理',
                        icon: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 18,
                        ),
                        color: const Color(0xFF4A4A4A),
                        onTap: onManage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillActionButton extends StatelessWidget {
  const _PillActionButton({
    required this.text,
    required this.icon,
    required this.onTap,
    this.gradient,
    this.color,
  });

  final String text;
  final Widget icon;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient,
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageMenuCard extends StatelessWidget {
  const _ManageMenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _ManageMenuItem extends StatelessWidget {
  const _ManageMenuItem({required this.title, this.trailing, this.onTap});

  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, color: Color(0xFF505050)),
            ),
            const Spacer(),
            trailing ??
                Container(
                  width: 17,
                  height: 17,
                  decoration: const BoxDecoration(
                    color: Color(0xFFCCCCCC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _GradientSmallButton extends StatelessWidget {
  const _GradientSmallButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 55,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

class _ShopManagerEmpty extends StatelessWidget {
  const _ShopManagerEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 200),
        Center(
          child: Column(
            children: [
              Image.asset(AppAssets.empty, width: 100, height: 83),
              const SizedBox(height: 10),
              const Text(
                '这里还什么都没有呢~',
                style: TextStyle(color: Color(0xFF999999), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadMoreText extends StatelessWidget {
  const _LoadMoreText({required this.loadingMore, required this.noMore});

  final bool loadingMore;
  final bool noMore;

  @override
  Widget build(BuildContext context) {
    if (noMore) return const SizedBox(height: 16);
    final text = loadingMore ? '努力加载中' : '轻轻上拉';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
      ),
    );
  }
}

class _ManagerLoading extends StatelessWidget {
  const _ManagerLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.2),
      child: Center(
        child: Container(
          width: 70,
          height: 65,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset('assets/static/data.gif'),
        ),
      ),
    );
  }
}

class ManagedShop {
  const ManagedShop({
    required this.shopId,
    required this.name,
    required this.imageUrl,
    required this.zipImageUrl,
  });

  final String shopId;
  final String name;
  final String imageUrl;
  final String zipImageUrl;

  factory ManagedShop.fromJson(Map<String, dynamic> json) {
    return ManagedShop(
      shopId: json['shopId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      zipImageUrl: json['zipImageUrl']?.toString() ?? '',
    );
  }
}
