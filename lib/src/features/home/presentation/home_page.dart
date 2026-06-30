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
  final _scrollController = ScrollController();

  List<Station> _stations = const [];
  List<HomeCategory> _categories = const [];
  List<HomeCategory> _sorts = const [];
  List<ShopSummary> _shops = const [];

  var _currentStation = 0;
  var _pageNo = 1;
  var _total = 0;
  var _isInitialLoading = true;
  var _isLoadingMore = false;
  String? _error;
  String _sortCondition = '';
  String _typeCondition = '';
  String _sortTitle = '综合排序';
  String _typeTitle = '全部美食';

  bool get _hasMore => _shops.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isInitialLoading = true;
      _error = null;
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
      });

      if (stations.isNotEmpty) {
        await _reloadShops();
      } else if (mounted) {
        setState(() {
          _shops = const [];
          _total = 0;
          _isInitialLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isInitialLoading = false;
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

  Future<void> _reloadShops() async {
    if (_stations.isEmpty) return;
    setState(() {
      _pageNo = 1;
      _shops = const [];
      _total = 0;
      _isInitialLoading = true;
      _error = null;
    });
    await _loadShops(pageNo: 1, replace: true);
  }

  Future<void> _loadShops({required int pageNo, required bool replace}) async {
    try {
      final result = await ref
          .read(homeRepositoryProvider)
          .getShopList(
            pageNo: pageNo,
            stationId: _stations[_currentStation].stationId,
            sortCondition: _sortCondition,
            typeCondition: _typeCondition,
          );
      if (!mounted) return;
      setState(() {
        _pageNo = pageNo;
        _shops = replace ? result.list : [..._shops, ...result.list];
        _total = result.total;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      setState(() => _isLoadingMore = true);
      _loadShops(pageNo: _pageNo + 1, replace: false);
    }
  }

  Future<void> _selectStation(int index) async {
    if (index == _currentStation) return;
    setState(() => _currentStation = index);
    await _reloadShops();
  }

  Future<void> _handleHorizontalDrag(DragEndDetails details) async {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 450 || _stations.isEmpty) return;
    if (velocity < 0 && _currentStation < _stations.length - 1) {
      await _selectStation(_currentStation + 1);
    } else if (velocity > 0 && _currentStation > 0) {
      await _selectStation(_currentStation - 1);
    }
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

  void _showShopDetailPending() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('店铺详情页待迁移')));
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
                      _reloadShops();
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
                      _reloadShops();
                    },
                  ),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
            if (_isInitialLoading) const _LoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _shops.isEmpty && !_isInitialLoading) {
      return _ErrorView(message: _error!, onRetry: _bootstrap);
    }
    if (_shops.isEmpty && !_isInitialLoading) {
      return RefreshIndicator(
        onRefresh: _reloadShops,
        child: const EmptyState(),
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: _handleHorizontalDrag,
      child: RefreshIndicator(
        onRefresh: _reloadShops,
        child: ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _shops.length + 1,
          separatorBuilder: (_, index) => index >= _shops.length - 1
              ? const SizedBox.shrink()
              : const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == _shops.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    _hasMore ? (_isLoadingMore ? '努力加载中' : '轻轻上拉') : '已经到底部啦～',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              );
            }
            return ShopSummaryCard(
              shop: _shops[index],
              onTap: _showShopDetailPending,
            );
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
