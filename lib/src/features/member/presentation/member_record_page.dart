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
import '../../../shared/widgets/cached_image.dart';
import '../../home/data/home_models.dart';

class MemberRecordPage extends ConsumerStatefulWidget {
  const MemberRecordPage({required this.params, this.extraShops, super.key});

  final Map<String, String> params;
  final Object? extraShops;

  @override
  ConsumerState<MemberRecordPage> createState() => _MemberRecordPageState();
}

class _MemberRecordPageState extends ConsumerState<MemberRecordPage> {
  static const _pageSize = 10;

  final _items = <MemberOrderRecord>[];
  int _pageNo = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _isManager = false;
  String _title = '';
  String _selectedShopId = '';
  final _shops = <_RecordShopOption>[];

  String get _memberId => widget.params['memberId'] ?? '';

  String get _shopId => widget.params['shopId'] ?? '';

  String get _shopName => widget.params['shopName'] ?? '';

  String get _pageTitle => widget.params['title'] ?? '';

  bool get _allowRefund => widget.params['allowRefund'] == '1';

  @override
  void initState() {
    super.initState();
    _selectedShopId = _shopId;
    _shops.addAll(_initialShops());
    _loadUser();
    _load(reset: true);
  }

  List<_RecordShopOption> _initialShops() {
    final extraShops = _parseShopList(widget.extraShops);
    if (extraShops.isNotEmpty) return extraShops;
    final raw = widget.params['shops'];
    if (raw == null || raw.isEmpty) return const [];
    try {
      return _parseShopList(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  List<_RecordShopOption> _parseShopList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => _RecordShopOption.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.shopId.isNotEmpty)
        .toList();
  }

  Future<void> _loadUser() async {
    final raw = await ref.read(appStorageProvider).getUserDetail();
    var isManager = false;
    var localShopName = '';
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw);
        if (json is Map) {
          isManager = json['isManager'] == true || json['isManager'] == 1;
          localShopName = json['shopName']?.toString() ?? '';
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _isManager = isManager;
      _title = _pageTitle.isNotEmpty
          ? _pageTitle
          : isManager
          ? (_shopName.isNotEmpty ? _shopName : localShopName)
          : _shopName;
    });
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
      final data = <String, dynamic>{
        'pageNo': _pageNo,
        'pageSize': _pageSize,
        'memberId': _memberId,
      };
      if (_selectedShopId.isNotEmpty) data['shopId'] = _selectedShopId;
      final raw = await ref
          .read(apiClientProvider)
          .post(TuanTuanEndpoints.memberOrderList, data: data);
      final envelope = ApiEnvelope.parse<PagedResult<MemberOrderRecord>>(
        raw,
        (data) => PagedResult.parse(data, MemberOrderRecord.fromJson),
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

  Future<void> _selectShopFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) =>
          _ShopFilterSheet(shops: _shops, selectedShopId: _selectedShopId),
    );
    if (selected == null || !mounted || selected == _selectedShopId) return;
    setState(() => _selectedShopId = selected);
    await _load(reset: true);
  }

  Future<void> _refund(MemberOrderRecord item) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认退款', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '确定要对这笔消费进行退款吗？退款成功后，金额将退回会员卡余额。',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _RefundConfirmLine(
              label: '退款金额',
              value: item.money.isEmpty ? '0' : item.money,
            ),
            if (item.shopDisplayName.isNotEmpty)
              _RefundConfirmLine(label: '店铺', value: item.shopDisplayName),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.brand,
              side: const BorderSide(color: AppTheme.brand),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brand,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.refundOrder,
            data: {'memberOrderId': item.memberOrderId},
          );
      final envelope = ApiEnvelope.parse<Map<String, dynamic>>(
        raw,
        (data) => data is Map ? Map<String, dynamic>.from(data) : {},
      );
      final refundStatus = _asInt(envelope.data?['refundStatus']);
      if (envelope.isSuccess && refundStatus == 1) {
        _toast('退款成功');
        await _load(reset: true);
      } else if (envelope.isSuccess && refundStatus == 2) {
        _toast('退款申请已提交，等待审批');
        await _load(reset: true);
      } else {
        _toast('退款失败，${envelope.message ?? ''}');
      }
    } catch (_) {
      _toast('退款失败');
    }
  }

  void _toast(String message) {
    AppToast.show(context, message);
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
          _title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                children: [
                  if (_shops.isNotEmpty)
                    _ShopFilterBar(
                      shop: _selectedFilterShop,
                      onTap: _selectShopFilter,
                    ),
                  if (_items.isEmpty && !_loading)
                    const _RecordEmpty()
                  else ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var index = 0; index < _items.length; index++)
                            _RecordCard(
                              key: ValueKey(_items[index].identityKey),
                              item: _items[index],
                              showDivider: index != _items.length - 1,
                              canRefund:
                                  _allowRefund &&
                                  _isManager &&
                                  _items[index].canRequestRefund,
                              onRefund: () => _refund(_items[index]),
                            ),
                        ],
                      ),
                    ),
                    _RecordLoadMore(
                      loadingMore: _loadingMore,
                      noMore: _items.length >= _total,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_loading) const _RecordLoading(),
        ],
      ),
    );
  }

  _RecordShopOption get _selectedFilterShop {
    if (_selectedShopId.isEmpty) return _RecordShopOption.all;
    return _shops.firstWhere(
      (shop) => shop.shopId == _selectedShopId,
      orElse: () => _RecordShopOption.all,
    );
  }
}

class _RecordCard extends StatefulWidget {
  const _RecordCard({
    super.key,
    required this.item,
    required this.showDivider,
    required this.canRefund,
    required this.onRefund,
  });

  final MemberOrderRecord item;
  final bool showDivider;
  final bool canRefund;
  final VoidCallback onRefund;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _ShopFilterBar extends StatelessWidget {
  const _ShopFilterBar({required this.shop, required this.onTap});

  final _RecordShopOption shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 58,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _ShopAvatar(shop: shop, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                shop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFF6F6F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF555555),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopFilterSheet extends StatelessWidget {
  const _ShopFilterSheet({required this.shops, required this.selectedShopId});

  final List<_RecordShopOption> shops;
  final String selectedShopId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E2E2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择店铺',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _ShopFilterItem(
                      shop: _RecordShopOption.all,
                      selected: selectedShopId.isEmpty,
                      showDivider: shops.isNotEmpty,
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                    for (var index = 0; index < shops.length; index++)
                      _ShopFilterItem(
                        shop: shops[index],
                        selected: selectedShopId == shops[index].shopId,
                        showDivider: index != shops.length - 1,
                        onTap: () =>
                            Navigator.of(context).pop(shops[index].shopId),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopFilterItem extends StatelessWidget {
  const _ShopFilterItem({
    required this.shop,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final _RecordShopOption shop;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          children: [
            SizedBox(
              height: 62,
              child: Row(
                children: [
                  _ShopAvatar(shop: shop, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.brand : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppTheme.brand
                            : const Color(0xFFD8D8D8),
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 19)
                        : null,
                  ),
                ],
              ),
            ),
            if (showDivider)
              const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
          ],
        ),
      ),
    );
  }
}

class _RefundConfirmLine extends StatelessWidget {
  const _RefundConfirmLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label：',
            style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopAvatar extends StatelessWidget {
  const _ShopAvatar({required this.shop, required this.size});

  final _RecordShopOption shop;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Image.asset(AppAssets.logo, fit: BoxFit.cover);
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: shop.imageUrl.isEmpty
            ? placeholder
            : AppCachedNetworkImage(
                imageUrl: shop.imageUrl,
                fit: BoxFit.cover,
                errorWidget: placeholder,
              ),
      ),
    );
  }
}

class _RecordCardState extends State<_RecordCard> {
  static const _revealWidth = 78.0;
  double _offset = 0;

  @override
  void didUpdateWidget(covariant _RecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedRecord = oldWidget.item.identityKey != widget.item.identityKey;
    final disabledRefund = oldWidget.canRefund && !widget.canRefund;
    if ((changedRecord || disabledRefund) && _offset != 0) {
      _offset = 0;
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.canRefund) return;
    setState(() {
      _offset = (_offset - details.delta.dx).clamp(0, _revealWidth);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.canRefund) return;
    setState(() {
      _offset = _offset > _revealWidth / 2 ? _revealWidth : 0;
    });
  }

  void _handleRefundTap() {
    if (_offset != 0) setState(() => _offset = 0);
    widget.onRefund();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: ClipRect(
        child: Stack(
          children: [
            if (widget.canRefund)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _handleRefundTap,
                    child: Container(
                      width: _revealWidth,
                      color: const Color(0xFFEE1616),
                      alignment: Alignment.center,
                      child: const Text(
                        '退款',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(-_offset, 0, 0),
              child: _RecordCardContent(
                item: widget.item,
                showDivider: widget.showDivider,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordCardContent extends StatelessWidget {
  const _RecordCardContent({required this.item, required this.showDivider});

  final MemberOrderRecord item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: Color(0xFFF2F2F2)))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.badgeColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                item.badgeText,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                item.statusText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (item.tipText.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: SizedBox(
                                  height: 20,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      if (item.paymentIcon.isNotEmpty)
                                        Image.asset(
                                          item.paymentIcon,
                                          width: 16,
                                          height: 16,
                                          fit: BoxFit.contain,
                                        ),
                                      if (item.paymentIcon.isNotEmpty)
                                        const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          item.tipText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          strutStyle: const StrutStyle(
                                            fontSize: 12,
                                            height: 1,
                                            forceStrutHeight: true,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1,
                                            color:
                                                item.tipText == '已全额退款' ||
                                                    item.tipText == '退款审批中'
                                                ? Colors.red
                                                : const Color(0xFFC1C1C1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        item.moneyText,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: item.isConsumptionLike
                              ? AppTheme.textPrimary
                              : AppTheme.brand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.memberOrderDatetime.isEmpty
                            ? '--'
                            : item.memberOrderDatetime,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '卡内余额 ${item.balance}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (item.operator.isNotEmpty)
                    _DetailLine(label: '操作员', value: item.operator),
                  if (item.shopDisplayName.isNotEmpty)
                    _DetailLine(label: '店铺', value: item.shopDisplayName),
                  if (!item.isConsumptionLike && item.displayRemark.isNotEmpty)
                    _DetailLine(label: '备注', value: item.displayRemark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordEmpty extends StatelessWidget {
  const _RecordEmpty();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.45,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
    );
  }
}

class _RecordLoadMore extends StatelessWidget {
  const _RecordLoadMore({required this.loadingMore, required this.noMore});

  final bool loadingMore;
  final bool noMore;

  @override
  Widget build(BuildContext context) {
    final text = loadingMore
        ? '努力加载中'
        : noMore
        ? '当前已无其它内容了～'
        : '轻轻上拉';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (noMore) ...[
            Container(width: 48, height: 1, color: const Color(0xFFE0E0E0)),
            const SizedBox(width: 14),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 15),
          ),
          if (noMore) ...[
            const SizedBox(width: 14),
            Container(width: 48, height: 1, color: const Color(0xFFE0E0E0)),
          ],
        ],
      ),
    );
  }
}

class _RecordLoading extends StatelessWidget {
  const _RecordLoading();

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

class _RecordShopOption {
  const _RecordShopOption({
    required this.shopId,
    required this.name,
    required this.imageUrl,
  });

  static const all = _RecordShopOption(shopId: '', name: '全部店铺', imageUrl: '');

  final String shopId;
  final String name;
  final String imageUrl;

  factory _RecordShopOption.fromJson(Map<String, dynamic> json) {
    return _RecordShopOption(
      shopId: json['shopId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }
}

class MemberOrderRecord {
  const MemberOrderRecord({
    required this.memberOrderId,
    required this.memberOrderFlg,
    required this.paymentWay,
    required this.onlineFlag,
    required this.userMobile,
    required this.useStatus,
    required this.refundStatus,
    required this.money,
    required this.memberOrderDatetime,
    required this.balance,
    required this.operator,
    required this.chargeShopName,
    required this.useShopName,
    required this.refundShopName,
    required this.remark,
  });

  final String memberOrderId;
  final String memberOrderFlg;
  final int paymentWay;
  final int onlineFlag;
  final String userMobile;
  final int useStatus;
  final int refundStatus;
  final String money;
  final String memberOrderDatetime;
  final String balance;
  final String operator;
  final String chargeShopName;
  final String useShopName;
  final String refundShopName;
  final String remark;

  String get displayRemark => _cleanRemarkForDisplay(remark);

  String get identityKey {
    if (memberOrderId.isNotEmpty) return '$memberOrderId-$useStatus';
    return '$useStatus-$memberOrderDatetime-$money-$balance';
  }

  bool get isRecharge => useStatus == 1;

  bool get isConsumption => useStatus == 2;

  bool get isRefund => useStatus == 3;

  bool get isApprovalPending => useStatus == 4;

  bool get isRefundedConsumption => useStatus == 5;

  bool get isRefundApprovalConsumption => useStatus == 6;

  bool get isConsumptionLike =>
      isConsumption ||
      isRefundedConsumption ||
      isRefundApprovalConsumption ||
      (useStatus == 0 && memberOrderFlg == '消费');

  String get statusText {
    return switch (useStatus) {
      1 => '充值',
      2 => '消费',
      3 => '退款',
      4 => '审批中',
      5 => '消费',
      6 => '消费',
      _ => memberOrderFlg,
    };
  }

  String get badgeText {
    if (isConsumptionLike) return '消';
    if (isRecharge) return '充';
    if (isRefund) return '退';
    if (isApprovalPending) return '审';
    return '';
  }

  Color get badgeColor {
    if (isConsumptionLike) return const Color(0xFFCCCCCC);
    if (isRecharge) return AppTheme.brand;
    if (isRefund) return const Color(0xFF126CFF);
    if (isApprovalPending) return const Color(0xFFFF4D00);
    return Colors.black;
  }

  bool get canRequestRefund =>
      isConsumption && refundStatus != 1 && refundStatus != 2;

  String get moneyText => isConsumptionLike
      ? '-${money.isEmpty ? 0 : money}'
      : '+${money.isEmpty ? 0 : money}';

  String get tipText {
    if (isRecharge) {
      final name = _paymentName(paymentWay);
      final online = paymentWay == 24
          ? onlineFlag == 1
                ? ' 线上充值'
                : ' 线下充值'
          : '';
      return '$name$online';
    }
    if (isRefund) {
      return '操作人：${userMobile.isEmpty ? '后台' : userMobile}';
    }
    if (isRefundedConsumption) return '已全额退款';
    if (isRefundApprovalConsumption) return '退款审批中';
    return '';
  }

  String get paymentIcon =>
      isRecharge || isRefund ? _paymentIcon(paymentWay) : '';

  String get shopDisplayName => chargeShopName.isNotEmpty
      ? chargeShopName
      : useShopName.isNotEmpty
      ? useShopName
      : refundShopName;

  factory MemberOrderRecord.fromJson(Map<String, dynamic> json) {
    return MemberOrderRecord(
      memberOrderId: json['memberOrderId']?.toString() ?? '',
      memberOrderFlg: json['memberOrderFlg']?.toString() ?? '',
      paymentWay: int.tryParse(json['paymentWay']?.toString() ?? '') ?? 0,
      onlineFlag: int.tryParse(json['onlineFlag']?.toString() ?? '') ?? 0,
      userMobile: json['userMobile']?.toString() ?? '',
      useStatus:
          _asInt(json['useStatus']) ?? _statusFromFlag(json['memberOrderFlg']),
      refundStatus: _asInt(json['refundStatus']) ?? 0,
      money: json['money']?.toString() ?? '0',
      memberOrderDatetime: json['memberOrderDatetime']?.toString() ?? '',
      balance: json['balance']?.toString() ?? '0',
      operator: json['operator']?.toString() ?? '',
      chargeShopName: json['chargeShopName']?.toString() ?? '',
      useShopName: json['useShopName']?.toString() ?? '',
      refundShopName: json['refundShopName']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
    );
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final raw = value.toString().trim();
  return int.tryParse(raw) ?? double.tryParse(raw)?.toInt();
}

String _cleanRemarkForDisplay(String value) {
  final text = value.trim();
  final hasCjk = RegExp(r'[\u3400-\u9FFF\u3040-\u30FF]').hasMatch(text);
  if (!hasCjk) return text;
  return text
      .replaceAllMapped(
        RegExp(r'\?([^?]+?)\?'),
        (match) => '【${match.group(1)?.trim() ?? ''}】',
      )
      .trim();
}

int _statusFromFlag(dynamic value) {
  return switch (value?.toString().trim()) {
    '充值' => 1,
    '消费' => 2,
    '退款' => 3,
    '审批中' => 4,
    _ => 0,
  };
}

String _paymentName(int id) {
  return switch (id) {
    23 => '现金',
    24 => '微信',
    25 => '支付宝',
    26 => 'paypay',
    27 => '信用卡',
    28 => '其他',
    _ => '',
  };
}

String _paymentIcon(int id) {
  return switch (id) {
    23 => 'assets/static/image/xj.png',
    24 => 'assets/static/image/wxpay.png',
    25 => 'assets/static/image/zfb.png',
    26 => 'assets/static/image/paypay.png',
    27 => 'assets/static/image/pos.png',
    28 => 'assets/static/image/qt.png',
    _ => '',
  };
}
