import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_assets.dart';
import '../../home/data/home_models.dart';
import '../../home/data/home_repository.dart';

class DiscountsPage extends ConsumerStatefulWidget {
  const DiscountsPage({super.key});

  @override
  ConsumerState<DiscountsPage> createState() => _DiscountsPageState();
}

class _DiscountsPageState extends ConsumerState<DiscountsPage> {
  final _pageController = PageController();
  final Map<String, ScrollController> _scrollControllers = {};
  final Map<String, _CouponPageState> _couponStates = {};

  List<Station> _stations = const [];

  var _currentStation = 0;
  var _isBootstrapping = true;
  String? _bootstrapError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isBootstrapping = true;
      _bootstrapError = null;
      _couponStates.clear();
    });

    try {
      final position = await _resolveLocation();
      final stations = await ref
          .read(homeRepositoryProvider)
          .getCouponStations(longitude: position.$1, latitude: position.$2);
      if (!mounted) return;
      setState(() {
        _stations = stations;
        _currentStation = 0;
        _isBootstrapping = false;
      });
      if (stations.isEmpty) {
        return;
      }
      await _reloadCoupons(stationIndex: 0);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bootstrapError = error.toString();
        _isBootstrapping = false;
      });
    }
  }

  Future<(double, double)> _resolveLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (0.0, 0.0);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return (position.longitude, position.latitude);
    } catch (_) {
      return (0.0, 0.0);
    }
  }

  Future<void> _reloadCoupons({required int stationIndex}) async {
    if (stationIndex < 0 || stationIndex >= _stations.length) return;
    final stationId = _stations[stationIndex].stationId;
    setState(() {
      _couponStates[stationId] = _stateFor(stationId).copyWith(
        coupons: const [],
        pageNo: 1,
        total: 0,
        isInitialLoading: true,
        isLoadingMore: false,
        error: null,
      );
    });
    await _loadCoupons(stationIndex: stationIndex, pageNo: 1, replace: true);
  }

  Future<void> _loadCoupons({
    required int stationIndex,
    required int pageNo,
    required bool replace,
  }) async {
    if (stationIndex < 0 || stationIndex >= _stations.length) return;
    final stationId = _stations[stationIndex].stationId;
    try {
      final result = await ref
          .read(homeRepositoryProvider)
          .getCouponPageMain(pageNo: pageNo, stationId: stationId);
      if (!mounted) return;
      setState(() {
        final previous = _stateFor(stationId);
        _couponStates[stationId] = previous.copyWith(
          pageNo: pageNo,
          coupons: replace
              ? result.list
              : [...previous.coupons, ...result.list],
          total: result.total,
          isInitialLoading: false,
          isLoadingMore: false,
          error: null,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _couponStates[stationId] = _stateFor(stationId).copyWith(
          error: error.toString(),
          isInitialLoading: false,
          isLoadingMore: false,
        );
      });
    }
  }

  void _ensureStationLoaded(int stationIndex) {
    if (stationIndex < 0 || stationIndex >= _stations.length) return;
    final stationId = _stations[stationIndex].stationId;
    if (!_couponStates.containsKey(stationId)) {
      _reloadCoupons(stationIndex: stationIndex);
      return;
    }
    final state = _stateFor(stationId);
    if (state.isInitialLoading ||
        state.isLoadingMore ||
        state.coupons.isNotEmpty) {
      return;
    }
    _reloadCoupons(stationIndex: stationIndex);
  }

  void _loadMoreForStation(int stationIndex) {
    if (stationIndex < 0 || stationIndex >= _stations.length) return;
    final stationId = _stations[stationIndex].stationId;
    final state = _stateFor(stationId);
    if (state.isInitialLoading || state.isLoadingMore || !state.hasMore) return;
    setState(() {
      _couponStates[stationId] = state.copyWith(isLoadingMore: true);
    });
    _loadCoupons(
      stationIndex: stationIndex,
      pageNo: state.pageNo + 1,
      replace: false,
    );
  }

  Future<void> _selectStation(int index) async {
    if (index == _currentStation) return;
    setState(() => _currentStation = index);
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    _ensureStationLoaded(index);
  }

  void _handleStationPageChanged(int index) {
    if (_currentStation != index) {
      setState(() => _currentStation = index);
    }
    _ensureStationLoaded(index);
  }

  void _openCoupon(CouponMain coupon) {
    final title = Uri.encodeComponent(coupon.couponName);
    context.push('/coupon/${coupon.couponId}?title=$title');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      body: Stack(
        children: [
          Column(
            children: [
              _DiscountHeader(
                stations: _stations,
                currentStation: _currentStation,
                onSearchTap: () => context.push('/search'),
                onStationTap: _selectStation,
              ),
              Expanded(child: _buildBody()),
            ],
          ),
          if (_isBootstrapping) const _DiscountLoading(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_bootstrapError != null && _stations.isEmpty && !_isBootstrapping) {
      return _DiscountError(message: _bootstrapError!, onRetry: _bootstrap);
    }
    if (_stations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _bootstrap,
        child: const _DiscountEmpty(),
      );
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _stations.length,
      onPageChanged: _handleStationPageChanged,
      itemBuilder: (context, index) {
        final stationId = _stations[index].stationId;
        final controller = _scrollControllerFor(stationId);
        return _DiscountStationPage(
          state: _stateFor(stationId),
          controller: controller,
          onRefresh: () => _reloadCoupons(stationIndex: index),
          onLoadMore: () => _loadMoreForStation(index),
          onRetry: () => _reloadCoupons(stationIndex: index),
          onCouponTap: _openCoupon,
        );
      },
    );
  }

  _CouponPageState _stateFor(String stationId) {
    return _couponStates[stationId] ??
        const _CouponPageState(isInitialLoading: true);
  }

  ScrollController _scrollControllerFor(String stationId) {
    return _scrollControllers.putIfAbsent(stationId, ScrollController.new);
  }
}

class _CouponPageState {
  const _CouponPageState({
    this.coupons = const [],
    this.pageNo = 1,
    this.total = 0,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<CouponMain> coupons;
  final int pageNo;
  final int total;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final String? error;

  bool get hasMore => coupons.length < total;

  _CouponPageState copyWith({
    List<CouponMain>? coupons,
    int? pageNo,
    int? total,
    bool? isInitialLoading,
    bool? isLoadingMore,
    Object? error = _copySentinel,
  }) {
    return _CouponPageState(
      coupons: coupons ?? this.coupons,
      pageNo: pageNo ?? this.pageNo,
      total: total ?? this.total,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error == _copySentinel ? this.error : error as String?,
    );
  }
}

const _copySentinel = Object();

class _DiscountStationPage extends StatelessWidget {
  const _DiscountStationPage({
    required this.state,
    required this.controller,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetry,
    required this.onCouponTap,
  });

  final _CouponPageState state;
  final ScrollController controller;
  final RefreshCallback onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final ValueChanged<CouponMain> onCouponTap;

  @override
  Widget build(BuildContext context) {
    if (state.error != null &&
        state.coupons.isEmpty &&
        !state.isInitialLoading) {
      return _DiscountError(message: state.error!, onRetry: onRetry);
    }

    if (state.isInitialLoading && state.coupons.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 70,
          height: 65,
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Image(image: AssetImage(AppAssets.loading)),
          ),
        ),
      );
    }

    if (state.coupons.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: const _DiscountEmpty(),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 120) {
            onLoadMore();
          }
          return false;
        },
        child: ListView.builder(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          itemCount: state.coupons.length + 1,
          itemBuilder: (context, index) {
            if (index == state.coupons.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Center(
                  child: Text(
                    state.hasMore
                        ? (state.isLoadingMore ? '努力加载中' : '轻轻上拉')
                        : '优惠内容已经到底了～',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              );
            }
            final coupon = state.coupons[index];
            final palette = _couponPalettes[index % _couponPalettes.length];
            return _AnimatedDiscountCardSlot(
              index: index,
              controller: controller,
              child: _DiscountCouponCard(
                coupon: coupon,
                palette: palette,
                onTap: () => onCouponTap(coupon),
              ),
            );
          },
        ),
      ),
    );
  }
}

const _discountCardHeight = 168.0;
const _discountCardOverlap = 16.0;
const _discountCardStep = _discountCardHeight - _discountCardOverlap;
const _discountListTopPadding = 20.0;

class _AnimatedDiscountCardSlot extends StatelessWidget {
  const _AnimatedDiscountCardSlot({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: index == 0 ? _discountCardHeight : _discountCardStep,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final offset = controller.hasClients ? controller.offset : 0.0;
          final cardTop =
              _discountListTopPadding + index * _discountCardStep - offset;
          final progress = ((-cardTop) / _discountCardHeight).clamp(0.0, 1.0);
          final scale = 1.0 - progress * 0.22;
          final opacity = (1.0 - progress * 1.35).clamp(0.0, 1.0);

          return IgnorePointer(
            ignoring: opacity < 0.05,
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, index == 0 ? 0 : -_discountCardOverlap),
                child: Transform.scale(
                  alignment: Alignment.topCenter,
                  scale: scale,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: child,
      ),
    );
  }
}

class _DiscountHeader extends StatelessWidget {
  const _DiscountHeader({
    required this.stations,
    required this.currentStation,
    required this.onSearchTap,
    required this.onStationTap,
  });

  final List<Station> stations;
  final int currentStation;
  final VoidCallback onSearchTap;
  final ValueChanged<int> onStationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x1AFE4E00), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.75],
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onSearchTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.only(left: 14, right: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 20,
                      color: Color(0xFF999999),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '请输入商户名、地点或菜名',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFCCCCCC),
                        ),
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '搜索',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 24),
              itemBuilder: (context, index) {
                final active = index == currentStation;
                return GestureDetector(
                  onTap: () => onStationTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stations[index].stationName,
                        style: TextStyle(
                          fontSize: 16,
                          color: active
                              ? AppTheme.brand
                              : AppTheme.textSecondary,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: active ? 32 : 0,
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: AppTheme.brandGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscountCouponCard extends StatelessWidget {
  const _DiscountCouponCard({
    required this.coupon,
    required this.palette,
    required this.onTap,
  });

  final CouponMain coupon;
  final _CouponPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 168,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.top, palette.bottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, -2),
              blurRadius: 10,
            ),
            BoxShadow(color: Color(0x4D000000), blurRadius: 10),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              bottom: -35,
              width: 225,
              height: 225,
              child: Opacity(
                opacity: 0.2,
                child: Image.asset(AppAssets.hotLogo, fit: BoxFit.fill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  SizedBox(
                    height: 60,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ClipOval(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: coupon.logoImageUrl.isEmpty
                                  ? Container(color: Colors.white24)
                                  : Image.network(
                                      coupon.logoImageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          Container(color: Colors.white24),
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 48,
                          right: 100,
                          top: 0,
                          bottom: 0,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              coupon.shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 96,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${coupon.categoryName} | ${coupon.distance}m',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 78,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            AppAssets.couponBg,
                            fit: BoxFit.fill,
                          ),
                        ),
                        Positioned(
                          left: 205,
                          top: 10,
                          bottom: 10,
                          child: Container(
                            width: 1,
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: palette.top,
                                  style: BorderStyle.solid,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          bottom: 12,
                          width: 193,
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: coupon.imageUrl.isEmpty
                                      ? Container(
                                          color: const Color(0xFFF0F0F0),
                                        )
                                      : Image.network(
                                          coupon.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            color: const Color(0xFFF0F0F0),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      coupon.couponName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '￥${_money(coupon.couponPrice)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.brand,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '￥${_money(coupon.oriPrice)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF999999),
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 105,
                          child: _DiscountRate(rate: coupon.discountRate),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountRate extends StatelessWidget {
  const _DiscountRate({required this.rate});

  final int rate;

  @override
  Widget build(BuildContext context) {
    final isHundred = rate == 100;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: SizedBox(
              height: 58,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  rate == 0 ? '--' : '$rate',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: isHundred ? 40 : 52,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF9809),
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '%',
                style: TextStyle(fontSize: 11, color: Color(0xFFFF9809)),
              ),
              Text(
                'OFF',
                style: TextStyle(fontSize: 11, color: Color(0xFFFF9809)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscountLoading extends StatelessWidget {
  const _DiscountLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x33000000),
      child: Center(
        child: Container(
          width: 70,
          height: 65,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset(AppAssets.loading),
        ),
      ),
    );
  }
}

class _DiscountEmpty extends StatelessWidget {
  const _DiscountEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(AppAssets.empty, width: 100, height: 83),
              const SizedBox(height: 10),
              const Text(
                '这里还什么都没有呢~',
                style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscountError extends StatelessWidget {
  const _DiscountError({required this.message, required this.onRetry});

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

class _CouponPalette {
  const _CouponPalette(this.top, this.bottom);

  final Color top;
  final Color bottom;
}

const _couponPalettes = [
  _CouponPalette(Color(0xFFFF4252), Color(0xFFFF7396)),
  _CouponPalette(Color(0xFFFF9040), Color(0xFFFFB973)),
  _CouponPalette(Color(0xFFFF66B2), Color(0xFFFF99D4)),
  _CouponPalette(Color(0xFF7064F9), Color(0xFFA08DFF)),
  _CouponPalette(Color(0xFFB266FF), Color(0xFFED8DFF)),
  _CouponPalette(Color(0xFFFFB60C), Color(0xFFFFDD00)),
  _CouponPalette(Color(0xFF04DB70), Color(0xFF3FF392)),
  _CouponPalette(Color(0xFF00CCBB), Color(0xFF19E6D5)),
  _CouponPalette(Color(0xFF05C9FA), Color(0xFF28E8FE)),
  _CouponPalette(Color(0xFF3399FF), Color(0xFF80BFFF)),
];

String _money(double value) {
  if (value % 1 == 0) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
