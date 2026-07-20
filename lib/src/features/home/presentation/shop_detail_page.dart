import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/ui/app_toast.dart';
import '../data/home_models.dart';
import '../data/home_repository.dart';

class ShopDetailPage extends ConsumerStatefulWidget {
  const ShopDetailPage({required this.shopId, super.key});

  final String shopId;

  @override
  ConsumerState<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends ConsumerState<ShopDetailPage> {
  final _scrollController = ScrollController();
  final _pageController = PageController();
  final List<CouponSummary> _coupons = [];

  ShopDetail? _shop;
  var _imageIndex = 0;
  var _pageNo = 1;
  var _total = 0;
  var _isLoading = true;
  var _isLoadingMore = false;
  String? _error;

  bool get _hasMore => _coupons.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _coupons.clear();
      _pageNo = 1;
      _total = 0;
    });
    try {
      final repository = ref.read(homeRepositoryProvider);
      final results = await Future.wait([
        repository.getShopDetail(widget.shopId),
        repository.getCouponPage(pageNo: 1, shopId: widget.shopId),
      ]);
      if (!mounted) return;
      final couponPage = results[1] as PagedResult<CouponSummary>;
      setState(() {
        _shop = results[0] as ShopDetail;
        _coupons.addAll(couponPage.list);
        _total = couponPage.total;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 160) {
      _loadMoreCoupons();
    }
  }

  Future<void> _loadMoreCoupons() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _pageNo + 1;
      final result = await ref
          .read(homeRepositoryProvider)
          .getCouponPage(pageNo: nextPage, shopId: widget.shopId);
      if (!mounted) return;
      setState(() {
        _pageNo = nextPage;
        _coupons.addAll(result.list);
        _total = result.total;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      _toast(error.toString());
    }
  }

  Future<void> _toggleFav() async {
    final shop = _shop;
    if (shop == null) return;
    final storage = ref.read(appStorageProvider);
    final userId = await storage.getUserId();
    if (userId == null || userId.isEmpty) {
      _toast('请先登录');
      return;
    }
    try {
      if (shop.isFav) {
        await ref
            .read(homeRepositoryProvider)
            .deleteShopFav(userId: userId, shopId: shop.shopId);
        if (!mounted) return;
        setState(() => _shop = shop.copyWith(isFav: false));
        _toast('取消收藏成功');
      } else {
        await ref
            .read(homeRepositoryProvider)
            .addShopFav(userId: userId, shopId: shop.shopId);
        if (!mounted) return;
        setState(() => _shop = shop.copyWith(isFav: true));
        _toast('收藏成功');
      }
    } catch (error) {
      _toast(error.toString());
    }
  }

  Future<void> _openMap() async {
    final shop = _shop;
    if (shop == null || shop.latitude == null || shop.longitude == null) {
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
  }

  Future<void> _callShop() async {
    final telephone = (_shop?.telephone ?? '').trim();
    if (telephone.isEmpty) {
      _toast('当前商家暂无联系方式');
      return;
    }
    final normalizedPhone = telephone.replaceAll(RegExp(r'[\s-]'), '');
    final uri = Uri(scheme: 'tel', path: normalizedPhone);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('无法拨打电话');
    }
  }

  Future<void> _handleCouponBuy(CouponSummary coupon) async {
    final userId = await ref.read(appStorageProvider).getUserId();
    if (!mounted) return;
    if (userId == null || userId.isEmpty) {
      _toast('请先登录');
      return;
    }
    final encodedTitle = Uri.encodeComponent(coupon.couponName);
    context.push('/coupon/${coupon.couponId}?title=$encodedTitle');
  }

  void _toast(String message) {
    if (!mounted) return;
    AppToast.show(context, message);
  }

  void _pending(String name) => _toast('$name待迁移');

  @override
  Widget build(BuildContext context) {
    final shop = _shop;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          if (_isLoading)
            const _DetailLoading()
          else if (_error != null || shop == null)
            _DetailError(message: _error ?? '页面不存在', onRetry: _loadInitial)
          else
            _buildContent(shop),
          Positioned(
            top: 40,
            left: 16,
            child: _CircleButton(
              icon: Icons.chevron_left,
              onTap: Navigator.of(context).pop,
            ),
          ),
        ],
      ),
      bottomNavigationBar: shop == null
          ? null
          : _BottomActions(
              isFav: shop.isFav,
              onFav: _toggleFav,
              onScore: () => _pending('评分页'),
            ),
    );
  }

  Widget _buildContent(ShopDetail shop) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _ShopHeader(
            shop: shop,
            controller: _pageController,
            imageIndex: _imageIndex,
            onPageChanged: (index) => setState(() => _imageIndex = index),
            onMap: _openMap,
            onPhone: _callShop,
          ),
        ),
        if (_menuImagesFor(shop.shopId).isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionDivider()),
          SliverToBoxAdapter(child: _SectionTitle(title: '菜单')),
          SliverToBoxAdapter(
            child: _MenuCarousel(images: _menuImagesFor(shop.shopId)),
          ),
        ] else
          const SliverToBoxAdapter(child: _SectionDivider()),
        SliverToBoxAdapter(child: _SectionTitle(title: '团优惠')),
        if (_coupons.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: EmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.separated(
              itemCount: _coupons.length,
              separatorBuilder: (_, index) => index >= _coupons.length - 1
                  ? const SizedBox.shrink()
                  : const SizedBox(height: 11),
              itemBuilder: (context, index) {
                return _CouponCard(
                  coupon: _coupons[index],
                  onBuy: () => _handleCouponBuy(_coupons[index]),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({
    required this.shop,
    required this.controller,
    required this.imageIndex,
    required this.onPageChanged,
    required this.onMap,
    required this.onPhone,
  });

  static const _heroHeight = 250.0;
  static const _overlap = 35.0;

  final ShopDetail shop;
  final PageController controller;
  final int imageIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onMap;
  final VoidCallback onPhone;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _HeroImages(
          shop: shop,
          controller: controller,
          imageIndex: imageIndex,
          onPageChanged: onPageChanged,
          height: _heroHeight,
          indicatorBottom: _overlap + 18,
        ),
        Padding(
          padding: const EdgeInsets.only(top: _heroHeight - _overlap),
          child: _ShopInfoCard(shop: shop, onMap: onMap, onPhone: onPhone),
        ),
      ],
    );
  }
}

class _HeroImages extends StatelessWidget {
  const _HeroImages({
    required this.shop,
    required this.controller,
    required this.imageIndex,
    required this.onPageChanged,
    required this.height,
    required this.indicatorBottom,
  });

  final ShopDetail shop;
  final PageController controller;
  final int imageIndex;
  final ValueChanged<int> onPageChanged;
  final double height;
  final double indicatorBottom;

  @override
  Widget build(BuildContext context) {
    final images = shop.imageUrls;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            Container(
              color: const Color(0xFFEFEFEF),
              child: const Icon(Icons.storefront, size: 56, color: Colors.grey),
            )
          else
            PageView.builder(
              controller: controller,
              onPageChanged: onPageChanged,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFFEFEFEF),
                    child: const Icon(
                      Icons.storefront,
                      size: 56,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),
          if (images.length > 1)
            Positioned(
              right: 16,
              bottom: indicatorBottom,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${imageIndex + 1}/${images.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShopInfoCard extends StatelessWidget {
  const _ShopInfoCard({
    required this.shop,
    required this.onMap,
    required this.onPhone,
  });

  final ShopDetail shop;
  final VoidCallback onMap;
  final VoidCallback onPhone;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 28,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop.name.isEmpty ? '暂无数据' : shop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: shop.categories.isEmpty
                    ? const [_Tag(text: '暂无数据')]
                    : [
                        for (final category in shop.categories)
                          _Tag(text: category.categoryName),
                      ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _RatingStars(value: shop.rating),
                  const SizedBox(width: 4),
                  Text(
                    shop.rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 12, color: AppTheme.brand),
                  ),
                  const Spacer(),
                  Text(
                    shop.nearestStation,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                shop.introduce.isEmpty ? '暂无数据' : shop.introduce,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 45),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onMap,
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/static/image/local.png',
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                shop.address.isEmpty ? '暂无数据' : shop.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppTheme.brand,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onPhone,
                      icon: const Icon(Icons.phone, size: 18),
                      color: AppTheme.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E8F)),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 8, color: AppTheme.pageBg);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon, required this.onBuy});

  final CouponSummary coupon;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0DFE4D00),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 72,
              height: 72,
              child: coupon.imageUrl.isEmpty
                  ? Container(color: const Color(0xFFF0F0F0))
                  : Image.network(
                      coupon.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: const Color(0xFFF0F0F0)),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  coupon.couponName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    height: 1.15,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '￥${_money(coupon.couponPrice)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.brand,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '￥${_money(coupon.oriPrice)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                        decoration: TextDecoration.lineThrough,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.brand),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '共省${_money(coupon.savedPrice)}元',
                    style: const TextStyle(fontSize: 12, color: AppTheme.brand),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onBuy,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: 76,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  '立即团购',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCarousel extends StatefulWidget {
  const _MenuCarousel({required this.images});

  final List<String> images;

  @override
  State<_MenuCarousel> createState() => _MenuCarouselState();
}

class _MenuCarouselState extends State<_MenuCarousel> {
  final _controller = PageController();
  var _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        height: 400,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final image = widget.images[index];
                return GestureDetector(
                  onTap: () => _showMenuImage(context, image),
                  child: Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: Image.network(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFF0F0F0),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_index + 1}/${widget.images.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenuImage(BuildContext context, String image) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: Navigator.of(context).pop,
          child: ColoredBox(
            color: Colors.black,
            child: InteractiveViewer(
              child: Center(
                child: Image.network(
                  image,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.isFav,
    required this.onFav,
    required this.onScore,
  });

  final bool isFav;
  final VoidCallback onFav;
  final VoidCallback onScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF4F4F4))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: _BottomActionButton(
                  icon: isFav
                      ? 'assets/static/image/star-fill.png'
                      : 'assets/static/image/star.png',
                  label: isFav ? '已收藏' : '收藏店铺',
                  color: isFav ? const Color(0xFF999999) : AppTheme.brand,
                  onTap: onFav,
                ),
              ),
              Container(width: 1, height: 20, color: const Color(0xFFEEEEEE)),
              Expanded(
                child: _BottomActionButton(
                  icon: 'assets/static/image/remark.png',
                  label: '去评分',
                  color: AppTheme.brand,
                  onTap: onScore,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(icon, width: 24, height: 24),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 16, color: color)),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0x99000000),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.pageBg,
      child: Center(
        child: Container(
          width: 70,
          height: 65,
          padding: const EdgeInsets.all(8),
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

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

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
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppAssets.empty, width: 100, height: 83),
          const SizedBox(height: 10),
          const Text(
            '这里还什么都没有呢~',
            style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 1; index <= 5; index++)
          Padding(
            padding: EdgeInsets.only(right: index == 5 ? 0 : 2.5),
            child: _RatingStar(active: index <= value.round()),
          ),
      ],
    );
  }
}

class _RatingStar extends StatelessWidget {
  const _RatingStar({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: active ? AppTheme.brand : const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Icon(Icons.star, size: 12, color: Colors.white),
    );
  }
}

String _money(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

List<String> _menuImagesFor(String shopId) {
  if (shopId == '1') return _shopMenuImagesOne;
  if (shopId == '2') return _shopMenuImagesTwo;
  return const [];
}

const _shopMenuImagesOne = [
  'https://tuantuan-share.s3.ap-northeast-1.amazonaws.com/ted_temp/mean-1.jpg',
  'https://tuantuan-share.s3.ap-northeast-1.amazonaws.com/ted_temp/mean-2.jpg',
  'https://tuantuan-share.s3.ap-northeast-1.amazonaws.com/ted_temp/mean-3.jpg',
  'https://tuantuan-share.s3.ap-northeast-1.amazonaws.com/ted_temp/mean-4.jpg',
  'https://tuantuan-share.s3.ap-northeast-1.amazonaws.com/ted_temp/mean-5.jpg',
];

const _shopMenuImagesTwo = [
  'https://tuantuan-share.s3.ap-northeast-1.amazonaws.com/ted_temp/mean-6.jpg',
  'https://tuantuan-share.s3.ap-northeast-1.amazonaws.com/ted_temp/mean-7.jpg',
  'https://tuantuan-share.s3.ap-northeast-1.amazonaws.com/ted_temp/mean-8.jpg',
  'https://tuantuan-share.s3.ap-northeast-1.amazonaws.com/ted_temp/mean-9.jpg',
];
