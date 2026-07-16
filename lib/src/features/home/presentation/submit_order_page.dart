import 'package:flutter/material.dart';
import 'package:fluwx/fluwx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/payment/wechat_pay_service.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import '../data/home_models.dart';

class SubmitOrderPage extends ConsumerStatefulWidget {
  const SubmitOrderPage({required this.couponId, this.bgc = '', super.key});

  final String couponId;
  final String bgc;

  @override
  ConsumerState<SubmitOrderPage> createState() => _SubmitOrderPageState();
}

class _SubmitOrderPageState extends ConsumerState<SubmitOrderPage> {
  _SubmitCoupon? _coupon;
  FluwxCancelable? _paySubscription;
  String? _payingOrderId;
  bool _loading = true;
  bool _payLoading = false;
  bool _payFailed = false;
  String? _error;
  int _payChoose = 1;

  @override
  void initState() {
    super.initState();
    _paySubscription = WeChatPayService.instance.fluwx.addSubscriber(
      _handleWeChatResponse,
    );
    _loadCoupon();
  }

  @override
  void dispose() {
    _paySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCoupon() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get(
            TuanTuanEndpoints.couponInfo,
            query: {'couponId': widget.couponId},
          );
      final envelope = ApiEnvelope.parse<_SubmitCoupon>(
        raw,
        (data) =>
            _SubmitCoupon.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      if (!mounted) return;
      if (!envelope.isSuccess || envelope.data == null) {
        setState(() {
          _error = envelope.message ?? '团优惠详情获取失败';
          _loading = false;
        });
        return;
      }
      setState(() {
        _coupon = envelope.data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _getPay() async {
    if (_payLoading) return;
    setState(() {
      _payLoading = true;
      _payFailed = false;
    });
    await _createOrder();
  }

  Future<void> _createOrder() async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.createOrder,
            data: {'couponId': widget.couponId},
          );
      final envelope = ApiEnvelope.parse<Map<String, dynamic>>(
        raw,
        (data) => Map<String, dynamic>.from(data as Map),
      );
      final orderId = envelope.data?['OrderMgmtId']?.toString() ?? '';
      if (!envelope.isSuccess || orderId.isEmpty) {
        _showPageToast('创建订单失败');
        if (mounted) setState(() => _payLoading = false);
        return;
      }
      _payingOrderId = orderId;
      await _getPayInfo(orderId);
    } catch (_) {
      _showPageToast('创建订单失败');
      if (mounted) setState(() => _payLoading = false);
    }
  }

  Future<void> _getPayInfo(String orderId) async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get(TuanTuanEndpoints.payInfo, query: {'orderId': orderId});
      final envelope = ApiEnvelope.parse<Map<String, dynamic>>(
        raw,
        (data) => Map<String, dynamic>.from(data as Map),
      );
      if (!envelope.isSuccess) {
        _showPageToast(envelope.message ?? '获取支付信息失败');
        if (mounted) setState(() => _payLoading = false);
        return;
      }

      final installed = await WeChatPayService.instance.isWeChatInstalled;
      if (!installed) {
        _showPageToast('请先安装微信');
        await _deletePayInfo(orderId);
        return;
      }
      final launched = await WeChatPayService.instance.pay(envelope.data ?? {});
      if (!launched) {
        _showPageToast('调起微信支付失败');
        await _deletePayInfo(orderId);
      }
    } catch (error) {
      _showPageToast(error.toString());
      await _deletePayInfo(orderId);
    }
  }

  Future<void> _handleWeChatResponse(WeChatResponse response) async {
    if (response is! WeChatPaymentResponse) return;
    final orderId = _payingOrderId;
    if (orderId == null || orderId.isEmpty) return;
    if (response.isSuccessful) {
      await _getPayStatus(orderId);
    } else {
      await _deletePayInfo(orderId);
    }
  }

  Future<void> _getPayStatus(String orderId) async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get(TuanTuanEndpoints.payStatus, query: {'orderId': orderId});
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!mounted) return;
      if (envelope.isSuccess) {
        setState(() {
          _payLoading = false;
          _payFailed = false;
        });
        context.go(
          Uri(
            path: '/coupon-order-detail',
            queryParameters: {
              'bgc': widget.bgc,
              'type': '1',
              'orderId': orderId,
            },
          ).toString(),
        );
      } else {
        await _deletePayInfo(orderId);
      }
    } catch (_) {
      await _deletePayInfo(orderId);
    }
  }

  Future<void> _deletePayInfo(String orderId) async {
    try {
      await ref
          .read(apiClientProvider)
          .delete(TuanTuanEndpoints.deleteOrder, data: {'orderId': orderId});
    } finally {
      if (mounted) {
        setState(() {
          _payLoading = true;
          _payFailed = true;
        });
      }
    }
  }

  void _rePay() {
    setState(() {
      _payChoose = 1;
      _payLoading = false;
      _payFailed = false;
    });
  }

  void _showPageToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_payLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _PayResultView(payFailed: _payFailed, onRetry: _rePay),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.chevron_left,
            color: Color(0xFF333333),
            size: 34,
          ),
        ),
        title: const Text(
          '提交订单',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : _SubmitBottomBar(
              title: _payChoose == 1 ? '微信支付' : '支付宝支付',
              onTap: _getPay,
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 70,
          height: 65,
          child: Image(image: AssetImage('assets/static/data.gif')),
        ),
      );
    }
    if (_error != null || _coupon == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? '优惠不存在',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadCoupon, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final coupon = _coupon!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _OrderCouponCard(coupon: coupon),
        if (coupon.validPeriodText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              '此优惠卷过期时间为${coupon.validPeriodText},请在有效期内使用,过期不退',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFEE0000), fontSize: 14),
            ),
          ),
        const SizedBox(height: 16),
        _PayChooseCard(
          payChoose: _payChoose,
          onChoose: (value) => setState(() => _payChoose = value),
        ),
      ],
    );
  }
}

class _OrderCouponCard extends StatelessWidget {
  const _OrderCouponCard({required this.coupon});

  final _SubmitCoupon coupon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Image.asset(
                  'assets/static/image/shop-2.png',
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    coupon.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: coupon.imageUrl.isEmpty
                        ? Container(color: const Color(0xFFF5F5F5))
                        : Image.network(
                            coupon.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Container(color: const Color(0xFFF5F5F5)),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Text(
                            coupon.couponName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: Text(
                            '￥${_money(coupon.couponPrice)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.brand,
                            ),
                          ),
                        ),
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: Text(
                            '×1',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
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
    );
  }
}

class _PayChooseCard extends StatelessWidget {
  const _PayChooseCard({required this.payChoose, required this.onChoose});

  final int payChoose;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChoose(1),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: payChoose == 1
                      ? AppTheme.brand
                      : const Color(0xFFEEEEEE),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/static/image/wxpay.png',
                    width: 26,
                    height: 26,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '微信支付',
                    style: TextStyle(fontSize: 16, color: Color(0xFF111111)),
                  ),
                  const Spacer(),
                  _ChooseIndicator(active: payChoose == 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChooseIndicator extends StatelessWidget {
  const _ChooseIndicator({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCCCCCC), width: 5),
        ),
      );
    }
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: AppTheme.brand,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 14),
    );
  }
}

class _SubmitBottomBar extends StatelessWidget {
  const _SubmitBottomBar({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF4F4F4))),
        ),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayResultView extends StatelessWidget {
  const _PayResultView({required this.payFailed, required this.onRetry});

  final bool payFailed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: payFailed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/static/image/emoji-timeline.png',
                  width: 48,
                  height: 48,
                ),
                const SizedBox(height: 20),
                const Text(
                  '支付失败',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  '请重新尝试',
                  style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    width: 160,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '重新支付',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: AppTheme.brand,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '支付结果确认中',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  '请稍等确认结果',
                  style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                ),
              ],
            ),
    );
  }
}

class _SubmitCoupon {
  const _SubmitCoupon({
    required this.shopName,
    required this.couponName,
    required this.couponPrice,
    required this.imageUrl,
    required this.validPeriodText,
  });

  final String shopName;
  final String couponName;
  final double couponPrice;
  final String imageUrl;
  final String validPeriodText;

  factory _SubmitCoupon.fromJson(Map<String, dynamic> json) {
    final images = json['imageList'];
    return _SubmitCoupon(
      shopName: json['name']?.toString() ?? '',
      couponName: json['couponName']?.toString() ?? '',
      couponPrice: _asDouble(json['couponPrice']) ?? 0,
      imageUrl: images is List && images.isNotEmpty
          ? _imageUrl(images.first)
          : '',
      validPeriodText: _formatValidPeriod(json['validPeriod']),
    );
  }
}

String _imageUrl(dynamic raw) {
  if (raw is Map) {
    return raw['zipImageUrl']?.toString() ?? raw['imageUrl']?.toString() ?? '';
  }
  return raw?.toString() ?? '';
}

String _formatValidPeriod(dynamic value) {
  if (value == null || value.toString().isEmpty) return '';
  final raw = value.toString().trim();
  DateTime? date;
  final timestamp = int.tryParse(raw);
  if (timestamp != null) {
    date = DateTime.fromMillisecondsSinceEpoch(
      raw.length >= 13 ? timestamp : timestamp * 1000,
    );
  } else {
    date = DateTime.tryParse(raw);
  }
  if (date == null) return raw.split(' ').first;
  return '${date.year}年${_twoDigits(date.month)}月${_twoDigits(date.day)}日';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String _money(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
