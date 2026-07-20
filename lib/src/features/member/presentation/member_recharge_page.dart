import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/ui/app_toast.dart';
import '../../home/data/home_models.dart';

class MemberRechargePage extends ConsumerStatefulWidget {
  const MemberRechargePage({required this.params, super.key});

  final Map<String, String> params;

  @override
  ConsumerState<MemberRechargePage> createState() => _MemberRechargePageState();
}

class _MemberRechargePageState extends ConsumerState<MemberRechargePage> {
  final _amountController = TextEditingController();
  final _confirmController = TextEditingController();

  _MemberUser _user = const _MemberUser.empty();
  _RechargeShop _shop = const _RechargeShop.empty();
  final _payList = <_PayCategory>[];
  int _activePayId = 24;
  bool _loadingShop = true;
  bool _submitting = false;
  bool _handlePayLoad = false;
  bool _createSuccess = false;
  bool _createFail = false;
  String _failMsg = '';
  _ChargeSuccess? _successData;

  int get _type => int.tryParse(widget.params['type'] ?? '1') ?? 1;
  int get _isShopCharge =>
      int.tryParse(widget.params['isShopCharge'] ?? '0') ?? 0;
  String get _shopId => widget.params['shopId'] ?? '';
  String get _routeUserId => widget.params['userId'] ?? '';
  String get _routeNumber => widget.params['number'] ?? '';

  @override
  void initState() {
    super.initState();
    _activePayId = _isShopCharge == 1 ? 23 : 24;
    _loadInitial();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final user = await _loadUser();
    if (!mounted) return;
    setState(() => _user = user);
    await Future.wait([_loadShop(), _loadChargeTypes()]);
  }

  Future<_MemberUser> _loadUser() async {
    final raw = await ref.read(appStorageProvider).getUserDetail();
    if (raw == null || raw.isEmpty) return const _MemberUser.empty();
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const _MemberUser.empty();
      return _MemberUser.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return const _MemberUser.empty();
    }
  }

  Future<void> _loadShop() async {
    if (_isShopCharge == 1) {
      if (!mounted) return;
      setState(() {
        _shop = _RechargeShop(name: _user.shopName, avatar: _user.avatar);
        _loadingShop = false;
      });
      return;
    }
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get(TuanTuanEndpoints.shopInfo, query: {'shopId': _shopId});
      final envelope = ApiEnvelope.parse<ShopDetail>(
        raw,
        (data) => ShopDetail.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      if (!mounted) return;
      final shop = envelope.data;
      setState(() {
        _shop = _RechargeShop(
          name: shop?.name ?? '',
          avatar: shop?.imageUrls.isNotEmpty == true
              ? shop!.imageUrls.first
              : '',
        );
        _loadingShop = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingShop = false);
    }
  }

  Future<void> _loadChargeTypes() async {
    if (_isShopCharge != 1) {
      setState(() {
        _payList
          ..clear()
          ..add(const _PayCategory(categoryId: 24, categoryName: '微信'));
      });
      return;
    }
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get(TuanTuanEndpoints.chargeTypeList);
      final envelope = ApiEnvelope.parse<List<_PayCategory>>(
        raw,
        (data) => data is List
            ? data
                  .whereType<Map>()
                  .map(
                    (item) =>
                        _PayCategory.fromJson(Map<String, dynamic>.from(item)),
                  )
                  .toList()
            : const [],
      );
      if (!mounted) return;
      setState(() {
        _payList
          ..clear()
          ..addAll(envelope.data ?? const []);
        if (_payList.isNotEmpty) _activePayId = _payList.first.categoryId;
      });
    } catch (_) {
      _toast('获取支付方式失败');
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_type == 1) {
      final amount = num.tryParse(_amountController.text);
      if (_amountController.text.isEmpty) {
        _toast('充值金额不能为空');
        return;
      }
      if (amount == null || amount < 100) {
        _toast('充值金额不能小于100');
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
    }
    await _createOrder();
  }

  Future<void> _createOrder() async {
    setState(() {
      _submitting = true;
      _handlePayLoad = true;
      _createSuccess = false;
      _createFail = false;
      _failMsg = '';
    });

    final data = <String, dynamic>{
      'isShopCharge': _isShopCharge,
      'chargeUserId': _user.userId,
      'chargeWay': _activePayId,
      'chargeMoney': _type == 1
          ? _amountController.text
          : num.tryParse(_routeNumber) ?? 0,
      'remark': '',
      'chargeShopId': _shopId,
      'userId': _routeUserId,
      'discountWay': '',
    };

    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(TuanTuanEndpoints.createMember, data: data);
      final envelope = ApiEnvelope.parse<Map<String, dynamic>>(
        raw,
        (value) => Map<String, dynamic>.from(value as Map),
      );
      final body = envelope.data ?? const {};
      if (!envelope.isSuccess || body['isSecces'] != true) {
        _showFail(envelope.message ?? '充值失败');
        return;
      }
      final memberOrderId = body['memberOrderId']?.toString() ?? '';
      final chargeQuery = <String, dynamic>{
        'isCreateFlg': _type == 2,
        'memberOrderId': memberOrderId,
        'userId': _isShopCharge == 1 ? _routeUserId : _user.userId,
      };

      if (_activePayId == 24 && _isShopCharge != 1) {
        _showFail('微信支付功能待接入，请稍后重新充值');
        return;
      }
      await _chargeMember(chargeQuery);
    } catch (_) {
      _showFail('充值失败');
    }
  }

  Future<void> _chargeMember(Map<String, dynamic> data) async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(TuanTuanEndpoints.chargeMember, data: data);
      final envelope = ApiEnvelope.parse<_ChargeSuccess>(
        raw,
        (value) =>
            _ChargeSuccess.fromJson(Map<String, dynamic>.from(value as Map)),
      );
      if (!mounted) return;
      if (envelope.isSuccess && envelope.data != null) {
        setState(() {
          _successData = envelope.data;
          _createSuccess = true;
          _createFail = false;
          _submitting = false;
        });
      } else {
        _showFail(envelope.message ?? '充值失败');
      }
    } catch (_) {
      _showFail('充值失败');
    }
  }

  void _showFail(String message) {
    if (!mounted) return;
    setState(() {
      _failMsg = message;
      _createFail = true;
      _createSuccess = false;
      _submitting = false;
    });
  }

  void _reCreate() {
    setState(() {
      _handlePayLoad = false;
      _createFail = false;
      _createSuccess = false;
      _failMsg = '';
      _submitting = false;
    });
  }

  void _toast(String message) {
    AppToast.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, size: 34),
        ),
        title: const Text(
          '会员卡充值',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _handlePayLoad ? _buildPayResult() : _buildForm(),
      bottomNavigationBar: _handlePayLoad
          ? null
          : SafeArea(
              top: false,
              child: Container(
                height: 58,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF4F4F4))),
                ),
                child: GestureDetector(
                  onTap: _submit,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: _submitting ? null : AppTheme.brandGradient,
                      color: _submitting ? const Color(0xFFC8C8C8) : null,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Text(
                      _submitting ? '处理中...' : '确认充值',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _RechargeCard(
            children: [
              _ShopLine(shop: _shop, loading: _loadingShop),
              const Divider(height: 1, color: Color(0xFFF7F7F7)),
              _InputLine(
                title: '充值金额',
                controller: _amountController,
                hint: '请输入充值金额',
              ),
              const Divider(height: 1, color: Color(0xFFF7F7F7)),
              _InputLine(
                title: '确认充值金额',
                controller: _confirmController,
                hint: '请再次输入充值金额',
              ),
            ],
          ),
          if (_isShopCharge == 0)
            const _RechargeCard(
              marginBottom: 0,
              padding: EdgeInsets.symmetric(horizontal: 10),
              children: [
                SizedBox(
                  height: 55,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '*注：充值金额不可退款！',
                      style: TextStyle(color: AppTheme.brand, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '支付方式',
                  style: TextStyle(fontSize: 16, color: AppTheme.textPrimary),
                ),
                for (final item in _payList)
                  _PayChooseItem(
                    item: item,
                    selected: _activePayId == item.categoryId,
                    onTap: () => setState(() => _activePayId = item.categoryId),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayResult() {
    if (!_createSuccess && !_createFail) {
      return const _PayStateView(
        icon: CircularProgressIndicator(color: AppTheme.brand),
        title: '支付结果确认中',
        subtitle: '请稍等确认结果',
      );
    }
    if (_createSuccess) {
      final data = _successData;
      return _PayStateView(
        icon: const Icon(
          Icons.check_circle,
          color: Color(0xFF00D511),
          size: 70,
        ),
        title: '充值成功',
        subtitle: data == null
            ? ''
            : '${data.chargeMoney}元\n卡内余额: ${data.money}元',
        buttonText: '确认',
        onButtonTap: () => context.pop(),
      );
    }
    return _PayStateView(
      icon: Image.asset('assets/static/image/kq.png', width: 54, height: 54),
      title: '充值失败',
      subtitle: _failMsg.isEmpty ? '哦豁，不知道啥原因失败了，请重新充值' : _failMsg,
      buttonText: '重新充值',
      onButtonTap: _reCreate,
    );
  }
}

class _RechargeCard extends StatelessWidget {
  const _RechargeCard({
    required this.children,
    this.marginBottom = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final List<Widget> children;
  final double marginBottom;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _ShopLine extends StatelessWidget {
  const _ShopLine({required this.shop, required this.loading});

  final _RechargeShop shop;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 35,
              height: 35,
              child: shop.avatar.isEmpty
                  ? Container(
                      color: const Color(0xFFF0F0F0),
                      child: const Icon(Icons.storefront_outlined, size: 19),
                    )
                  : Image.network(shop.avatar, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loading ? '加载中...' : shop.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputLine extends StatelessWidget {
  const _InputLine({
    required this.title,
    required this.controller,
    required this.hint,
  });

  final String title;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
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
                filled: false,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayChooseItem extends StatelessWidget {
  const _PayChooseItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _PayCategory item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.brand : const Color(0xFFEEEEEE),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Image.asset(_payIcon(item.categoryId), width: 26, height: 26),
            const SizedBox(width: 8),
            Text(
              item.categoryName,
              style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
            ),
            const Spacer(),
            selected
                ? Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppTheme.brand,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 15,
                    ),
                  )
                : Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFCCCCCC),
                        width: 5,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _PayStateView extends StatelessWidget {
  const _PayStateView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonTap,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 125),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
          ],
          if (buttonText != null) ...[
            const SizedBox(height: 30),
            GestureDetector(
              onTap: onButtonTap,
              child: Container(
                width: 160,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  buttonText!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _payIcon(int id) {
  return switch (id) {
    23 => 'assets/static/image/xj.png',
    24 => 'assets/static/image/wxpay.png',
    25 => 'assets/static/image/zfb.png',
    26 => 'assets/static/image/paypay.png',
    27 => 'assets/static/image/pos.png',
    28 => 'assets/static/image/qt.png',
    _ => 'assets/static/image/qt.png',
  };
}

class _MemberUser {
  const _MemberUser({
    required this.userId,
    required this.shopName,
    required this.avatar,
  });

  const _MemberUser.empty() : this(userId: '', shopName: '', avatar: '');

  final String userId;
  final String shopName;
  final String avatar;

  factory _MemberUser.fromJson(Map<String, dynamic> json) {
    return _MemberUser(
      userId: json['userId']?.toString() ?? '',
      shopName: json['shopName']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
    );
  }
}

class _RechargeShop {
  const _RechargeShop({required this.name, required this.avatar});
  const _RechargeShop.empty() : this(name: '', avatar: '');

  final String name;
  final String avatar;
}

class _PayCategory {
  const _PayCategory({required this.categoryId, required this.categoryName});

  final int categoryId;
  final String categoryName;

  factory _PayCategory.fromJson(Map<String, dynamic> json) {
    return _PayCategory(
      categoryId: int.tryParse(json['categoryId']?.toString() ?? '') ?? 0,
      categoryName: json['categoryName']?.toString() ?? '',
    );
  }
}

class _ChargeSuccess {
  const _ChargeSuccess({required this.chargeMoney, required this.money});

  final String chargeMoney;
  final String money;

  factory _ChargeSuccess.fromJson(Map<String, dynamic> json) {
    return _ChargeSuccess(
      chargeMoney: json['chargeMoney']?.toString() ?? '',
      money: json['money']?.toString() ?? '',
    );
  }
}
