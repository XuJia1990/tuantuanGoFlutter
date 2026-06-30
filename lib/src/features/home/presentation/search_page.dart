import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../data/home_models.dart';
import '../data/home_repository.dart';
import 'shop_summary_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ShopSummary> _shops = [];

  var _pageNo = 1;
  var _total = 0;
  var _isLoading = false;
  var _isLoadingMore = false;
  var _hasSearched = false;
  String _keyword = '';

  bool get _hasMore => _shops.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      setState(() => _isLoadingMore = true);
      _load(pageNo: _pageNo + 1, replace: false);
    }
  }

  Future<void> _search() async {
    _keyword = _controller.text.trim();
    setState(() {
      _hasSearched = true;
      _pageNo = 1;
      _total = 0;
      _shops.clear();
    });
    await _load(pageNo: 1, replace: true);
  }

  Future<void> _load({required int pageNo, required bool replace}) async {
    setState(() {
      _isLoading = replace;
      _isLoadingMore = !replace;
    });
    try {
      final result = await ref
          .read(homeRepositoryProvider)
          .searchShops(pageNo: pageNo, keyword: _keyword);
      if (!mounted) return;
      setState(() {
        _pageNo = pageNo;
        if (replace) _shops.clear();
        _shops.addAll(result.list);
        _total = result.total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _showShopDetailPending() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('店铺详情页待迁移')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: Navigator.of(context).pop,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          hintText: '请输入商户名、地点或菜名',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          fillColor: AppTheme.pageBg,
                          prefixIcon: const Icon(Icons.search, size: 20),
                        ),
                      ),
                    ),
                    TextButton(onPressed: _search, child: const Text('搜索')),
                  ],
                ),
              ),
              Expanded(child: _buildResults()),
            ],
          ),
          if (_isLoading) const _SearchLoading(),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_shops.isEmpty && _hasSearched && !_isLoading) {
      return const EmptyState(search: true);
    }
    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _shops.length + (_shops.isEmpty ? 0 : 1),
        separatorBuilder: (_, index) => index >= _shops.length - 1
            ? const SizedBox.shrink()
            : const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _shops.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _hasMore
                      ? (_isLoadingMore ? '努力加载中' : '轻轻上拉')
                      : '当前搜索内容已无其它结果了～',
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
    );
  }
}

class _SearchLoading extends StatelessWidget {
  const _SearchLoading();

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
