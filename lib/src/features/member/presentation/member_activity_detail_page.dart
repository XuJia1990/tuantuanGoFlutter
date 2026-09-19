import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/ui/app_toast.dart';
import '../../../shared/widgets/cached_image.dart';
import '../data/member_activity_models.dart';
import '../data/member_activity_repository.dart';

class MemberActivityDetailPage extends ConsumerStatefulWidget {
  const MemberActivityDetailPage({required this.extra, super.key});

  final Object? extra;

  @override
  ConsumerState<MemberActivityDetailPage> createState() =>
      _MemberActivityDetailPageState();
}

class _MemberActivityDetailPageState
    extends ConsumerState<MemberActivityDetailPage> {
  late final Map<String, dynamic> _routeData;
  final Set<String> _claimingRewards = {};
  final Map<String, String> _claimRequestIds = {};
  MemberActivityDetail? _detail;
  bool _loading = true;
  String? _error;

  String get _activityId => _routeData['activityId']?.toString() ?? '';
  String get _shopName => _routeData['shopName']?.toString() ?? '九年食班广小路店';
  String get _shopImageUrl => _routeData['shopImageUrl']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _routeData = widget.extra is Map
        ? Map<String, dynamic>.from(widget.extra! as Map)
        : <String, dynamic>{};
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (_activityId.isEmpty) {
      setState(() {
        _loading = false;
        _error = '活动信息不完整';
      });
      return;
    }
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final detail = await ref
          .read(memberActivityRepositoryProvider)
          .getDetail(_activityId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (error is MemberActivityApiException && error.requiresLogin) {
        await ref.read(appStorageProvider).clearAuth();
        ref.read(authRevisionProvider.notifier).bump();
        if (!mounted) return;
        AppToast.show(context, '登录状态已过期，请重新登录');
        await context.push('/login');
        if (!mounted) return;
        final signedIn = await ref.read(appStorageProvider).isSignedIn();
        if (signedIn) {
          _load();
        } else {
          setState(() {
            _loading = false;
            _error = '请登录后查看活动详情';
          });
        }
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openSeal() async {
    final detail = _detail;
    if (detail == null || !detail.active || detail.isComplete) return;
    final updated = await context.push<MemberActivityDetail>(
      '/seal-debug',
      extra: {'activityId': detail.activityId, 'shopId': detail.shopId},
    );
    if (!mounted || updated == null) return;
    setState(() => _detail = updated);
  }

  Future<void> _claimReward(MemberActivityReward reward) async {
    if (reward.claimed ||
        !reward.claimable ||
        _claimingRewards.contains(reward.rewardId)) {
      return;
    }
    setState(() => _claimingRewards.add(reward.rewardId));
    try {
      final result = await ref
          .read(memberActivityRepositoryProvider)
          .claimReward(
            activityId: _activityId,
            rewardId: reward.rewardId,
            requestId: _claimRequestIds.putIfAbsent(
              reward.rewardId,
              () => newActivityRequestId('claim'),
            ),
          );
      _claimRequestIds.remove(reward.rewardId);
      if (!mounted) return;
      AppToast.show(context, result.claimed ? '领取成功，奖品已放入券包' : '领取失败');
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      AppToast.show(context, error.toString());
    } finally {
      if (mounted) setState(() => _claimingRewards.remove(reward.rewardId));
    }
  }

  Future<void> _confirmClaimReward(MemberActivityReward reward) async {
    if (reward.claimed ||
        !reward.claimable ||
        _claimingRewards.contains(reward.rewardId)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '温馨提示',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          '是否领取优惠券？',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Color(0xFF555555)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          SizedBox(
            width: 112,
            height: 44,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF2F2F2),
                foregroundColor: const Color(0xFF666666),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            height: 44,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('确认'),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _claimReward(reward);
  }

  void _pop() {
    context.pop(_detail);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _detail == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.brand),
        ),
      );
    }
    if (_detail == null) {
      return Scaffold(
        backgroundColor: AppTheme.pageBg,
        appBar: AppBar(),
        body: _DetailState(message: _error ?? '活动加载失败', onRetry: _load),
      );
    }

    final detail = _detail!;
    final description = detail.notes.isNotEmpty
        ? detail.notes
        : _detailRewardSummary(detail.rewards);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _ActivityHeader(
                detail: detail,
                description: description,
                onBack: _pop,
              ),
            ),
            SliverToBoxAdapter(
              child: _ShopHeader(name: _shopName, imageUrl: _shopImageUrl),
            ),
            if (detail.rewards.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    '暂无奖品',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF999999)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                sliver: SliverList.builder(
                  itemCount: detail.rewards.length,
                  itemBuilder: (context, index) {
                    final reward = detail.rewards[index];
                    return _RewardRow(
                      reward: reward,
                      claiming: _claimingRewards.contains(reward.rewardId),
                      onClaim: () => _confirmClaimReward(reward),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
          ],
        ),
        bottomNavigationBar: _BottomAction(
          enabled: detail.active && !detail.isComplete,
          text: !detail.active
              ? '活动未开始'
              : detail.isComplete
              ? '已集满印章'
              : '开始集印章',
          onPressed: _openSeal,
        ),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({
    required this.detail,
    required this.description,
    required this.onBack,
  });

  final MemberActivityDetail detail;
  final String description;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final stampCardHeight = _StampCard.heightFor(detail.totalStamps);
    return SizedBox(
      height: 163 + stampCardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            child: _ActivityHero(
              title: detail.activityName,
              description: description,
              imageUrl: detail.imageUrl,
              onBack: onBack,
            ),
          ),
          Positioned(
            left: 0,
            top: 163,
            right: 0,
            child: _StampCard(detail: detail),
          ),
        ],
      ),
    );
  }
}

class _ActivityHero extends StatelessWidget {
  const _ActivityHero({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.onBack,
  });

  final String title;
  final String description;
  final String imageUrl;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 211,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isEmpty)
            const _ActivityImagePlaceholder()
          else
            AppCachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.05),
              errorWidget: const _ActivityImagePlaceholder(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x12000000),
                  Color(0x24000000),
                  Color(0x9A000000),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00FFFFFF),
                    Color(0x24FFFFFF),
                    Color(0xB8FFFFFF),
                    Color(0xFFFFFFFF),
                  ],
                  stops: [0, 0.26, 0.78, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: topInset + 8,
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 28,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 17,
            right: 16,
            bottom: 65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w400,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
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

class _ActivityImagePlaceholder extends StatelessWidget {
  const _ActivityImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFB8B8B8),
      child: Center(
        child: Icon(Icons.image_outlined, size: 40, color: Color(0xFFE7E7E7)),
      ),
    );
  }
}

class _StampCard extends StatelessWidget {
  const _StampCard({required this.detail});

  static const _columns = 5;
  static const _cellHeight = 56.0;
  static const _rowSpacing = 9.0;
  static const _surroundingHeight = 72.0;

  final MemberActivityDetail detail;

  static int rowCountFor(int totalStamps) {
    if (totalStamps <= 0) return 1;
    return (totalStamps + _columns - 1) ~/ _columns;
  }

  static double heightFor(int totalStamps) {
    final rows = rowCountFor(totalStamps);
    return _surroundingHeight + rows * _cellHeight + (rows - 1) * _rowSpacing;
  }

  @override
  Widget build(BuildContext context) {
    final rowCount = rowCountFor(detail.totalStamps);
    return Container(
      height: heightFor(detail.totalStamps),
      margin: const EdgeInsets.fromLTRB(13, 0, 13, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F3),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFFFE0CA), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _StampPatternPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 11),
          child: Column(
            children: [
              for (var row = 0; row < rowCount; row++) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var column = 0; column < _columns; column++)
                      _stampCell(row * _columns + column + 1),
                  ],
                ),
                if (row < rowCount - 1) const SizedBox(height: _rowSpacing),
              ],
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: Color(0xFFFF5A19),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _detailTimeText(detail.endTime),
                    style: const TextStyle(
                      color: Color(0xFFFF5A19),
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stampCell(int number) {
    if (number > detail.totalStamps) {
      return const SizedBox(width: 56, height: 56);
    }
    MemberActivityStamp? stamp;
    for (final item in detail.stamps) {
      if (item.number == number) {
        stamp = item;
        break;
      }
    }
    return _StampCell(
      index: number,
      collected: stamp?.collected ?? number <= detail.collectedCount,
      isGift: stamp?.hasReward ?? false,
    );
  }
}

class _StampCell extends StatelessWidget {
  const _StampCell({
    required this.index,
    required this.collected,
    required this.isGift,
  });

  final int index;
  final bool collected;
  final bool isGift;

  @override
  Widget build(BuildContext context) {
    if (collected) {
      return Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFA21A), Color(0xFFFF4D0A)],
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.ramen_dining_rounded,
            color: Color(0xFFFF4E0A),
            size: 32,
          ),
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFE2CE)),
      ),
      child: isGift
          ? const Icon(
              Icons.card_giftcard_rounded,
              color: Color(0xFFFF6B3B),
              size: 31,
            )
          : Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFFFF4D0A),
                fontSize: 19,
                height: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

class _StampPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFE6D5).withValues(alpha: 0.68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 42.0;
    for (var y = -10.0; y < size.height + step; y += step) {
      for (var x = -8.0; x < size.width + step; x += step) {
        final shift = ((y / step).round().isOdd) ? 20.0 : 0.0;
        final center = Offset(x + shift, y);
        canvas.drawCircle(center, 11, paint);
        canvas.drawCircle(center, 16, paint);
        canvas.drawLine(
          center + const Offset(-21, -7),
          center + const Offset(-12, -14),
          paint,
        );
        canvas.drawLine(
          center + const Offset(12, 14),
          center + const Offset(21, 7),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.name, required this.imageUrl});

  final String name;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 28, 14, 9),
      child: Row(
        children: [
          _ShopLogo(imageUrl: imageUrl),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF222222),
                fontSize: 17,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopLogo extends StatelessWidget {
  const _ShopLogo({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: const Text(
        '九年\n食班',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF257B54),
          fontSize: 8,
          height: 1.05,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? fallback
          : AppCachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: fallback,
            ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.reward,
    required this.claiming,
    required this.onClaim,
  });

  final MemberActivityReward reward;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final available = reward.claimable && !reward.claimed && !claiming;
    final unreached = !reward.claimable && !reward.claimed;
    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: unreached || reward.claimed
                      ? const Color(0xFFF1F1F1)
                      : const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${reward.requiredStampNo}枚印章可领取',
                  style: TextStyle(
                    color: unreached || reward.claimed
                        ? const Color(0xFF999999)
                        : const Color(0xFFFF671F),
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                reward.name.isEmpty ? '活动奖品' : reward.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unreached || reward.claimed
                      ? const Color(0xFF888888)
                      : const Color(0xFF222222),
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reward.claimed
                    ? '优惠券已领取'
                    : claiming
                    ? '领取中...'
                    : unreached
                    ? '尚未达到领取条件'
                    : reward.content.isEmpty
                    ? '点击领取优惠券'
                    : reward.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: available
                      ? const Color(0xFFFF5A19)
                      : const Color(0xFF999999),
                  fontSize: 12,
                  height: 1,
                  fontWeight: available ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _RewardImage(reward: reward, unreached: unreached),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: available ? onClaim : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 106),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: unreached ? Opacity(opacity: 0.58, child: content) : content,
        ),
      ),
    );
  }
}

class _RewardImage extends StatelessWidget {
  const _RewardImage({required this.reward, required this.unreached});

  final MemberActivityReward reward;
  final bool unreached;

  @override
  Widget build(BuildContext context) {
    final image = reward.imageUrl.isEmpty
        ? const _RewardImagePlaceholder()
        : AppCachedNetworkImage(
            imageUrl: reward.imageUrl,
            width: 121,
            height: 80,
            fit: BoxFit.cover,
            errorWidget: const _RewardImagePlaceholder(),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 121,
        height: 80,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (unreached)
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: image,
              )
            else
              image,
            if (reward.claimed) ...[
              const ColoredBox(color: Color(0x73000000)),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xD9FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '已领取',
                    style: TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RewardImagePlaceholder extends StatelessWidget {
  const _RewardImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF1F1F1),
      child: Center(
        child: Icon(Icons.image_outlined, size: 28, color: Color(0xFFBDBDBD)),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.enabled,
    required this.text,
    required this.onPressed,
  });

  final bool enabled;
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            height: 45,
            decoration: BoxDecoration(
              gradient: enabled
                  ? const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFF4A0A)],
                    )
                  : null,
              color: enabled ? null : const Color(0xFFD8D8D8),
            ),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _detailRewardSummary(List<MemberActivityReward> rewards) {
  if (rewards.isEmpty) return '完成集章即可领取活动奖品';
  return rewards
      .map((reward) => '${reward.requiredStampNo}枚领${reward.name}')
      .join('，');
}

String _detailTimeText(String raw) {
  if (raw.isEmpty) return '活动截止时间未设置';
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})',
  ).firstMatch(raw);
  if (match == null) return '$raw 活动为止';
  return '${match.group(1)}年${int.parse(match.group(2)!)}月'
      '${int.parse(match.group(3)!)}日 ${match.group(4)}时'
      '${match.group(5)}分活动为止';
}

class _DetailState extends StatelessWidget {
  const _DetailState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFAAAAAA),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777)),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}
