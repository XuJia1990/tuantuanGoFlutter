import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_assets.dart';
import '../data/home_models.dart';

class ShopSummaryCard extends StatelessWidget {
  const ShopSummaryCard({required this.shop, required this.onTap, super.key});

  final ShopSummary shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        height: 108,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 88,
                height: 88,
                child: shop.imageUrl.isEmpty
                    ? Container(
                        color: const Color(0xFFF0F0F0),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: Color(0xFFAAAAAA),
                        ),
                      )
                    : Image.network(
                        shop.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFFF0F0F0),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 58),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name.isEmpty ? '未命名店铺' : shop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _RatingStars(value: shop.rating),
                            const SizedBox(width: 4),
                            Text(
                              shop.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.brand,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          shop.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (shop.couponPrice != null &&
                                shop.couponPrice!.isNotEmpty) ...[
                              Image.asset(
                                'assets/static/image/index-icon-1.png',
                                width: 16,
                                height: 16,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '￥${shop.couponPrice}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.brandEnd,
                                  ),
                                ),
                              ),
                            ] else
                              const Flexible(
                                child: Text(
                                  '本月优惠卷:暂无',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.brandEnd,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${shop.distance}m',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({this.search = false, super.key});

  final bool search;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            search ? 'assets/static/image/search.png' : AppAssets.empty,
            width: search ? 50 : 100,
            height: search ? 50 : 83,
          ),
          const SizedBox(height: 10),
          Text(
            search ? '当前搜索无相关匹配结果' : '这里还什么都没有呢~',
            style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 1; index <= 5; index++)
          Padding(
            padding: EdgeInsets.only(right: index == 5 ? 0 : 2.5),
            child: _RatingStar(active: index <= value.round()),
          ),
      ],
    );
  }
}

class _RatingStar extends StatelessWidget {
  const _RatingStar({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: active ? AppTheme.brand : const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Icon(Icons.star, size: 12, color: Colors.white),
    );
  }
}
