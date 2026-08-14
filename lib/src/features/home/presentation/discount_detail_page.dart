import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/ui/app_toast.dart';
import '../../../shared/widgets/cached_image.dart';
import '../data/home_models.dart';
import '../data/home_repository.dart';

class DiscountDetailPage extends ConsumerStatefulWidget {
  const DiscountDetailPage({required this.params, super.key});

  final Map<String, String> params;

  String get couponId => params['couponId'] ?? '';
  String get title => params['title'] ?? '';
  String get shopId => params['shopId'] ?? '';
  String get shopName => params['shopName'] ?? '';
  String get stationId => params['stationId'] ?? '';
  int get pageNo => int.tryParse(params['pageNo'] ?? '') ?? 1;
  int get index => int.tryParse(params['index'] ?? '') ?? 0;
  int get total => int.tryParse(params['total'] ?? '') ?? 0;

  @override
  ConsumerState<DiscountDetailPage> createState() => _DiscountDetailPageState();
}

class _DiscountDetailPageState extends ConsumerState<DiscountDetailPage> {
  static const int _pageSize = 10;

  final PageController _pageController = PageController();
  final Map<String, ShopDetail> _shopCache = {};
  final Set<String> _detailLoadingIds = {};

  CouponDetail? _singleCoupon;
  List<CouponMain> _coupons = const [];
  int _firstPageNo = 1;
  int _lastPageNo = 1;
  int _currentIndex = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  bool get _isPagedEntry => widget.stationId.isNotEmpty;
  CouponMain? get _currentCoupon => _coupons.isEmpty
      ? null
      : _coupons[_currentIndex.clamp(0, _coupons.length - 1)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isPagedEntry) {
        await _loadPaged();
      } else {
        await _loadSingle();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadSingle() async {
    final coupon = await ref
        .read(homeRepositoryProvider)
        .getCouponInfo(couponId: widget.couponId);
    if (!mounted) return;
    setState(() {
      _singleCoupon = coupon;
      _loading = false;
    });
  }

  Future<void> _loadPaged() async {
    final result = await ref
        .read(homeRepositoryProvider)
        .getCouponPageMain(pageNo: widget.pageNo, stationId: widget.stationId);
    if (!mounted) return;
    final localIndex = result.list.isEmpty
        ? 0
        : (widget.index % _pageSize).clamp(0, result.list.length - 1);
    setState(() {
      _coupons = result.list;
      _firstPageNo = widget.pageNo;
      _lastPageNo = widget.pageNo;
      _currentIndex = localIndex;
      _total = widget.total > 0 ? widget.total : result.total;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && localIndex > 0) {
        _pageController.jumpToPage(localIndex);
      }
    });
    await _ensureCurrentDetail();
  }

  Future<void> _ensureCurrentDetail() async {
    final coupon = _currentCoupon;
    if (coupon == null ||
        coupon.items.isNotEmpty ||
        _detailLoadingIds.contains(coupon.couponId)) {
      return;
    }
    _detailLoadingIds.add(coupon.couponId);
    try {
      final detail = await ref
          .read(homeRepositoryProvider)
          .getCouponInfo(couponId: coupon.couponId);
      if (!mounted) return;
      final index = _coupons.indexWhere(
        (item) => item.couponId == coupon.couponId,
      );
      if (index == -1) return;
      final next = List<CouponMain>.from(_coupons);
      next[index] = next[index].copyWith(items: detail.items);
      setState(() => _coupons = next);
    } catch (_) {
      // The main card can still be used without the package detail list.
    } finally {
      _detailLoadingIds.remove(coupon.couponId);
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || _lastPageNo * _pageSize >= _total) return;
    final nextPage = _lastPageNo + 1;
    setState(() => _loadingMore = true);
    try {
      final result = await ref
          .read(homeRepositoryProvider)
          .getCouponPageMain(pageNo: nextPage, stationId: widget.stationId);
      if (!mounted) return;
      setState(() {
        _coupons = [..._coupons, ...result.list];
        _lastPageNo = nextPage;
        _total = result.total > 0 ? result.total : _total;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _toast(error.toString());
    }
  }

  Future<void> _loadPreviousPage() async {
    if (_loadingMore || _firstPageNo <= 1) return;
    final previousPage = _firstPageNo - 1;
    setState(() => _loadingMore = true);
    try {
      final result = await ref
          .read(homeRepositoryProvider)
          .getCouponPageMain(pageNo: previousPage, stationId: widget.stationId);
      if (!mounted) return;
      final insertedCount = result.list.length;
      setState(() {
        _coupons = [...result.list, ..._coupons];
        _firstPageNo = previousPage;
        _currentIndex += insertedCount;
        _total = result.total > 0 ? result.total : _total;
        _loadingMore = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _toast(error.toString());
    }
  }

  Future<void> _onPageChanged(int index) async {
    setState(() => _currentIndex = index);
    await _ensureCurrentDetail();
    if (index >= _coupons.length - 2) {
      await _loadNextPage();
    } else if (index == 0) {
      await _loadPreviousPage();
    }
  }

  Future<void> _copyItems(List<CouponDetailItem> items) async {
    if (items.isEmpty) return;
    final value = items
        .map((item) => '${item.goodsName}:${item.quantity}${item.unit}')
        .join(',');
    await Clipboard.setData(ClipboardData(text: value));
    _toast('复制成功');
  }

  Future<void> _toggleFav() async {
    final coupon = _currentCoupon;
    if (coupon == null || coupon.shopId.isEmpty) return;
    final userId = await ref.read(appStorageProvider).getUserId();
    if (userId == null || userId.isEmpty) {
      _toast('请先登录');
      return;
    }
    try {
      if (coupon.isFav) {
        await ref
            .read(homeRepositoryProvider)
            .deleteShopFav(userId: userId, shopId: coupon.shopId);
        _updateCurrentCoupon(coupon.copyWith(isFav: false));
        _toast('取消收藏成功');
      } else {
        await ref
            .read(homeRepositoryProvider)
            .addShopFav(userId: userId, shopId: coupon.shopId);
        _updateCurrentCoupon(coupon.copyWith(isFav: true));
        _toast('收藏成功');
      }
    } catch (error) {
      _toast(error.toString());
    }
  }

  void _updateCurrentCoupon(CouponMain coupon) {
    if (!mounted) return;
    final next = List<CouponMain>.from(_coupons);
    next[_currentIndex] = coupon;
    setState(() => _coupons = next);
  }

  Future<void> _openMap() async {
    final coupon = _currentCoupon;
    final shopId = coupon?.shopId ?? widget.shopId;
    if (shopId.isEmpty) return;
    try {
      final shop =
          _shopCache[shopId] ??
          await ref.read(homeRepositoryProvider).getShopDetail(shopId);
      _shopCache[shopId] = shop;
      if (shop.latitude == null || shop.longitude == null) {
        _toast('当前店铺暂无位置信息');
        return;
      }
      final uri = Uri.https('maps.apple.com', '/', {
        'q': shop.name,
        'address': shop.address,
        'll': '${shop.latitude},${shop.longitude}',
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _toast('无法打开地图');
      }
    } catch (error) {
      _toast(error.toString());
    }
  }

  void _goOrder(String couponId) {
    context.push('/submit-order?couponId=${Uri.encodeComponent(couponId)}');
  }

  void _goShop(String shopId) {
    if (shopId.isEmpty) return;
    context.push('/shop/$shopId');
  }

  void _toast(String message) {
    AppToast.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.isNotEmpty ? widget.title : '团优惠详情';
    return Scaffold(
      backgroundColor: _isPagedEntry
          ? _palette(_firstPageNo, _currentIndex).background
          : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, size: 34),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.brand),
            )
          : _error != null
          ? _DiscountDetailError(message: _error!, onRetry: _load)
          : _isPagedEntry
          ? _buildPagedBody()
          : _buildSingleBody(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : _isPagedEntry
          ? _buildPagedBottom()
          : _buildSingleBottom(),
    );
  }

  Widget _buildPagedBody() {
    if (_coupons.isEmpty) {
      return _DiscountDetailError(message: '优惠不存在', onRetry: _load);
    }
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: _coupons.length,
          itemBuilder: (context, index) {
            final coupon = _coupons[index];
            return _DiscountMainBody(
              coupon: coupon,
              palette: _palette(_firstPageNo, index),
              onCopy: () => _copyItems(coupon.items),
              onShop: () => _goShop(coupon.shopId),
              onMap: _openMap,
            );
          },
        ),
        if (_loadingMore)
          const Positioned(
            right: 18,
            top: 8,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleBody() {
    final coupon = _singleCoupon;
    if (coupon == null) {
      return _DiscountDetailError(message: '优惠不存在', onRetry: _load);
    }
    return _DiscountSingleBody(
      coupon: coupon,
      shopId: widget.shopId,
      shopName: widget.shopName,
      onCopy: () => _copyItems(coupon.items),
      onShop: () => _goShop(widget.shopId),
    );
  }

  Widget? _buildSingleBottom() {
    final coupon = _singleCoupon;
    if (coupon == null) return null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: _BuyButton(onTap: () => _goOrder(coupon.couponId)),
      ),
    );
  }

  Widget? _buildPagedBottom() {
    final coupon = _currentCoupon;
    if (coupon == null) return null;
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Row(
          children: [
            _BottomIconButton(
              icon: coupon.isFav ? Icons.star : Icons.star_border,
              label: '收藏',
              color: coupon.isFav
                  ? const Color(0xFFFFB020)
                  : AppTheme.textPrimary,
              onTap: _toggleFav,
            ),
            const SizedBox(width: 14),
            Expanded(child: _BuyButton(onTap: () => _goOrder(coupon.couponId))),
          ],
        ),
      ),
    );
  }
}

class _DiscountMainBody extends StatelessWidget {
  const _DiscountMainBody({
    required this.coupon,
    required this.palette,
    required this.onCopy,
    required this.onShop,
    required this.onMap,
  });

  final CouponMain coupon;
  final _DiscountPalette palette;
  final VoidCallback onCopy;
  final VoidCallback onShop;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 112),
      children: [
        _ShopHeader(
          logoUrl: coupon.logoImageUrl,
          shopName: coupon.shopName,
          address: coupon.address,
          onShop: onShop,
          onMap: onMap,
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CouponImage(imageUrl: coupon.imageUrl),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupon.couponName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '￥${_money(coupon.couponPrice)}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.brand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '￥${_money(coupon.oriPrice)}',
                          style: const TextStyle(
                            color: Color(0xFF999999),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const Spacer(),
                        _OffBadge(
                          rate: coupon.discountRate,
                          color: palette.accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PackageCard(items: coupon.items, onCopy: onCopy),
      ],
    );
  }
}

class _DiscountSingleBody extends StatelessWidget {
  const _DiscountSingleBody({
    required this.coupon,
    required this.shopId,
    required this.shopName,
    required this.onCopy,
    required this.onShop,
  });

  final CouponDetail coupon;
  final String shopId;
  final String shopName;
  final VoidCallback onCopy;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        if (shopName.isNotEmpty)
          _ShopHeader(
            logoUrl: '',
            shopName: shopName,
            address: '',
            onShop: shopId.isEmpty ? null : onShop,
          ),
        if (shopName.isNotEmpty) const SizedBox(height: 16),
        _CouponImage(imageUrl: coupon.imageUrl),
        const SizedBox(height: 16),
        Text(
          coupon.couponName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '￥${_money(coupon.couponPrice)}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.brand,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '￥${_money(coupon.oriPrice)}',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF999999),
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const Spacer(),
            _OffBadge(rate: coupon.offRate, color: AppTheme.brand),
          ],
        ),
        const SizedBox(height: 18),
        _PackageCard(items: coupon.items, onCopy: onCopy),
      ],
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({
    required this.logoUrl,
    required this.shopName,
    required this.address,
    this.onShop,
    this.onMap,
  });

  final String logoUrl;
  final String shopName;
  final String address;
  final VoidCallback? onShop;
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onShop,
            child: ClipOval(
              child: SizedBox(
                width: 46,
                height: 46,
                child: logoUrl.isEmpty
                    ? Image.asset('assets/static/image/shop.png')
                    : AppCachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.cover,
                        errorWidget: Image.asset(
                          'assets/static/image/shop.png',
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onShop,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onMap != null)
            IconButton(
              onPressed: onMap,
              icon: const Icon(
                Icons.location_on_outlined,
                color: AppTheme.brand,
              ),
              tooltip: '地图',
            )
          else if (onShop != null)
            const Icon(Icons.chevron_right, color: AppTheme.brand),
        ],
      ),
    );
  }
}

class _CouponImage extends StatelessWidget {
  const _CouponImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1.75,
        child: imageUrl.isEmpty
            ? Container(color: const Color(0xFFF5F5F5))
            : AppCachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                errorWidget: Container(color: const Color(0xFFF5F5F5)),
              ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.items, required this.onCopy});

  final List<CouponDetailItem> items;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '套餐详情',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: items.isEmpty ? null : onCopy,
                child: const Text('复制'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (items.isEmpty)
            const Text('暂无明细', style: TextStyle(color: AppTheme.textSecondary))
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(child: Text(item.goodsName)),
                    Text('${item.quantity}${item.unit}'),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          '立即团购',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BottomIconButton extends StatelessWidget {
  const _BottomIconButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 54,
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class _OffBadge extends StatelessWidget {
  const _OffBadge({required this.rate, required this.color});

  final int rate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rate.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
              height: .9,
            ),
          ),
          Text(
            '% OFF',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscountDetailError extends StatelessWidget {
  const _DiscountDetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _DiscountPalette {
  const _DiscountPalette({required this.background, required this.accent});

  final Color background;
  final Color accent;
}

_DiscountPalette _palette(int firstPageNo, int index) {
  const palettes = [
    _DiscountPalette(background: Color(0xFFFFF4EC), accent: Color(0xFFFF6948)),
    _DiscountPalette(background: Color(0xFFEFF8FF), accent: Color(0xFF1687D9)),
    _DiscountPalette(background: Color(0xFFF2F7EE), accent: Color(0xFF35A85B)),
    _DiscountPalette(background: Color(0xFFFFF7E6), accent: Color(0xFFE79A20)),
    _DiscountPalette(background: Color(0xFFF7F0FF), accent: Color(0xFF8156D9)),
  ];
  final globalIndex =
      ((firstPageNo - 1) * _DiscountDetailPageState._pageSize) + index;
  return palettes[globalIndex % palettes.length];
}

String _money(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
