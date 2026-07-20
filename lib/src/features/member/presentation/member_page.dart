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

class MemberPage extends ConsumerStatefulWidget {
  const MemberPage({super.key});

  @override
  ConsumerState<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends ConsumerState<MemberPage> {
  static const _pageSize = 10;

  final _items = <MemberCardInfo>[];
  ProviderSubscription<int>? _authSubscription;
  int _pageNo = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<int>(authRevisionProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(reset: true);
      });
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _authSubscription?.close();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      _pageNo = 1;
      _total = 0;
    }
    final token = await ref.read(appStorageProvider).getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _items.clear();
        _loading = false;
        _loadingMore = false;
      });
      return;
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
            TuanTuanEndpoints.userGroupList,
            data: {'pageNo': _pageNo, 'pageSize': _pageSize},
          );
      final envelope = ApiEnvelope.parse<PagedResult<MemberCardInfo>>(
        raw,
        (data) =>
            PagedResult.parse<MemberCardInfo>(data, MemberCardInfo.fromJson),
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

  Future<void> _refresh() async {
    await _load(reset: true);
  }

  void _maybeLoadMore(ScrollNotification notification) {
    if (_loading || _loadingMore || _items.length >= _total) return;
    if (notification.metrics.extentAfter > 160) return;
    _pageNo += 1;
    _load(reset: false);
  }

  void _toggleShop(MemberCardInfo card, MemberShopInfo shop) {
    setState(() {
      if (card.handleShopId == shop.shopId) {
        card.handleShopId = '';
        card.handleShopName = '';
      } else {
        card.handleShopId = shop.shopId;
        card.handleShopName = shop.name;
      }
    });
  }

  void _goRecharge(MemberCardInfo card) {
    if (card.handleShopId.isEmpty) {
      _toast('请点击选择充值店铺');
      return;
    }
    context.push(
      Uri(
        path: '/member-recharge',
        queryParameters: {
          'type': '1',
          'isShopCharge': '0',
          'shopId': card.handleShopId,
        },
      ).toString(),
    );
  }

  void _goRecord(MemberCardInfo card) {
    if (card.handleShopId.isEmpty) {
      _toast('请点击选择要查看记录的店铺');
      return;
    }
    context.push(
      Uri(
        path: '/member-record',
        queryParameters: {
          'shopId': card.handleShopId,
          'memberId': card.memberId,
          'shopName': card.handleShopName,
          'source': 'user',
          'allowRefund': '0',
        },
      ).toString(),
    );
  }

  void _scanJoin() {
    context.push('/scan-code');
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
          '会员',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _scanJoin,
            icon: Image.asset(
              'assets/static/image/s-code.png',
              width: 25,
              height: 25,
            ),
          ),
          const SizedBox(width: 8),
        ],
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
              onRefresh: _refresh,
              child: _items.isEmpty && !_loading
                  ? _EmptyMemberView(onScan: _scanJoin)
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      itemCount: _items.length + (_items.isEmpty ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return _LoadMoreText(
                            loadingMore: _loadingMore,
                            noMore: _items.length >= _total,
                          );
                        }
                        return _MemberCard(
                          card: _items[index],
                          gradient:
                              _cardGradients[index % _cardGradients.length],
                          onToggleShop: _toggleShop,
                          onToggleShopList: () {
                            setState(() {
                              _items[index].showShop = !_items[index].showShop;
                            });
                          },
                          onRecord: _goRecord,
                          onRecharge: _goRecharge,
                        );
                      },
                    ),
            ),
          ),
          if (_loading) const _MemberLoading(),
        ],
      ),
    );
  }
}

class MemberTargetPlaceholderPage extends StatelessWidget {
  const MemberTargetPlaceholderPage({
    required this.title,
    required this.sourcePage,
    required this.params,
    super.key,
  });

  final String title;
  final String sourcePage;
  final Map<String, String> params;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, size: 34),
        ),
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title 页面待迁移',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              sourcePage,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            if (params.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (final entry in params.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${entry.key}: ${entry.value}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.card,
    required this.gradient,
    required this.onToggleShop,
    required this.onToggleShopList,
    required this.onRecord,
    required this.onRecharge,
  });

  final MemberCardInfo card;
  final LinearGradient gradient;
  final void Function(MemberCardInfo card, MemberShopInfo shop) onToggleShop;
  final VoidCallback onToggleShopList;
  final void Function(MemberCardInfo card) onRecord;
  final void Function(MemberCardInfo card) onRecharge;

  @override
  Widget build(BuildContext context) {
    final shops = card.showShop ? card.shopInfoList : card.shopInfoList.take(3);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '余额：',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                '卡号:${card.memberCardId.isEmpty ? '--' : card.memberCardId}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  card.balanceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CardActionButton(text: '详情', onTap: () => onRecord(card)),
              const SizedBox(width: 5),
              _CardActionButton(text: '充值', onTap: () => onRecharge(card)),
            ],
          ),
          const SizedBox(height: 7),
          const Row(
            children: [
              Expanded(child: Divider(color: Color(0x66FFFFFF), height: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '所属店铺',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              Expanded(child: Divider(color: Color(0x66FFFFFF), height: 1)),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / 3;
              return Wrap(
                children: [
                  for (final shop in shops)
                    SizedBox(
                      width: itemWidth,
                      height: 60,
                      child: _ShopCell(
                        shop: shop,
                        selected: shop.shopId == card.handleShopId,
                        onTap: () => onToggleShop(card, shop),
                      ),
                    ),
                ],
              );
            },
          ),
          if (card.shopInfoList.length > 3)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleShopList,
              child: SizedBox(
                height: 18,
                child: Icon(
                  card.showShop
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 30,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 65,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ShopCell extends StatelessWidget {
  const _ShopCell({
    required this.shop,
    required this.selected,
    required this.onTap,
  });

  final MemberShopInfo shop;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: selected ? 0.5 : 1,
        child: Column(
          children: [
            ClipOval(
              child: SizedBox(
                width: 35,
                height: 35,
                child: shop.imageUrl.isEmpty
                    ? Container(
                        color: Colors.white.withValues(alpha: 0.25),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      )
                    : Image.network(
                        shop.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.white.withValues(alpha: 0.25),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              shop.name.isEmpty ? '--' : shop.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMemberView extends StatelessWidget {
  const _EmptyMemberView({required this.onScan});

  final VoidCallback onScan;

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
              const SizedBox(height: 8),
              const Text(
                '这里还什么都没有呢~',
                style: TextStyle(color: Color(0xFFA9A9A9), fontSize: 16),
              ),
              const SizedBox(height: 50),
              GestureDetector(
                onTap: onScan,
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 0.85,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/static/image/s-code.png',
                        width: 23,
                        height: 23,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '扫一扫加入会员',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
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
    if (noMore) return const SizedBox.shrink();
    final text = loadingMore ? '努力加载中' : '轻轻上拉';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
      ),
    );
  }
}

class _MemberLoading extends StatelessWidget {
  const _MemberLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.2),
      child: Center(
        child: Container(
          width: 86,
          height: 82,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Image.asset('assets/static/data.gif', width: 70, height: 65),
        ),
      ),
    );
  }
}

class MemberCardInfo {
  MemberCardInfo({
    required this.memberId,
    required this.memberCardId,
    required this.balanceText,
    required this.shopInfoList,
  });

  final String memberId;
  final String memberCardId;
  final String balanceText;
  final List<MemberShopInfo> shopInfoList;
  bool showShop = false;
  String handleShopId = '';
  String handleShopName = '';

  factory MemberCardInfo.fromJson(Map<String, dynamic> json) {
    final rawShops = json['shopInfoList'];
    return MemberCardInfo(
      memberId: json['memberId']?.toString() ?? '',
      memberCardId: json['memberCardId']?.toString() ?? '',
      balanceText: json['balance']?.toString() ?? '0',
      shopInfoList: rawShops is List
          ? rawShops
                .whereType<Map>()
                .map(
                  (item) =>
                      MemberShopInfo.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class MemberShopInfo {
  const MemberShopInfo({
    required this.shopId,
    required this.name,
    required this.imageUrl,
  });

  final String shopId;
  final String name;
  final String imageUrl;

  factory MemberShopInfo.fromJson(Map<String, dynamic> json) {
    return MemberShopInfo(
      shopId: json['shopId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }
}

const _cardGradients = [
  LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFFFE4D00), Color(0xFFFF9809)],
  ),
  LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFFFF9040), Color(0xFFFFB973)],
  ),
  LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFFFF66B2), Color(0xFFFF99D4)],
  ),
  LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF7064F9), Color(0xFFA08DFF)],
  ),
  LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFFB266FF), Color(0xFFED8DFF)],
  ),
  LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFFFFB60C), Color(0xFFFFDD00)],
  ),
  LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF04DB70), Color(0xFF3FF392)],
  ),
  LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF00CCBB), Color(0xFF19E6D5)],
  ),
  LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF05C9FA), Color(0xFF28E8FE)],
  ),
  LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF3399FF), Color(0xFF80BFFF)],
  ),
];
