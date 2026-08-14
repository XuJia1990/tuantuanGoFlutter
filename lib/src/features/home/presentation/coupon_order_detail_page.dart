import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/ui/app_toast.dart';
import '../../../shared/widgets/cached_image.dart';
import '../data/home_models.dart';

class CouponOrderDetailPage extends ConsumerStatefulWidget {
  const CouponOrderDetailPage({required this.params, super.key});

  final Map<String, String> params;

  @override
  ConsumerState<CouponOrderDetailPage> createState() =>
      _CouponOrderDetailPageState();
}

class _CouponOrderDetailPageState extends ConsumerState<CouponOrderDetailPage> {
  _CouponOrderDetail? _detail;
  ShopDetail? _shop;
  String _mobile = '';
  bool _loading = true;
  String? _error;

  String get _orderId => widget.params['orderId'] ?? '';
  int get _type => int.tryParse(widget.params['type'] ?? '2') ?? 2;
  int get _status => int.tryParse(widget.params['status'] ?? '0') ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mobile = _mobileFromUserDetail(
        await ref.read(appStorageProvider).getUserDetail(),
      );
      final raw = await ref
          .read(apiClientProvider)
          .get(TuanTuanEndpoints.orderDetail, query: {'orderId': _orderId});
      final envelope = ApiEnvelope.parse<_CouponOrderDetail>(
        raw,
        (data) =>
            _CouponOrderDetail.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      if (!envelope.isSuccess || envelope.data == null) {
        throw Exception(envelope.message ?? '订单详情获取失败');
      }
      final detail = envelope.data!;
      ShopDetail? shop;
      if (detail.shopId.isNotEmpty) {
        final shopRaw = await ref
            .read(apiClientProvider)
            .get(TuanTuanEndpoints.shopInfo, query: {'shopId': detail.shopId});
        final shopEnvelope = ApiEnvelope.parse<ShopDetail>(
          shopRaw,
          (data) => ShopDetail.fromJson(Map<String, dynamic>.from(data as Map)),
        );
        if (shopEnvelope.isSuccess) shop = shopEnvelope.data;
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _shop = shop;
        _mobile = mobile;
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

  Future<void> _copyOrderId() async {
    final detail = _detail;
    if (detail == null || detail.orderMgmtId.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: detail.orderMgmtId));
    _toast('复制成功');
  }

  Future<void> _openMap() async {
    final shop = _shop;
    final detail = _detail;
    final latitude = shop?.latitude;
    final longitude = shop?.longitude;
    if (latitude == null || longitude == null) {
      _toast('当前店铺暂无位置信息');
      return;
    }
    final uri = Uri.https('maps.apple.com', '/', {
      'q': shop?.name ?? detail?.shopName ?? '',
      'address': shop?.address ?? detail?.shopAddress ?? '',
      'll': '$latitude,$longitude',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('无法打开地图');
    }
  }

  void _goShop() {
    final shopId = _detail?.shopId ?? '';
    if (shopId.isEmpty) return;
    context.push('/shop/$shopId');
  }

  void _handleBack() {
    final router = GoRouter.of(context);
    final popCount = _type == 1 ? 2 : 1;
    var popped = false;
    for (var index = 0; index < popCount && router.canPop(); index += 1) {
      router.pop();
      popped = true;
    }
    if (!popped) {
      router.go('/');
    }
  }

  void _toast(String message) {
    AppToast.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final usedOrExpired =
        detail?.writeoffStatus == 1 ||
        detail?.writeoffStatus == 2 ||
        _status == 1 ||
        _status == 2;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: usedOrExpired
            ? const Color(0xFF9B9B9B)
            : const Color(0xFFFF526F),
        appBar: AppBar(
          leading: IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 34),
          ),
          title: Text(
            _type == 1 ? '购买成功' : '我的卷包',
            style: const TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _error != null || detail == null
            ? _OrderError(message: _error ?? '订单不存在', onRetry: _load)
            : _OrderContent(
                detail: detail,
                mobile: _mobile,
                status: _status,
                usedOrExpired: usedOrExpired,
                onCopy: _copyOrderId,
                onMap: _openMap,
                onShop: _goShop,
              ),
      ),
    );
  }
}

class _OrderContent extends StatelessWidget {
  const _OrderContent({
    required this.detail,
    required this.mobile,
    required this.status,
    required this.usedOrExpired,
    required this.onCopy,
    required this.onMap,
    required this.onShop,
  });

  final _CouponOrderDetail detail;
  final String mobile;
  final int status;
  final bool usedOrExpired;
  final VoidCallback onCopy;
  final VoidCallback onMap;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final qrData = '${detail.uuid},${detail.orderMgmtId},cop';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Stack(
          children: [
            Positioned(
              right: -70,
              top: -50,
              child: Opacity(
                opacity: 0.16,
                child: Image.asset(
                  'assets/static/image/hot-logo.png',
                  width: 210,
                  height: 210,
                ),
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _OrderImage(url: detail.logoImageUrl, size: 42),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              detail.shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: onShop,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: AppTheme.brand,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: onMap,
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/static/image/local.png',
                              width: 18,
                              height: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                detail.shopAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppTheme.brand,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OrderImage(url: detail.couponImage, size: 84),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  detail.couponName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '￥${detail.couponPrice}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.brand,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '￥${detail.oriPrice}',
                                      style: const TextStyle(
                                        color: Color(0xFF999999),
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${detail.validPeriod}到期',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _DiscountBadge(
                            rate: detail.discountRate,
                            disabled: usedOrExpired,
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        '核销码',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.white,
                            child: QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              size: 180,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          if (usedOrExpired)
                            Positioned.fill(
                              child: ColoredBox(
                                color: const Color(0x99FFFFFF),
                                child: Center(
                                  child: _Stamp(
                                    text:
                                        detail.writeoffStatus == 1 ||
                                            status == 1
                                        ? '已使用'
                                        : '已过期',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '订单信息',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _OrderLine(
                        label: '订单号',
                        value: detail.orderMgmtId,
                        trailing: GestureDetector(
                          onTap: onCopy,
                          child: const Text(
                            '复制',
                            style: TextStyle(color: AppTheme.brand),
                          ),
                        ),
                      ),
                      const _OrderLine(label: '交易方式', value: '微信支付'),
                      _OrderLine(
                        label: '手机号',
                        value: mobile.isEmpty ? '--' : mobile,
                      ),
                      _OrderLine(label: '下单时间', value: detail.orderTime),
                      _OrderLine(
                        label: '付款时间',
                        value: detail.payTime.isEmpty ? '--' : detail.payTime,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderLine extends StatelessWidget {
  const _OrderLine({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '--' : value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.rate, required this.disabled});

  final int rate;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF7F7F7) : const Color(0x26FF9809),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rate.toString(),
            style: TextStyle(
              fontSize: rate >= 100 ? 20 : 26,
              fontWeight: FontWeight.w800,
              color: disabled
                  ? const Color(0xFFCCCCCC)
                  : const Color(0xFFFF4353),
              height: 0.9,
            ),
          ),
          Text(
            '% OFF',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: disabled
                  ? const Color(0xFFCCCCCC)
                  : const Color(0xFFFF4353),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.25,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.brand, width: 3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.brand,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _OrderImage extends StatelessWidget {
  const _OrderImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? Container(color: const Color(0xFFF2F2F2))
            : AppCachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: Container(color: const Color(0xFFF2F2F2)),
              ),
      ),
    );
  }
}

class _OrderError extends StatelessWidget {
  const _OrderError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _CouponOrderDetail {
  const _CouponOrderDetail({
    required this.orderMgmtId,
    required this.uuid,
    required this.shopId,
    required this.shopName,
    required this.shopAddress,
    required this.logoImageUrl,
    required this.couponName,
    required this.couponImage,
    required this.couponPrice,
    required this.oriPrice,
    required this.validPeriod,
    required this.discountRate,
    required this.orderTime,
    required this.payTime,
    required this.writeoffStatus,
  });

  final String orderMgmtId;
  final String uuid;
  final String shopId;
  final String shopName;
  final String shopAddress;
  final String logoImageUrl;
  final String couponName;
  final String couponImage;
  final String couponPrice;
  final String oriPrice;
  final String validPeriod;
  final int discountRate;
  final String orderTime;
  final String payTime;
  final int writeoffStatus;

  factory _CouponOrderDetail.fromJson(Map<String, dynamic> json) {
    final images = json['couponImageUrlList'];
    final rate = _asDouble(json['discountRate']) ?? 0;
    return _CouponOrderDetail(
      orderMgmtId: _string(json['orderMgmtId'] ?? json['orderId']),
      uuid: _string(json['uuid']),
      shopId: _string(json['shopId']),
      shopName: _string(json['shopName']),
      shopAddress: _string(json['shopAddress'] ?? json['address']),
      logoImageUrl: _string(json['logoImageUrl'] ?? json['logoImageURL']),
      couponName: _string(json['couponName']),
      couponImage: images is List && images.isNotEmpty
          ? _string(images.first)
          : _string(json['couponImage']),
      couponPrice: _string(json['couponPrice']),
      oriPrice: _string(json['oriPrice']),
      validPeriod: _formatDate(json['validPeriod']),
      discountRate: rate <= 1 ? (rate * 100).toInt() : rate.toInt(),
      orderTime: _formatDate(json['orderTime']),
      payTime: json['payTime'] == null ? '' : _formatDate(json['payTime']),
      writeoffStatus: _asInt(json['writeoffStatus']) ?? 0,
    );
  }
}

String _formatDate(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '';
  final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  final date = DateTime.tryParse(normalized);
  if (date == null) return raw;
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

String _mobileFromUserDetail(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return decoded['mobile']?.toString() ?? '';
    }
  } catch (_) {}
  return '';
}

String _string(dynamic value) => value?.toString() ?? '';

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
