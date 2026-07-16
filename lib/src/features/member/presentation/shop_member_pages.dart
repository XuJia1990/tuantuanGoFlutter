import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import '../../../core/storage/app_storage.dart';
import '../../home/data/home_models.dart';

class CreateMemberPage extends ConsumerStatefulWidget {
  const CreateMemberPage({required this.params, super.key});

  final Map<String, String> params;

  @override
  ConsumerState<CreateMemberPage> createState() => _CreateMemberPageState();
}

class _CreateMemberPageState extends ConsumerState<CreateMemberPage> {
  final _amountController = TextEditingController();
  final _confirmController = TextEditingController();
  Timer? _debounce;
  _LocalUser _user = const _LocalUser.empty();
  int _points = 0;

  String get _from => widget.params['from'] ?? '';
  String get _mobile => widget.params['mobile'] ?? _user.mobile;
  String get _scannedUserId => widget.params['userId'] ?? '';
  String get _scannedShopId => widget.params['shopId'] ?? '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await _LocalUser.load(ref.read(appStorageProvider));
    if (mounted) setState(() => _user = user);
  }

  void _onAmountChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (value.isEmpty) {
        if (mounted) setState(() => _points = 0);
        return;
      }
      try {
        final raw = await ref
            .read(apiClientProvider)
            .get(TuanTuanEndpoints.pointRate, query: {'chargeMoney': value});
        final envelope = ApiEnvelope.parse<int>(raw, (data) {
          if (data is Map) return _asInt(data['get_points']) ?? 0;
          return 0;
        });
        if (mounted && envelope.isSuccess) {
          setState(() => _points = envelope.data ?? 0);
        }
      } catch (_) {}
    });
  }

  Future<void> _submit() async {
    final amount = num.tryParse(_amountController.text);
    if (_mobile.isEmpty) {
      _toast('用户账号不能为空');
      return;
    }
    if (_amountController.text.isEmpty) {
      _toast('充值金额不能为空');
      return;
    }
    if (_confirmController.text.isEmpty) {
      _toast('请再次输入充值金额');
      return;
    }
    if (_amountController.text != _confirmController.text) {
      _toast('两次金额不一致，请检查输入金额');
      return;
    }
    if (!_user.isGroupManager && (amount == null || amount < 100)) {
      _toast('充值金额不能小于100');
      return;
    }
    final params = <String, String>{
      'type': '2',
      'number': _amountController.text,
      'isShopCharge': _from == 'shop' ? '1' : '0',
      'shopId': _from == 'shop'
          ? (_scannedShopId.isNotEmpty ? _scannedShopId : _user.shopId)
          : _scannedShopId,
    };
    if (_from == 'shop') params['userId'] = _scannedUserId;
    if (!mounted) return;
    context.push(
      Uri(path: '/member-recharge', queryParameters: params).toString(),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.pageBg,
        appBar: _SimpleAppBar(title: '创建会员', onBack: () => context.pop()),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                '* 最低充值100日元即可成为会员',
                style: TextStyle(color: Color(0xFFBABABA), fontSize: 14),
              ),
            ),
            _WhiteCard(
              children: [_InfoLine(title: '用户账号', trailing: Text(_mobile))],
            ),
            _WhiteCard(
              children: [
                _InputLine(
                  title: '充值金额',
                  hint: '请输入充值金额',
                  controller: _amountController,
                  onChanged: _onAmountChanged,
                ),
                const Divider(height: 1, color: Color(0xFFF7F7F7)),
                _InputLine(
                  title: '确认充值金额',
                  hint: '请再次输入充值金额',
                  controller: _confirmController,
                ),
              ],
            ),
            _WhiteCard(
              children: [_InfoLine(title: '赠送积分', trailing: Text('$_points'))],
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: _GradientButton(text: '立即创建', onTap: _submit),
          ),
        ),
      ),
    );
  }
}

class ShopMemberDetailListPage extends ConsumerStatefulWidget {
  const ShopMemberDetailListPage({required this.params, super.key});

  final Map<String, String> params;

  @override
  ConsumerState<ShopMemberDetailListPage> createState() =>
      _ShopMemberDetailListPageState();
}

class _ShopMemberDetailListPageState
    extends ConsumerState<ShopMemberDetailListPage> {
  static const _pageSize = 10;

  final _searchController = TextEditingController();
  final _items = <ShopMemberItem>[];
  _LocalUser _user = const _LocalUser.empty();
  int _pageNo = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;

  String get _shopId => widget.params['shopId']?.isNotEmpty == true
      ? widget.params['shopId']!
      : _user.shopId;
  String get _shopName => widget.params['shopName']?.isNotEmpty == true
      ? widget.params['shopName']!
      : _user.shopName;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await _LocalUser.load(ref.read(appStorageProvider));
    if (mounted) setState(() => _user = user);
    await _load(reset: true);
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
        'keyWords': _searchController.text.trim(),
      };
      if (_shopId.isNotEmpty) data['shopId'] = _shopId;
      final raw = await ref
          .read(apiClientProvider)
          .post(TuanTuanEndpoints.shopMemberList, data: data);
      final envelope = ApiEnvelope.parse<PagedResult<ShopMemberItem>>(
        raw,
        (data) => PagedResult.parse(data, ShopMemberItem.fromJson),
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
      setState(() {
        if (reset) _items.clear();
        _items.addAll(envelope.data!.list);
        _total = envelope.data!.total;
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

  void _scanCreateMember() {
    context.push(
      Uri(
        path: '/scan-code',
        queryParameters: {
          'mode': 'shop',
          'shopId': _shopId,
          'shopName': _shopName,
        },
      ).toString(),
    );
  }

  void _goRecharge(ShopMemberItem item) {
    context.push(
      Uri(
        path: '/member-recharge',
        queryParameters: {
          'type': '1',
          'isShopCharge': '1',
          'userId': item.userId,
          'shopId': _shopId,
        },
      ).toString(),
    );
  }

  void _goRecord(ShopMemberItem item) {
    context.push(
      Uri(
        path: '/member-record',
        queryParameters: {
          'memberId': item.memberId,
          'shopId': _shopId,
          'shopName': _shopName,
          'allowRefund': '1',
        },
      ).toString(),
    );
  }

  Future<void> _clearSearch() async {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
    FocusScope.of(context).unfocus();
    await _load(reset: true);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final title = _total > 0 ? '会员详情（$_total人）' : '会员详情';
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: _SimpleAppBar(title: title, onBack: () => context.pop()),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                height: 70,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 13),
                      const Icon(
                        Icons.search,
                        color: Color(0xFF9E9E9E),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          textAlignVertical: TextAlignVertical.center,
                          onSubmitted: (_) {
                            FocusScope.of(context).unfocus();
                            _load(reset: true);
                          },
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                          ),
                          cursorColor: AppTheme.brand,
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            fillColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                            hintText: '请输入会员账号',
                            hintStyle: TextStyle(
                              color: Color(0xFFCFCFCF),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _clearSearch,
                          child: const SizedBox(
                            width: 40,
                            height: 44,
                            child: Center(
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: Color(0xFFB8B8B8),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 14),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _maybeLoadMore(notification);
                    return false;
                  },
                  child: RefreshIndicator(
                    color: AppTheme.brand,
                    onRefresh: () => _load(reset: true),
                    child: _items.isEmpty && !_loading
                        ? _MemberListEmpty(onScan: _scanCreateMember)
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length + (_items.isEmpty ? 0 : 1),
                            itemBuilder: (context, index) {
                              if (index == _items.length) {
                                return _LoadMoreText(
                                  loadingMore: _loadingMore,
                                  noMore: _items.length >= _total,
                                );
                              }
                              final item = _items[index];
                              return _ShopMemberCard(
                                item: item,
                                onRecharge: () => _goRecharge(item),
                                onRecord: () => _goRecord(item),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (_loading) const _LoadingOverlay(),
        ],
      ),
    );
  }
}

class ShopMemberStaticPage extends ConsumerStatefulWidget {
  const ShopMemberStaticPage({required this.params, super.key});

  final Map<String, String> params;

  @override
  ConsumerState<ShopMemberStaticPage> createState() =>
      _ShopMemberStaticPageState();
}

class _ShopMemberStaticPageState extends ConsumerState<ShopMemberStaticPage> {
  static const _pageSize = 9;

  _LocalUser _user = const _LocalUser.empty();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  int _showFlag = 0;
  int _pageNo = 1;
  int _total = 0;
  int _trueList = 0;
  String _consumeMoney = '0.00';
  String _rechargeMoney = '0.00';
  int _orderCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  final _groups = <MemberHistoryGroup>[];

  String get _shopId => widget.params['shopId']?.isNotEmpty == true
      ? widget.params['shopId']!
      : _user.shopId;
  String get _shopName => widget.params['shopName']?.isNotEmpty == true
      ? widget.params['shopName']!
      : _user.shopName;
  String get _typeLabel => switch (_showFlag) {
    1 => '消费',
    2 => '充值',
    _ => '全部',
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await _LocalUser.load(ref.read(appStorageProvider));
    if (mounted) setState(() => _user = user);
    await _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      _pageNo = 1;
      _total = 0;
      _trueList = 0;
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
            TuanTuanEndpoints.memberUsedHistory,
            data: {
              'pageNo': _pageNo,
              'pageSize': _pageSize,
              'startDate': _dateCompact(_startDate),
              'endDate': _dateCompact(_endDate),
              'shopId': _shopId,
              'showFlag': _showFlag,
            },
          );
      final envelope = ApiEnvelope.parse<_HistoryPage>(
        raw,
        _HistoryPage.fromRaw,
      );
      if (!mounted) return;
      if (!envelope.isSuccess || envelope.data == null) {
        _toast(envelope.message ?? '获取失败');
        setState(() {
          if (reset) _groups.clear();
          _loading = false;
          _loadingMore = false;
        });
        return;
      }
      final page = envelope.data!;
      setState(() {
        if (reset) _groups.clear();
        _groups.addAll(page.groups);
        _consumeMoney = page.consumeMoney;
        _rechargeMoney = page.rechargeMoney;
        _orderCount = page.orderCountFor(_showFlag);
        _total = page.total;
        _trueList = _groups.fold<int>(
          0,
          (sum, group) => sum + group.recordsFor(_showFlag).length,
        );
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      _toast('获取失败');
      setState(() {
        if (reset) _groups.clear();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _maybeLoadMore(ScrollNotification notification) {
    if (_loading || _loadingMore || _trueList >= _total) return;
    if (notification.metrics.extentAfter > 160) return;
    _pageNo += 1;
    _load(reset: false);
  }

  Future<void> _chooseDate() async {
    final result = await showModalBottomSheet<_DateRangeValue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) =>
          _DateRangePickerSheet(startDate: _startDate, endDate: _endDate),
    );
    if (result == null || !mounted) return;
    if (result.endDate.isBefore(result.startDate)) {
      _toast('结束日期不能早于开始日期');
      return;
    }
    setState(() {
      _startDate = result.startDate;
      _endDate = result.endDate;
    });
    await _load(reset: true);
  }

  Future<void> _chooseType() async {
    final value = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TypeSheetItem(
                label: '全部',
                active: _showFlag == 0,
                onTap: () => context.pop(0),
              ),
              _TypeSheetItem(
                label: '消费',
                active: _showFlag == 1,
                onTap: () => context.pop(1),
              ),
              _TypeSheetItem(
                label: '充值',
                active: _showFlag == 2,
                onTap: () => context.pop(2),
              ),
              const SizedBox(height: 10),
              _TypeSheetItem(
                label: '取消',
                active: false,
                onTap: () => context.pop(),
              ),
            ],
          ),
        );
      },
    );
    if (value == null) return;
    setState(() => _showFlag = value);
    await _load(reset: true);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${_dateSlash(_startDate)}-${_dateSlash(_endDate)}';
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: _SimpleAppBar(title: _shopName, onBack: () => context.pop()),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.fromLTRB(12, 15, 12, 15),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brand.withValues(alpha: 0.35),
                      blurRadius: 7,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatisticChip(
                            icon: Icons.calendar_month,
                            text: dateLabel,
                            onTap: _chooseDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatisticChip(
                          text: _typeLabel,
                          icon: Icons.keyboard_arrow_down,
                          onTap: _chooseType,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    if (_showFlag == 0)
                      Row(
                        children: [
                          Expanded(
                            child: _TotalBlock(
                              label: '消费总额',
                              money: _consumeMoney,
                            ),
                          ),
                          Expanded(
                            child: _TotalBlock(
                              label: '充值总额',
                              money: _rechargeMoney,
                            ),
                          ),
                        ],
                      )
                    else
                      _TotalBlock(
                        label: _showFlag == 1 ? '消费总额' : '充值总额',
                        money: _showFlag == 1 ? _consumeMoney : _rechargeMoney,
                        count: '共计$_orderCount笔',
                        alignLeft: true,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _maybeLoadMore(notification);
                    return false;
                  },
                  child: RefreshIndicator(
                    color: AppTheme.brand,
                    onRefresh: () => _load(reset: true),
                    child: _groups.isEmpty && !_loading
                        ? const _SimpleEmpty()
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                            children: [
                              for (final group in _groups)
                                _HistoryGroupCard(
                                  group: group,
                                  showFlag: _showFlag,
                                ),
                              _LoadMoreText(
                                loadingMore: _loadingMore,
                                noMore: _trueList >= _total,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (_loading) const _LoadingOverlay(),
        ],
      ),
    );
  }
}

class MemberShopPayPage extends ConsumerStatefulWidget {
  const MemberShopPayPage({required this.params, super.key});

  final Map<String, String> params;

  @override
  ConsumerState<MemberShopPayPage> createState() => _MemberShopPayPageState();
}

class _MemberShopPayPageState extends ConsumerState<MemberShopPayPage> {
  final _amountController = TextEditingController();
  Timer? _debounce;
  _LocalUser _user = const _LocalUser.empty();
  _CheckoutInfo _info = const _CheckoutInfo.empty();
  bool _loading = true;
  bool _submitting = false;
  bool _resultVisible = false;
  bool _paySuccess = false;
  bool _payFail = false;

  String get _shopId => widget.params['shopId'] ?? _user.shopId;
  String get _payCode => widget.params['payCode'] ?? '';
  List<String> get _payParts => _payCode.split('_');
  String get _payUserId => _payParts.isNotEmpty ? _payParts.first : '';
  String get _timestamp => _payParts.length > 1 ? _payParts[1] : '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await _LocalUser.load(ref.read(appStorageProvider));
    if (mounted) setState(() => _user = user);
    await _loadCheckoutInfo();
  }

  Future<void> _loadCheckoutInfo() async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.scanUserPayCode,
            data: {'shopId': _shopId, 'payUserId': _payUserId},
          );
      final envelope = ApiEnvelope.parse<_CheckoutInfo>(
        raw,
        (data) =>
            _CheckoutInfo.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      if (!mounted) return;
      if (envelope.isSuccess && envelope.data != null) {
        setState(() {
          _info = envelope.data!;
          _loading = false;
        });
      } else {
        _toast(envelope.message ?? '获取失败');
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      _toast('获取失败');
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final amount = num.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _toast('请输入消费金额');
      return;
    }
    if (amount > _info.balance) {
      _showBalanceDialog();
      return;
    }
    setState(() {
      _submitting = true;
      _resultVisible = true;
      _paySuccess = false;
      _payFail = false;
    });
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.payByShopManager,
            data: {
              'payUserId': _payUserId,
              'timestamp': _timestamp,
              'payMoney': _amountController.text,
              'shopId': _shopId,
            },
          );
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _paySuccess = envelope.isSuccess;
        _payFail = !envelope.isSuccess;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _payFail = true;
      });
    }
  }

  void _showBalanceDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Image.asset('assets/static/image/kq.png', width: 40, height: 40),
            const SizedBox(height: 10),
            const Text('卡内余额不足', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text('哦豁，您的卡内余额不足，请前往充值', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.brand),
            child: const Text('再想想'),
          ),
          FilledButton(
            onPressed: () {
              context.pop();
              context.push(
                Uri(
                  path: '/member-recharge',
                  queryParameters: {
                    'type': '1',
                    'isShopCharge': '1',
                    'userId': _payUserId,
                    'shopId': _shopId,
                  },
                ).toString(),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.brand),
            child: const Text('去充值'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _CheckoutScaffold(
      title: _info.shopName,
      info: _info,
      account: _info.mobile.isNotEmpty ? _info.mobile : _user.mobile,
      amountController: _amountController,
      loading: _loading,
      resultVisible: _resultVisible,
      success: _paySuccess,
      fail: _payFail,
      onSubmit: _submit,
      onBack: () => context.pop(),
      onDone: () => context.go('/shop-manager'),
      onRetry: () {
        setState(() {
          _resultVisible = false;
          _payFail = false;
          _paySuccess = false;
        });
      },
      onRecharge: () => context.push(
        Uri(
          path: '/member-recharge',
          queryParameters: {
            'type': '1',
            'isShopCharge': '1',
            'userId': _payUserId,
            'shopId': _shopId,
          },
        ).toString(),
      ),
    );
  }
}

class MemberConsumptionPage extends ConsumerStatefulWidget {
  const MemberConsumptionPage({required this.params, super.key});

  final Map<String, String> params;

  @override
  ConsumerState<MemberConsumptionPage> createState() =>
      _MemberConsumptionPageState();
}

class _MemberConsumptionPageState extends ConsumerState<MemberConsumptionPage> {
  final _amountController = TextEditingController();
  _LocalUser _user = const _LocalUser.empty();
  _CheckoutInfo _info = const _CheckoutInfo.empty();
  bool _loading = true;
  bool _resultVisible = false;
  bool _paySuccess = false;
  bool _payFail = false;

  String get _shopId => widget.params['shopId'] ?? '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await _LocalUser.load(ref.read(appStorageProvider));
    if (mounted) setState(() => _user = user);
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get(TuanTuanEndpoints.checkoutInfo, query: {'shopId': _shopId});
      final envelope = ApiEnvelope.parse<_CheckoutInfo>(
        raw,
        (data) =>
            _CheckoutInfo.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      if (!mounted) return;
      if (envelope.isSuccess && envelope.data != null) {
        setState(() {
          _info = envelope.data!;
          _loading = false;
        });
      } else {
        _toast(envelope.message ?? '获取失败');
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      _toast('获取失败');
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final amount = num.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _toast('请输入消费金额');
      return;
    }
    if (amount > _info.balance) {
      _toast('卡内余额不足');
      return;
    }
    setState(() {
      _resultVisible = true;
      _paySuccess = false;
      _payFail = false;
    });
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.payOrder,
            data: {'shopId': _shopId, 'payMoney': _amountController.text},
          );
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!mounted) return;
      setState(() {
        _paySuccess = envelope.isSuccess;
        _payFail = !envelope.isSuccess;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _payFail = true);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _CheckoutScaffold(
      title: _info.shopName,
      info: _info,
      account: _user.mobile,
      amountController: _amountController,
      loading: _loading,
      resultVisible: _resultVisible,
      success: _paySuccess,
      fail: _payFail,
      onSubmit: _submit,
      onBack: () => context.pop(),
      onDone: () => context.go('/member'),
      onRetry: () {
        setState(() {
          _resultVisible = false;
          _payFail = false;
          _paySuccess = false;
        });
      },
      onRecharge: () => context.push(
        Uri(
          path: '/member-recharge',
          queryParameters: {
            'type': '1',
            'isShopCharge': '0',
            'shopId': _shopId,
          },
        ).toString(),
      ),
    );
  }
}

class _CheckoutScaffold extends StatelessWidget {
  const _CheckoutScaffold({
    required this.title,
    required this.info,
    required this.account,
    required this.amountController,
    required this.loading,
    required this.resultVisible,
    required this.success,
    required this.fail,
    required this.onSubmit,
    required this.onBack,
    required this.onDone,
    required this.onRetry,
    required this.onRecharge,
  });

  final String title;
  final _CheckoutInfo info;
  final String account;
  final TextEditingController amountController;
  final bool loading;
  final bool resultVisible;
  final bool success;
  final bool fail;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final VoidCallback onDone;
  final VoidCallback onRetry;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.brand,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
            ),
            SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: kToolbarHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 0,
                          child: IconButton(
                            onPressed: onBack,
                            icon: const Icon(
                              Icons.chevron_left,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                            children: [
                              Container(
                                height: 426,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  image: const DecorationImage(
                                    image: AssetImage(
                                      'assets/static/card_bg.png',
                                    ),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: 79,
                                        child: Row(
                                          children: [
                                            ClipOval(
                                              child: SizedBox(
                                                width: 42,
                                                height: 42,
                                                child: info.imageUrl.isEmpty
                                                    ? Image.asset(
                                                        'assets/static/logott.png',
                                                      )
                                                    : Image.network(
                                                        info.imageUrl,
                                                        fit: BoxFit.cover,
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                info.shopName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 78),
                                      _CheckoutLine(
                                        label: '账号',
                                        value: account,
                                      ),
                                      _CheckoutLine(
                                        label: '余额',
                                        value: _moneyText(info.balance),
                                      ),
                                      const SizedBox(height: 20),
                                      Container(
                                        height: 60,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(
                                              color: Color(0xFFEFEFEF),
                                            ),
                                            bottom: BorderSide(
                                              color: Color(0xFFEFEFEF),
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text(
                                              '消费金额',
                                              style: TextStyle(
                                                fontSize: 17,
                                                color: Color(0xFF505050),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextField(
                                                controller: amountController,
                                                textAlign: TextAlign.right,
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                  LengthLimitingTextInputFormatter(
                                                    10,
                                                  ),
                                                ],
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: '请输入消费金额',
                                                      hintStyle: TextStyle(
                                                        color: Color(
                                                          0xFFCCCCCC,
                                                        ),
                                                      ),
                                                      border: InputBorder.none,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _GradientButton(
                                        text: '确认结账',
                                        onTap: onSubmit,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            '余额不足?',
                                            style: TextStyle(
                                              color: Color(0xFFC3C3C3),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: onRecharge,
                                            child: const Padding(
                                              padding: EdgeInsets.only(
                                                left: 10,
                                              ),
                                              child: Text(
                                                '去充值>',
                                                style: TextStyle(
                                                  color: AppTheme.brandEnd,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            if (resultVisible)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white,
                  child: _PayResultView(
                    loading: !success && !fail,
                    success: success,
                    title: success
                        ? '支付成功'
                        : fail
                        ? '支付失败'
                        : '支付结果确认中',
                    subtitle: success
                        ? '交易已完成'
                        : fail
                        ? '请重新尝试'
                        : '请稍等确认结果',
                    buttonText: success
                        ? '完成'
                        : fail
                        ? '重新支付'
                        : null,
                    onButtonTap: success
                        ? onDone
                        : fail
                        ? onRetry
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShopMemberCard extends StatelessWidget {
  const _ShopMemberCard({
    required this.item,
    required this.onRecharge,
    required this.onRecord,
  });

  final ShopMemberItem item;
  final VoidCallback onRecharge;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 138,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 14,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: item.avatar.isEmpty
                          ? Image.asset('assets/static/logott.png')
                          : Image.network(item.avatar, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                item.userName.isEmpty ? '--' : item.userName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text.rich(
                              TextSpan(
                                text: '余额：',
                                children: [
                                  TextSpan(
                                    text: item.balanceText,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: AppTheme.brand,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                '会员卡号:${item.memberId.isEmpty ? '--' : item.memberId}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFC1C1C1),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 7,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '会员账号:${item.mobile.isEmpty ? '--' : item.mobile}',
                                    maxLines: 1,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Color(0xFFC1C1C1),
                                      fontSize: 12,
                                    ),
                                  ),
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
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: Color(0xFFEFEFEF)),
          ),
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SmallPillButton(text: '充值', filled: true, onTap: onRecharge),
                  const SizedBox(width: 15),
                  _SmallPillButton(text: '记录', filled: false, onTap: onRecord),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryGroupCard extends StatelessWidget {
  const _HistoryGroupCard({required this.group, required this.showFlag});

  final MemberHistoryGroup group;
  final int showFlag;

  @override
  Widget build(BuildContext context) {
    final records = group.recordsFor(showFlag);
    if (records.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(
              group.orderDate,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          for (final record in records)
            _HistoryRecordRow(record: record, showFlag: showFlag),
        ],
      ),
    );
  }
}

class _HistoryRecordRow extends StatelessWidget {
  const _HistoryRecordRow({required this.record, required this.showFlag});

  final MemberHistoryRecord record;
  final int showFlag;

  @override
  Widget build(BuildContext context) {
    final isCharge = showFlag == 0 ? record.useChargedFlag == 2 : showFlag == 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isCharge ? AppTheme.brandGradient : null,
                color: isCharge ? null : const Color(0xFF999999),
              ),
              child: Text(
                isCharge ? '充' : '消',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  _HistoryLine(
                    left: isCharge ? '充　值' : '消　费',
                    right: record.moneyFor(isCharge),
                    rightColor: isCharge
                        ? AppTheme.brand
                        : const Color(0xFF666666),
                    bigRight: true,
                  ),
                  _HistoryLine(
                    left: record.orderTime,
                    right: isCharge ? record.payTypeText : record.useWay,
                  ),
                  _HistoryLine(left: '操作员', right: record.operMobile),
                  _HistoryLine(left: '会　员', right: record.memberMobile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({
    required this.left,
    required this.right,
    this.rightColor = const Color(0xFF999999),
    this.bigRight = false,
  });

  final String left;
  final String right;
  final Color rightColor;
  final bool bigRight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: bigRight ? 16 : 14,
                fontWeight: bigRight ? FontWeight.w700 : FontWeight.w400,
                color: rightColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SimpleAppBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.chevron_left, size: 36),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      actions: const [SizedBox(width: 56)],
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.children});

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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, color: Color(0xFF505050)),
          ),
          const Spacer(),
          DefaultTextStyle(
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
            child: trailing,
          ),
        ],
      ),
    );
  }
}

class _InputLine extends StatelessWidget {
  const _InputLine({
    required this.title,
    required this.hint,
    required this.controller,
    this.onChanged,
  });

  final String title;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, color: Color(0xFF505050)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 15,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPillButton extends StatelessWidget {
  const _SmallPillButton({
    required this.text,
    required this.filled,
    required this.onTap,
  });

  final String text;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 35,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: filled ? AppTheme.brandGradient : null,
          color: filled ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: filled ? null : Border.all(color: AppTheme.brand),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: filled ? Colors.white : AppTheme.brand,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.text, required this.onTap});

  final String text;
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
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatisticChip extends StatelessWidget {
  const _StatisticChip({
    required this.text,
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 24,
        width: compact ? 92 : null,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: const Color(0x662D0F00),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            if (!compact) const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalBlock extends StatelessWidget {
  const _TotalBlock({
    required this.label,
    required this.money,
    this.count,
    this.alignLeft = false,
  });

  final String label;
  final String money;
  final String? count;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: alignLeft
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                money,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (count != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Text(
                count!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateRangeValue {
  const _DateRangeValue({required this.startDate, required this.endDate});

  final DateTime startDate;
  final DateTime endDate;
}

class _DateRangePickerSheet extends StatefulWidget {
  const _DateRangePickerSheet({required this.startDate, required this.endDate});

  final DateTime startDate;
  final DateTime endDate;

  @override
  State<_DateRangePickerSheet> createState() => _DateRangePickerSheetState();
}

class _DateRangePickerSheetState extends State<_DateRangePickerSheet> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _editingStart = true;

  DateTime get _activeDate => _editingStart ? _startDate : _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = _dateOnly(widget.startDate);
    _endDate = _dateOnly(widget.endDate);
  }

  void _changeDate(DateTime date) {
    final value = _dateOnly(date);
    setState(() {
      if (_editingStart) {
        _startDate = value;
      } else {
        _endDate = value;
      }
    });
  }

  void _confirm() {
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束日期不能早于开始日期')));
      return;
    }
    Navigator.of(
      context,
    ).pop(_DateRangeValue(startDate: _startDate, endDate: _endDate));
  }

  @override
  Widget build(BuildContext context) {
    final now = _dateOnly(DateTime.now());
    return Container(
      height: 535,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 88,
                      child: Center(
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '自定义时间',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 88),
                ],
              ),
            ),
            SizedBox(
              height: 76,
              child: Row(
                children: [
                  const SizedBox(width: 30),
                  Expanded(
                    child: _DateRangeTab(
                      text: _dateHyphen(_startDate),
                      active: _editingStart,
                      onTap: () => setState(() => _editingStart = true),
                    ),
                  ),
                  const SizedBox(
                    width: 46,
                    child: Center(
                      child: Text(
                        '至',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _DateRangeTab(
                      text: _dateHyphen(_endDate),
                      active: !_editingStart,
                      onTap: () => setState(() => _editingStart = false),
                    ),
                  ),
                  const SizedBox(width: 30),
                ],
              ),
            ),
            SizedBox(
              height: 235,
              child: _ChineseDatePicker(
                key: ValueKey(_editingStart),
                initialDate: _activeDate.isAfter(now) ? now : _activeDate,
                maxDate: now,
                onChanged: _changeDate,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 14, 30, 20),
              child: _GradientButton(text: '确认', onTap: _confirm),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRangeTab extends StatelessWidget {
  const _DateRangeTab({
    required this.text,
    required this.active,
    required this.onTap,
  });

  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppTheme.brandEnd : AppTheme.textPrimary,
              width: active ? 1.5 : 1,
            ),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? AppTheme.brandEnd : AppTheme.textPrimary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _ChineseDatePicker extends StatefulWidget {
  const _ChineseDatePicker({
    required this.initialDate,
    required this.maxDate,
    required this.onChanged,
    super.key,
  });

  final DateTime initialDate;
  final DateTime maxDate;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_ChineseDatePicker> createState() => _ChineseDatePickerState();
}

class _ChineseDatePickerState extends State<_ChineseDatePicker> {
  static const _minYear = 1990;
  static const _itemExtent = 42.0;

  late int _year;
  late int _month;
  late int _day;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  int get _maxYear => widget.maxDate.year;
  int get _monthCount => _year == _maxYear ? widget.maxDate.month : 12;
  int get _dayCount {
    final count = _daysInMonth(_year, _month);
    if (_year == widget.maxDate.year && _month == widget.maxDate.month) {
      return widget.maxDate.day;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    final initial = _clampDate(widget.initialDate);
    _year = initial.year;
    _month = initial.month;
    _day = initial.day;
    _yearController = FixedExtentScrollController(
      initialItem: _year - _minYear,
    );
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  DateTime _clampDate(DateTime date) {
    final clean = _dateOnly(date);
    if (clean.isAfter(widget.maxDate)) return _dateOnly(widget.maxDate);
    if (clean.year < _minYear) return DateTime(_minYear, 1);
    return clean;
  }

  void _setDate({int? year, int? month, int? day}) {
    final nextYear = year ?? _year;
    var nextMonth = month ?? _month;
    if (nextYear == _maxYear && nextMonth > widget.maxDate.month) {
      nextMonth = widget.maxDate.month;
    }
    final maxDay =
        nextYear == widget.maxDate.year && nextMonth == widget.maxDate.month
        ? widget.maxDate.day
        : _daysInMonth(nextYear, nextMonth);
    var nextDay = day ?? _day;
    if (nextDay > maxDay) nextDay = maxDay;

    setState(() {
      _year = nextYear;
      _month = nextMonth;
      _day = nextDay;
    });
    widget.onChanged(DateTime(_year, _month, _day));

    if (_monthController.selectedItem != _month - 1) {
      _monthController.jumpToItem(_month - 1);
    }
    if (_dayController.selectedItem != _day - 1) {
      _dayController.jumpToItem(_day - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: const CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          pickerTextStyle: TextStyle(fontSize: 20, color: AppTheme.textPrimary),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 18,
            right: 18,
            top: (235 - _itemExtent) / 2,
            child: Container(
              height: _itemExtent,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _PickerColumn(
                  controller: _yearController,
                  itemExtent: _itemExtent,
                  onSelectedItemChanged: (index) {
                    _setDate(year: _minYear + index);
                  },
                  children: [
                    for (var year = _minYear; year <= _maxYear; year++)
                      Center(child: Text('$year年')),
                  ],
                ),
              ),
              Expanded(
                child: _PickerColumn(
                  controller: _monthController,
                  itemExtent: _itemExtent,
                  onSelectedItemChanged: (index) {
                    _setDate(month: index + 1);
                  },
                  children: [
                    for (var month = 1; month <= _monthCount; month++)
                      Center(child: Text('$month月')),
                  ],
                ),
              ),
              Expanded(
                child: _PickerColumn(
                  controller: _dayController,
                  itemExtent: _itemExtent,
                  onSelectedItemChanged: (index) {
                    _setDate(day: index + 1);
                  },
                  children: [
                    for (var day = 1; day <= _dayCount; day++)
                      Center(child: Text('${day.toString().padLeft(2, '0')}日')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerColumn extends StatelessWidget {
  const _PickerColumn({
    required this.controller,
    required this.itemExtent,
    required this.onSelectedItemChanged,
    required this.children,
  });

  final FixedExtentScrollController controller;
  final double itemExtent;
  final ValueChanged<int> onSelectedItemChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: itemExtent,
      magnification: 1.02,
      useMagnifier: true,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: onSelectedItemChanged,
      children: children,
    );
  }
}

class _TypeSheetItem extends StatelessWidget {
  const _TypeSheetItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active || label == '取消'
              ? AppTheme.brandEnd
              : AppTheme.textPrimary,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _CheckoutLine extends StatelessWidget {
  const _CheckoutLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _PayResultView extends StatelessWidget {
  const _PayResultView({
    required this.loading,
    required this.success,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonTap,
  });

  final bool loading;
  final bool success;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const CircularProgressIndicator(color: AppTheme.brand)
          else if (success)
            const Icon(Icons.check_circle, color: Color(0xFF00D511), size: 70)
          else
            Image.asset('assets/static/image/kq.png', width: 70, height: 70),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFF999999))),
          if (buttonText != null && onButtonTap != null) ...[
            const SizedBox(height: 30),
            SizedBox(
              width: 170,
              child: _GradientButton(text: buttonText!, onTap: onButtonTap!),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberListEmpty extends StatelessWidget {
  const _MemberListEmpty({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Center(
          child: Column(
            children: [
              Image.asset(AppAssets.empty, width: 100, height: 83),
              const SizedBox(height: 10),
              const Text(
                '这里还什么都没有呢~',
                style: TextStyle(color: Color(0xFF999999)),
              ),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _GradientButton(text: '扫一扫添加会员', onTap: onScan),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SimpleEmpty extends StatelessWidget {
  const _SimpleEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.24),
        Center(
          child: Column(
            children: [
              Image.asset(AppAssets.empty, width: 100, height: 83),
              const SizedBox(height: 10),
              const Text(
                '这里还什么都没有呢~',
                style: TextStyle(color: Color(0xFF999999)),
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
    final text = loadingMore
        ? '努力加载中'
        : noMore
        ? '当前搜索内容已无其它结果了～'
        : '轻轻上拉';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

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

class ShopMemberItem {
  const ShopMemberItem({
    required this.userId,
    required this.userName,
    required this.memberId,
    required this.mobile,
    required this.avatar,
    required this.balance,
  });

  final String userId;
  final String userName;
  final String memberId;
  final String mobile;
  final String avatar;
  final num balance;

  String get balanceText => _moneyText(balance);

  factory ShopMemberItem.fromJson(Map<String, dynamic> json) {
    return ShopMemberItem(
      userId: _string(json['userId']),
      userName: _string(json['userName'] ?? json['nickname'] ?? json['name']),
      memberId: _string(json['memberId'] ?? json['memberCardId']),
      mobile: _string(json['mobile'] ?? json['memberMobile']),
      avatar: _string(json['avatar'] ?? json['avatarUrl']),
      balance:
          _asNum(json['balance'] ?? json['cardBalance'] ?? json['money']) ?? 0,
    );
  }
}

class _HistoryPage {
  const _HistoryPage({
    required this.groups,
    required this.total,
    required this.consumeMoney,
    required this.rechargeMoney,
    required this.totalUsedCount,
    required this.totalChargeCount,
  });

  final List<MemberHistoryGroup> groups;
  final int total;
  final String consumeMoney;
  final String rechargeMoney;
  final int totalUsedCount;
  final int totalChargeCount;

  int orderCountFor(int showFlag) =>
      showFlag == 2 ? totalChargeCount : totalUsedCount;

  static _HistoryPage fromRaw(dynamic raw) {
    if (raw is! Map) {
      return const _HistoryPage(
        groups: [],
        total: 0,
        consumeMoney: '0.00',
        rechargeMoney: '0.00',
        totalUsedCount: 0,
        totalChargeCount: 0,
      );
    }
    final first = raw['list'] is List && (raw['list'] as List).isNotEmpty
        ? (raw['list'] as List).first
        : null;
    if (first is! Map) {
      return _HistoryPage(
        groups: const [],
        total: _asInt(raw['total']) ?? 0,
        consumeMoney: '0.00',
        rechargeMoney: '0.00',
        totalUsedCount: 0,
        totalChargeCount: 0,
      );
    }
    final data = Map<String, dynamic>.from(first);
    List<MemberHistoryGroup> groupsFrom(String key) {
      final list = data[key];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map(
            (item) =>
                MemberHistoryGroup.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    final allGroups = groupsFrom('usedChargeHistoryList');
    return _HistoryPage(
      groups: allGroups.isNotEmpty
          ? allGroups
          : [
              ...groupsFrom('usedHistoryList'),
              ...groupsFrom('chargeHistoryList'),
            ],
      total: _asInt(raw['total']) ?? 0,
      consumeMoney: (_asNum(data['totalUsedMoney']) ?? 0).toStringAsFixed(2),
      rechargeMoney: (_asNum(data['totalChargeMoney']) ?? 0).toStringAsFixed(2),
      totalUsedCount: _asInt(data['totalUsedCount']) ?? 0,
      totalChargeCount: _asInt(data['totalChargeCount']) ?? 0,
    );
  }
}

class MemberHistoryGroup {
  const MemberHistoryGroup({
    required this.orderDate,
    required this.usedHistory,
    required this.chargedHistory,
    required this.mixedHistory,
  });

  final String orderDate;
  final List<MemberHistoryRecord> usedHistory;
  final List<MemberHistoryRecord> chargedHistory;
  final List<MemberHistoryRecord> mixedHistory;

  List<MemberHistoryRecord> recordsFor(int showFlag) {
    if (showFlag == 1) return usedHistory;
    if (showFlag == 2) return chargedHistory;
    return mixedHistory;
  }

  factory MemberHistoryGroup.fromJson(Map<String, dynamic> json) {
    List<MemberHistoryRecord> parse(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (item) =>
                MemberHistoryRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    return MemberHistoryGroup(
      orderDate: _string(json['orderDate'] ?? json['date']),
      usedHistory: parse('usedHistoryDOList'),
      chargedHistory: parse('chargedHistoryDOList'),
      mixedHistory: parse('usedChargedHistoryDOList'),
    );
  }
}

class MemberHistoryRecord {
  const MemberHistoryRecord({
    required this.useChargedFlag,
    required this.usedMoney,
    required this.chargeMoney,
    required this.orderTime,
    required this.payType,
    required this.useWay,
    required this.operMobile,
    required this.memberMobile,
  });

  final int useChargedFlag;
  final String usedMoney;
  final String chargeMoney;
  final String orderTime;
  final int payType;
  final String useWay;
  final String operMobile;
  final String memberMobile;

  String moneyFor(bool isCharge) => isCharge ? chargeMoney : usedMoney;

  String get payTypeText {
    if (payType == 1) return '微信';
    if (payType == 2) return '支付宝';
    return '其他';
  }

  factory MemberHistoryRecord.fromJson(Map<String, dynamic> json) {
    return MemberHistoryRecord(
      useChargedFlag: _asInt(json['useChargedFlag']) ?? 0,
      usedMoney: _string(json['usedMoney']),
      chargeMoney: _string(json['chargeMoney']),
      orderTime: _string(json['orderTime'] ?? json['memberOrderDatetime']),
      payType: _asInt(json['payType']) ?? 0,
      useWay: _string(json['useWay']),
      operMobile: _string(json['operMobile'] ?? json['operator']),
      memberMobile: _string(json['memberMobile'] ?? json['mobile']),
    );
  }
}

class _CheckoutInfo {
  const _CheckoutInfo({
    required this.shopName,
    required this.name,
    required this.imageUrl,
    required this.mobile,
    required this.balance,
  });

  const _CheckoutInfo.empty()
    : shopName = '',
      name = '',
      imageUrl = '',
      mobile = '',
      balance = 0;

  final String shopName;
  final String name;
  final String imageUrl;
  final String mobile;
  final num balance;

  factory _CheckoutInfo.fromJson(Map<String, dynamic> json) {
    return _CheckoutInfo(
      shopName: _string(json['shopName'] ?? json['name']),
      name: _string(json['name']),
      imageUrl: _string(json['imageUrl'] ?? json['avatar'] ?? json['logo']),
      mobile: _string(json['mobile'] ?? json['userMobile']),
      balance: _asNum(json['balance']) ?? 0,
    );
  }
}

class _LocalUser {
  const _LocalUser({
    required this.userId,
    required this.mobile,
    required this.shopId,
    required this.shopName,
    required this.avatar,
    required this.isGroupManager,
  });

  const _LocalUser.empty()
    : userId = '',
      mobile = '',
      shopId = '',
      shopName = '',
      avatar = '',
      isGroupManager = false;

  final String userId;
  final String mobile;
  final String shopId;
  final String shopName;
  final String avatar;
  final bool isGroupManager;

  static Future<_LocalUser> load(AppStorage storage) async {
    final raw = await storage.getUserDetail();
    final isGroupManager = await storage.isGroupManager();
    if (raw == null || raw.isEmpty) {
      return _LocalUser(
        userId: await storage.getUserId() ?? '',
        mobile: '',
        shopId: '',
        shopName: '',
        avatar: '',
        isGroupManager: isGroupManager,
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const _LocalUser.empty();
      final data = Map<String, dynamic>.from(decoded);
      return _LocalUser(
        userId: _string(data['userId'] ?? await storage.getUserId()),
        mobile: _string(data['mobile']),
        shopId: _string(data['shopId']),
        shopName: _string(data['shopName']),
        avatar: _string(data['avatar']),
        isGroupManager: isGroupManager,
      );
    } catch (_) {
      return const _LocalUser.empty();
    }
  }
}

String _string(dynamic value) => value?.toString() ?? '';

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

num? _asNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

String _moneyText(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _dateCompact(DateTime date) {
  return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
}

String _dateSlash(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _dateHyphen(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

int _daysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}
