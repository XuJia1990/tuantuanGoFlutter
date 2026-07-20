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

class MemberRecordPage extends ConsumerStatefulWidget {
  const MemberRecordPage({required this.params, super.key});

  final Map<String, String> params;

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

  String get _memberId => widget.params['memberId'] ?? '';
  String get _shopId => widget.params['shopId'] ?? '';
  String get _shopName => widget.params['shopName'] ?? '';
  bool get _allowRefund => widget.params['allowRefund'] == '1';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _load(reset: true);
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
      _title = isManager
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
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.memberOrderList,
            data: {
              'pageNo': _pageNo,
              'pageSize': _pageSize,
              'memberId': _memberId,
              'shopId': _shopId,
            },
          );
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

  Future<void> _refund(MemberOrderRecord item) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('您确认退款吗?', textAlign: TextAlign.center),
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
            child: const Text('确认退款'),
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
        (data) => Map<String, dynamic>.from(data as Map),
      );
      if (envelope.isSuccess && envelope.data?['isSecces'] == true) {
        _toast('退款成功');
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
              child: _items.isEmpty && !_loading
                  ? const _RecordEmpty()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < _items.length;
                                index++
                              )
                                _RecordCard(
                                  item: _items[index],
                                  showDivider: index != _items.length - 1,
                                  canRefund:
                                      _allowRefund &&
                                      _isManager &&
                                      _items[index].memberOrderFlg == '消费' &&
                                      _items[index].useStatus == 1,
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
                    ),
            ),
          ),
          if (_loading) const _RecordLoading(),
        ],
      ),
    );
  }
}

class _RecordCard extends StatefulWidget {
  const _RecordCard({
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

class _RecordCardState extends State<_RecordCard> {
  static const _revealWidth = 78.0;
  double _offset = 0;

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
                    onTap: widget.onRefund,
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
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                item.memberOrderFlg,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (item.tipText.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item.paymentIcon.isNotEmpty)
                                      Image.asset(
                                        item.paymentIcon,
                                        width: 16,
                                        height: 16,
                                      ),
                                    if (item.paymentIcon.isNotEmpty)
                                      const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        item.tipText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: item.tipText == '已全额退款'
                                              ? Colors.red
                                              : const Color(0xFFC1C1C1),
                                        ),
                                      ),
                                    ),
                                  ],
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
                          color: item.memberOrderFlg == '消费'
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
                  if (item.memberOrderFlg != '消费' && item.remark.isNotEmpty)
                    _DetailLine(label: '备注', value: item.remark),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
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

class MemberOrderRecord {
  const MemberOrderRecord({
    required this.memberOrderId,
    required this.memberOrderFlg,
    required this.paymentWay,
    required this.onlineFlag,
    required this.userMobile,
    required this.useStatus,
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
  final String money;
  final String memberOrderDatetime;
  final String balance;
  final String operator;
  final String chargeShopName;
  final String useShopName;
  final String refundShopName;
  final String remark;

  String get badgeText {
    if (memberOrderFlg == '消费') return '消';
    if (memberOrderFlg == '充值') return '充';
    if (memberOrderFlg == '退款') return '退';
    return '';
  }

  Color get badgeColor {
    if (memberOrderFlg == '消费') return const Color(0xFFCCCCCC);
    if (memberOrderFlg == '充值') return AppTheme.brand;
    if (memberOrderFlg == '退款') return const Color(0xFF126CFF);
    return Colors.black;
  }

  String get moneyText => memberOrderFlg == '消费'
      ? '-${money.isEmpty ? 0 : money}'
      : '+${money.isEmpty ? 0 : money}';

  String get tipText {
    if (memberOrderFlg == '充值') {
      final name = _paymentName(paymentWay);
      final online = paymentWay == 24
          ? onlineFlag == 1
                ? ' 线上充值'
                : ' 线下充值'
          : '';
      return '$name$online';
    }
    if (memberOrderFlg == '退款') {
      return '操作人:${userMobile.isEmpty ? '--' : userMobile}';
    }
    if (memberOrderFlg == '消费' && useStatus == 2) return '已全额退款';
    return '';
  }

  String get paymentIcon => memberOrderFlg == '充值' || memberOrderFlg == '退款'
      ? _paymentIcon(paymentWay)
      : '';

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
      useStatus: int.tryParse(json['useStatus']?.toString() ?? '') ?? 0,
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
