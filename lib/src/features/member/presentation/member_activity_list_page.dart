import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/cached_image.dart';
import '../data/member_activity_models.dart';
import '../data/member_activity_repository.dart';

class MemberActivityListPage extends ConsumerStatefulWidget {
  const MemberActivityListPage({
    required this.params,
    required this.extraShops,
    super.key,
  });

  final Map<String, String> params;
  final Object? extraShops;

  @override
  ConsumerState<MemberActivityListPage> createState() =>
      _MemberActivityListPageState();
}

class _MemberActivityListPageState
    extends ConsumerState<MemberActivityListPage> {
  late final List<_ActivityShop> _shops;
  final List<_MemberActivity> _activities = [];
  String _selectedShopId = 'all';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _shops = _parseShops(widget.extraShops, widget.params['shops']);
    _load();
  }

  List<_MemberActivity> get _visibleActivities {
    if (_selectedShopId == 'all') return _activities;
    return _activities
        .where((activity) => activity.shop.shopId == _selectedShopId)
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(memberActivityRepositoryProvider);
      final groups = await Future.wait([
        for (final shop in _shops.where((shop) => shop.shopId.isNotEmpty))
          repository
              .listByShop(shop.shopId)
              .then(
                (items) => [
                  for (final item in items)
                    _MemberActivity(summary: item, shop: shop),
                ],
              ),
      ]);
      if (!mounted) return;
      setState(() {
        _activities
          ..clear()
          ..addAll(groups.expand((items) => items));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openActivity(_MemberActivity activity) async {
    final detail = await context.push<MemberActivityDetail>(
      '/member-activity-detail',
      extra: <String, dynamic>{
        'activityId': activity.summary.activityId,
        'shopId': activity.summary.shopId,
        'title': activity.summary.activityName,
        'activityImageUrl': activity.summary.imageUrl,
        'shopName': activity.shop.name,
        'shopImageUrl': activity.shop.imageUrl,
      },
    );
    if (!mounted || detail == null) return;
    setState(() => activity.detail = detail);
  }

  @override
  Widget build(BuildContext context) {
    final activities = _visibleActivities;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leadingWidth: 48,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: Color(0xFF111111),
            size: 30,
          ),
        ),
        centerTitle: true,
        title: const Text(
          '活动列表',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          _ShopFilterBar(
            shops: _shops,
            selectedShopId: _selectedShopId,
            onChanged: (shopId) => setState(() => _selectedShopId = shopId),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.brand),
                  )
                : _error != null
                ? _ActivityState(
                    icon: Icons.wifi_off_rounded,
                    text: _error!,
                    actionText: '重新加载',
                    onAction: _load,
                  )
                : activities.isEmpty
                ? const _ActivityState(
                    icon: Icons.local_activity_outlined,
                    text: '暂无活动',
                  )
                : RefreshIndicator(
                    color: AppTheme.brand,
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
                      itemCount: activities.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        return _ActivityCard(
                          activity: activity,
                          onTap: () => _openActivity(activity),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShopFilterBar extends StatelessWidget {
  const _ShopFilterBar({
    required this.shops,
    required this.selectedShopId,
    required this.onChanged,
  });

  final List<_ActivityShop> shops;
  final String selectedShopId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 8),
        children: [
          _ShopFilterChip(
            text: '全部活动',
            active: selectedShopId == 'all',
            onTap: () => onChanged('all'),
          ),
          for (final shop in shops)
            _ShopFilterChip(
              text: shop.name,
              active: selectedShopId == shop.shopId,
              onTap: () => onChanged(shop.shopId),
            ),
        ],
      ),
    );
  }
}

class _ShopFilterChip extends StatelessWidget {
  const _ShopFilterChip({
    required this.text,
    required this.active,
    required this.onTap,
  });

  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 35,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF7900) : const Color(0xFFF1F1F1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF575757),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.onTap});

  final _MemberActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 142,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _ShopLogo(shop: activity.shop),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.summary.activityName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 16,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity.shop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF777777),
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 17),
              if (activity.detail case final detail?)
                _ActivityProgress(detail: detail)
              else
                Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  padding: const EdgeInsets.fromLTRB(15, 10, 15, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Color(0xFFFF6B00),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _listTimeText(activity.summary.endTime),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF7A7A7A),
                            fontSize: 12,
                            height: 1,
                          ),
                        ),
                      ),
                      Text(
                        activity.summary.active ? '进行中' : '未开始',
                        style: const TextStyle(
                          color: Color(0xFFFF4D00),
                          fontSize: 13,
                          height: 1,
                          fontWeight: FontWeight.w500,
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

class _ActivityProgress extends StatelessWidget {
  const _ActivityProgress({required this.detail});

  final MemberActivityDetail detail;

  @override
  Widget build(BuildContext context) {
    final total = detail.totalStamps;
    final progress = total <= 0 ? 0.0 : detail.collectedCount / total;
    return Container(
      constraints: const BoxConstraints(minHeight: 45),
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: progress.clamp(0, 1),
                    backgroundColor: const Color(0xFFFFE4DA),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF6B00),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${detail.collectedCount}/$total',
                style: const TextStyle(
                  color: Color(0xFFFF4D00),
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _rewardSummary(detail.rewards),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF7A7A7A),
                fontSize: 12,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopLogo extends StatelessWidget {
  const _ShopLogo({required this.shop});

  final _ActivityShop shop;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 38,
        height: 38,
        child: shop.imageUrl.isEmpty
            ? Container(
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
              )
            : AppCachedNetworkImage(
                imageUrl: shop.imageUrl,
                fit: BoxFit.cover,
                errorWidget: Container(
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
                ),
              ),
      ),
    );
  }
}

class _ActivityShop {
  const _ActivityShop({
    required this.shopId,
    required this.name,
    required this.imageUrl,
  });

  final String shopId;
  final String name;
  final String imageUrl;
}

class _MemberActivity {
  _MemberActivity({required this.summary, required this.shop});

  final MemberActivitySummary summary;
  final _ActivityShop shop;
  MemberActivityDetail? detail;
}

List<_ActivityShop> _parseShops(Object? extraShops, String? rawShops) {
  final shops = <_ActivityShop>[];

  void addShop(Map<String, dynamic> json, int index) {
    final shopId = json['shopId']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    shops.add(
      _ActivityShop(
        shopId: shopId.isEmpty ? 'shop-$index' : shopId,
        name: name.isEmpty ? '九年食班广小路店' : name,
        imageUrl: json['imageUrl']?.toString() ?? '',
      ),
    );
  }

  if (extraShops is Iterable) {
    var index = 0;
    for (final item in extraShops) {
      if (item is Map) addShop(Map<String, dynamic>.from(item), index);
      index += 1;
    }
  }

  if (shops.isEmpty && rawShops != null && rawShops.isNotEmpty) {
    try {
      final decoded = jsonDecode(rawShops);
      if (decoded is Iterable) {
        var index = 0;
        for (final item in decoded) {
          if (item is Map) addShop(Map<String, dynamic>.from(item), index);
          index += 1;
        }
      }
    } catch (_) {
      // Keep the prototype page usable if the query parameter is malformed.
    }
  }

  return shops;
}

String _listTimeText(String raw) {
  if (raw.isEmpty) return '截止时间未设置';
  final value = raw.length >= 16 ? raw.substring(0, 16) : raw;
  return '截止至 $value';
}

String _rewardSummary(List<MemberActivityReward> rewards) {
  if (rewards.isEmpty) return '暂无奖品说明';
  return rewards
      .map((reward) => '${reward.requiredStampNo}枚领${reward.name}')
      .join('，');
}

class _ActivityState extends StatelessWidget {
  const _ActivityState({
    required this.icon,
    required this.text,
    this.actionText,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFFB5B5B5)),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionText ?? '重试')),
            ],
          ],
        ),
      ),
    );
  }
}
