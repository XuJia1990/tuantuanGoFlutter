import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../data/home_models.dart';
import '../data/home_repository.dart';
import 'shop_summary_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _pageController = PageController();

  List<Station> _stations = const [];
  List<HomeCategory> _categories = const [];
  List<HomeCategory> _sorts = const [];
  final Map<String, _ShopListState> _shopStates = {};

  var _currentStation = 0;
  var _isBootstrapping = true;
  String? _bootstrapError;
  String _sortCondition = '';
  String _typeCondition = '';
  String _sortTitle = '综合排序';
  String _typeTitle = '全部美食';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isBootstrapping = true;
      _bootstrapError = null;
      _shopStates.clear();
    });

    try {
      final repository = ref.read(homeRepositoryProvider);
      final position = await _resolveLocation();
      final results = await Future.wait([
        repository.getStations(longitude: position.$1, latitude: position.$2),
        repository.getCategories(1),
        repository.getCategories(3),
      ]);

      final stations = results[0] as List<Station>;
      final categories = results[1] as List<HomeCategory>;
      final sorts = results[2] as List<HomeCategory>;
      final firstSort = sorts.isNotEmpty ? sorts.first : null;

      if (!mounted) return;
      setState(() {
        _stations = stations;
        _categories = categories;
        _sorts = sorts;
        _currentStation = 0;
        _sortCondition = firstSort?.categoryId ?? '';
        _sortTitle = firstSort?.categoryName ?? '综合排序';
        _typeCondition = '';
        _typeTitle = '全部美食';
        _isBootstrapping = false;
      });

      if (stations.isNotEmpty) {
        await _reloadShops(stationIndex: 0);
      }
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

  Future<void> _reloadCurrentShops() {
    return _reloadShops(stationIndex: _currentStation);
  }

  Future<void> _reloadShops({required int stationIndex}) async {
    if (stationIndex < 0 || stationIndex >= _stations.length) return;
    final stationId = _stations[stationIndex].stationId;
    setState(() {
      _shopStates[stationId] = _stateFor(stationId).copyWith(
        shops: const [],
        pageNo: 1,
        total: 0,
        isInitialLoading: true,
        isLoadingMore: false,
        error: null,
      );
    });
    await _loadShops(stationIndex: stationIndex, pageNo: 1, replace: true);
  }

  Future<void> _loadShops({
    required int stationIndex,
    required int pageNo,
    required bool replace,
  }) async {
    if (stationIndex < 0 || stationIndex >= _stations.length) return;
    final stationId = _stations[stationIndex].stationId;
    try {
      final result = await ref
          .read(homeRepositoryProvider)
          .getShopList(
            pageNo: pageNo,
            stationId: stationId,
            sortCondition: _sortCondition,
            typeCondition: _typeCondition,
          );
      if (!mounted) return;
      setState(() {
        final previous = _stateFor(stationId);
        _shopStates[stationId] = previous.copyWith(
          pageNo: pageNo,
          shops: replace ? result.list : [...previous.shops, ...result.list],
          total: result.total,
          isInitialLoading: false,
          isLoadingMore: false,
          error: null,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _shopStates[stationId] = _stateFor(stationId).copyWith(
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
    if (!_shopStates.containsKey(stationId)) {
      _reloadShops(stationIndex: stationIndex);
      return;
    }
    final state = _stateFor(stationId);
    if (state.isInitialLoading ||
        state.isLoadingMore ||
        state.shops.isNotEmpty) {
      return;
    }
    _reloadShops(stationIndex: stationIndex);
  }

  void _loadMoreForStation(int stationIndex) {
    if (stationIndex < 0 || stationIndex >= _stations.length) return;
    final stationId = _stations[stationIndex].stationId;
    final state = _stateFor(stationId);
    if (state.isInitialLoading || state.isLoadingMore || !state.hasMore) return;
    setState(() {
      _shopStates[stationId] = state.copyWith(isLoadingMore: true);
    });
    _loadShops(
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

  void _reloadCurrentFilterResult() {
    setState(_shopStates.clear);
    _reloadCurrentShops();
  }

  _ShopListState _stateFor(String stationId) {
    return _shopStates[stationId] ??
        const _ShopListState(isInitialLoading: true);
  }

  Future<void> _showOptionSheet({
    required String title,
    required List<HomeCategory> options,
    required String selectedId,
    required ValueChanged<HomeCategory> onSelected,
  }) async {
    if (options.isEmpty) return;
    final selected = await showModalBottomSheet<HomeCategory>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final active = option.categoryId == selectedId;
                    return ListTile(
                      title: Text(option.categoryName),
                      trailing: active
                          ? const CircleAvatar(
                              radius: 10,
                              backgroundColor: AppTheme.brand,
                              child: Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              ),
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(option),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                _Header(
                  stations: _stations,
                  currentStation: _currentStation,
                  onSearchTap: () => context.push('/search'),
                  onStationTap: _selectStation,
                ),
                _FilterBar(
                  sortTitle: _sortTitle,
                  typeTitle: _typeTitle,
                  onSortTap: () => _showOptionSheet(
                    title: '综合排序',
                    options: _sorts,
                    selectedId: _sortCondition,
                    onSelected: (item) {
                      setState(() {
                        _sortCondition = item.categoryId;
                        _sortTitle = item.categoryName;
                      });
                      _reloadCurrentFilterResult();
                    },
                  ),
                  onTypeTap: () => _showOptionSheet(
                    title: '全部美食',
                    options: _categories,
                    selectedId: _typeCondition,
                    onSelected: (item) {
                      setState(() {
                        _typeCondition = item.categoryId == '0'
                            ? ''
                            : item.categoryId;
                        _typeTitle = item.categoryName;
                      });
                      _reloadCurrentFilterResult();
                    },
                  ),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
            if (_isBootstrapping) const _LoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_bootstrapError != null && _stations.isEmpty && !_isBootstrapping) {
      return _ErrorView(message: _bootstrapError!, onRetry: _bootstrap);
    }
    if (_stations.isEmpty) {
      return RefreshIndicator(onRefresh: _bootstrap, child: const EmptyState());
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _stations.length,
      onPageChanged: _handleStationPageChanged,
      itemBuilder: (context, index) {
        final stationId = _stations[index].stationId;
        return _StationShopPage(
          state: _stateFor(stationId),
          onRefresh: () => _reloadShops(stationIndex: index),
          onLoadMore: () => _loadMoreForStation(index),
          onRetry: () => _reloadShops(stationIndex: index),
          onShopTap: (shop) => context.push('/shop/${shop.shopId}'),
        );
      },
    );
  }
}

class _ShopListState {
  const _ShopListState({
    this.shops = const [],
    this.pageNo = 1,
    this.total = 0,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<ShopSummary> shops;
  final int pageNo;
  final int total;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final String? error;

  bool get hasMore => shops.length < total;

  _ShopListState copyWith({
    List<ShopSummary>? shops,
    int? pageNo,
    int? total,
    bool? isInitialLoading,
    bool? isLoadingMore,
    Object? error = _copySentinel,
  }) {
    return _ShopListState(
      shops: shops ?? this.shops,
      pageNo: pageNo ?? this.pageNo,
      total: total ?? this.total,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error == _copySentinel ? this.error : error as String?,
    );
  }
}

const _copySentinel = Object();

class _StationShopPage extends StatelessWidget {
  const _StationShopPage({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetry,
    required this.onShopTap,
  });

  final _ShopListState state;
  final RefreshCallback onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final ValueChanged<ShopSummary> onShopTap;

  @override
  Widget build(BuildContext context) {
    if (state.error != null && state.shops.isEmpty && !state.isInitialLoading) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }

    if (state.isInitialLoading && state.shops.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 70,
          height: 65,
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Image(image: AssetImage('assets/static/data.gif')),
          ),
        ),
      );
    }

    if (state.shops.isEmpty) {
      return RefreshIndicator(onRefresh: onRefresh, child: const EmptyState());
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
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: state.shops.length + 1,
          separatorBuilder: (_, index) => index >= state.shops.length - 1
              ? const SizedBox.shrink()
              : const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == state.shops.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    state.hasMore
                        ? (state.isLoadingMore ? '努力加载中' : '轻轻上拉')
                        : '已经到底部啦～',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              );
            }
            final shop = state.shops[index];
            return ShopSummaryCard(shop: shop, onTap: () => onShopTap(shop));
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
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
          colors: [Color(0x1AFE4D00), Colors.white],
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
                        borderRadius: BorderRadius.circular(18),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.sortTitle,
    required this.typeTitle,
    required this.onSortTap,
    required this.onTypeTap,
  });

  final String sortTitle;
  final String typeTitle;
  final VoidCallback onSortTap;
  final VoidCallback onTypeTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _FilterButton(title: sortTitle, onTap: onSortTap),
          ),
          Container(width: 1, height: 16, color: const Color(0xFFF0F0F0)),
          Expanded(
            child: _FilterButton(title: typeTitle, onTap: onTypeTap),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      iconAlignment: IconAlignment.end,
      label: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
      ),
      icon: const Icon(
        Icons.arrow_drop_down,
        size: 18,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

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
          child: Image.asset('assets/static/data.gif'),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
