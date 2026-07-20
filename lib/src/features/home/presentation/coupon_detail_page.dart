import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/ui/app_toast.dart';
import '../data/home_models.dart';
import '../data/home_repository.dart';

class CouponDetailPage extends ConsumerStatefulWidget {
  const CouponDetailPage({
    required this.couponId,
    required this.title,
    super.key,
  });

  final String couponId;
  final String title;

  @override
  ConsumerState<CouponDetailPage> createState() => _CouponDetailPageState();
}

class _CouponDetailPageState extends ConsumerState<CouponDetailPage> {
  CouponDetail? _coupon;
  var _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCoupon();
  }

  Future<void> _loadCoupon() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final coupon = await ref
          .read(homeRepositoryProvider)
          .getCouponInfo(couponId: widget.couponId);
      if (!mounted) return;
      setState(() {
        _coupon = coupon;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _copyDetail() async {
    final coupon = _coupon;
    if (coupon == null || coupon.items.isEmpty) return;
    final value = coupon.items
        .map((item) => '${item.goodsName}:${item.quantity}${item.unit}')
        .join(',');
    await Clipboard.setData(ClipboardData(text: value));
    _toast('复制成功');
  }

  void _toast(String message) {
    if (!mounted) return;
    AppToast.show(context, message);
  }

  void _handleOrder() {
    context.push(
      '/submit-order?couponId=${Uri.encodeComponent(widget.couponId)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.isNotEmpty
        ? widget.title
        : _coupon?.couponName ?? '';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: Navigator.of(context).pop,
          icon: const Icon(
            Icons.chevron_left,
            color: Color(0xFF333333),
            size: 32,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 70,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF4F4F4))),
          ),
          child: Center(
            child: GestureDetector(
              onTap: _coupon == null ? null : _handleOrder,
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '立即团购',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
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
    return _CouponContent(coupon: _coupon!, onCopy: _copyDetail);
  }
}

class _CouponContent extends StatelessWidget {
  const _CouponContent({required this.coupon, required this.onCopy});

  final CouponDetail coupon;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 188.5,
            width: double.infinity,
            child: coupon.imageUrl.isEmpty
                ? Container(color: const Color(0xFFF5F5F5))
                : Image.network(
                    coupon.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Container(color: const Color(0xFFF5F5F5)),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 53.5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '团购价：',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brand,
                        ),
                      ),
                      Text(
                        '￥${_money(coupon.couponPrice)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brand,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '原价：￥${_money(coupon.oriPrice)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF999999),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _DiscountBadge(rate: coupon.offRate),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFE7E7E7)),
        SizedBox(
          height: 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '团购详情',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onCopy,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '复制',
                    style: TextStyle(fontSize: 14, color: AppTheme.brand),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...coupon.items.map((item) => _CouponDetailRow(item: item)),
      ],
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.rate});

  final int rate;

  @override
  Widget build(BuildContext context) {
    final display = rate == 0 ? '--' : '$rate';
    return Container(
      width: 70,
      height: 40,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0x26FF9809),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                display,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF9809),
                  height: 1,
                ),
              ),
              const SizedBox(width: 2),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '%',
                      style: TextStyle(
                        fontSize: 8,
                        color: Color(0xFFFF9809),
                        height: 1,
                      ),
                    ),
                    Text(
                      'OFF',
                      style: TextStyle(
                        fontSize: 8,
                        color: Color(0xFFFF9809),
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CouponDetailRow extends StatelessWidget {
  const _CouponDetailRow({required this.item});

  final CouponDetailItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 30,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Text('·', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    item.goodsName.isEmpty ? '--' : item.goodsName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${item.quantity.isEmpty ? '--' : item.quantity}${item.unit.isEmpty ? '--' : item.unit}',
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

String _money(double value) {
  if (value % 1 == 0) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
