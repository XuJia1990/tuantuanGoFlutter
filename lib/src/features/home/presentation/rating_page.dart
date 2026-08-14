import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/ui/app_toast.dart';
import '../data/home_models.dart';

class RatingPage extends ConsumerStatefulWidget {
  const RatingPage({required this.shopId, required this.shopName, super.key});

  final String shopId;
  final String shopName;

  @override
  ConsumerState<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends ConsumerState<RatingPage> {
  double _rating = 0;
  String _environment = '';
  String _service = '';
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    if (_rating == 0) {
      _toast('请进行总体评分');
      return;
    }
    if (_environment.isEmpty) {
      _toast('请进行环境评分');
      return;
    }
    if (_service.isEmpty) {
      _toast('请进行服务评分');
      return;
    }

    final userId = await ref.read(appStorageProvider).getUserId();
    if (userId == null || userId.isEmpty) {
      _toast('请先登录');
      return;
    }

    setState(() => _submitting = true);
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get(
            TuanTuanEndpoints.insertRating,
            query: {
              'shopId': widget.shopId,
              'userId': userId,
              'rating': _ratingText(_rating),
              'environRating': _binaryRating(_environment),
              'serviceRating': _binaryRating(_service),
            },
          );
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!mounted) return;
      if (envelope.isSuccess) {
        _toast('评分成功');
        context.pop(true);
      } else {
        _toast(envelope.message ?? '评分失败');
      }
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  int _binaryRating(String value) => value == '差' ? 0 : 1;

  String _ratingText(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  void _toast(String message) {
    AppToast.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => context.pop(),
          child: const Text('取消', style: TextStyle(color: Color(0xFF333333))),
        ),
        leadingWidth: 66,
        title: const Text(
          '店铺评分',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
        children: [
          Row(
            children: [
              Image.asset(
                'assets/static/image/shop.png',
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          _ScoreRow(
            title: '总体：',
            child: _OverallRating(
              value: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
          ),
          _ScoreRow(
            title: '环境：',
            child: _RatingChips(
              value: _environment,
              onChanged: (value) => setState(() => _environment = value),
            ),
          ),
          _ScoreRow(
            title: '服务：',
            child: _RatingChips(
              value: _service,
              onChanged: (value) => setState(() => _service = value),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: GestureDetector(
            onTap: _submitting ? null : _submit,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _submitting ? null : AppTheme.brandGradient,
                color: _submitting ? const Color(0xFFCCCCCC) : null,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                _submitting ? '发布中...' : '发布',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                color: AppTheme.textPrimary,
                height: 1.9,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _OverallRating extends StatelessWidget {
  const _OverallRating({required this.value, required this.onChanged});

  static const _labels = ['很糟糕', '较差', '一般', '还可以', '很棒'];
  static const double _itemWidth = 56;
  static const double _starSize = 38;

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _itemWidth * _labels.length,
      child: Row(
        children: [
          for (var index = 0; index < _labels.length; index++)
            SizedBox(
              width: _itemWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HalfStarButton(
                    index: index,
                    value: value,
                    size: _starSize,
                    onChanged: onChanged,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _labels[index],
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
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

class _HalfStarButton extends StatelessWidget {
  const _HalfStarButton({
    required this.index,
    required this.value,
    required this.size,
    required this.onChanged,
  });

  final int index;
  final double value;
  final double size;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final fill = (value - index).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final isLeftHalf = details.localPosition.dx <= size / 2;
        onChanged(index + (isLeftHalf ? .5 : 1.0));
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Icon(Icons.star, color: const Color(0xFFB2B2B2), size: size),
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: fill,
                child: Icon(Icons.star, color: AppTheme.brand, size: size),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingChips extends StatelessWidget {
  const _RatingChips({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = ['差', '一般', '很棒'];
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: [
        for (final item in items)
          ChoiceChip(
            label: Text(item),
            selected: value == item,
            selectedColor: const Color(0xFFFFE5D7),
            checkmarkColor: AppTheme.brand,
            labelStyle: TextStyle(
              color: value == item ? AppTheme.brand : AppTheme.textPrimary,
            ),
            side: BorderSide(
              color: value == item ? AppTheme.brand : const Color(0xFFE5E5E5),
            ),
            onSelected: (_) => onChanged(item),
          ),
      ],
    );
  }
}
