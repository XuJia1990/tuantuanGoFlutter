import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_go_flutter/src/features/member/data/member_activity_models.dart';
import 'package:tuantuan_go_flutter/src/features/member/data/member_activity_repository.dart';

void main() {
  test('parses stamp-card detail from activityData', () {
    final detail = MemberActivityDetail.fromJson({
      'activityId': 1,
      'shopId': 268,
      'activityType': 'STAMP_CARD',
      'activityName': '测试集章卡',
      'imageUrl': 'https://cdn.example.com/activity.jpg',
      'endTime': '2027-09-29 23:59:59',
      'activeFlg': true,
      'activityData': {
        'totalStamps': 10,
        'collectedCount': 1,
        'stamps': [
          {'stampNo': 1, 'collected': true, 'hasReward': true},
          {'stampNo': 2, 'collected': false, 'hasReward': false},
        ],
      },
      'totalStamps': 99,
      'collectedCount': 99,
      'rewards': [
        {
          'rewardId': 101,
          'requiredProgress': 1,
          'requiredStampNo': 1,
          'rewardName': '测试奖品',
          'rewardContent': '奖品说明',
          'imageUrl': 'https://cdn.example.com/reward.jpg',
          'claimable': true,
          'claimed': false,
        },
      ],
    });

    expect(detail.activityId, '1');
    expect(detail.shopId, '268');
    expect(detail.imageUrl, 'https://cdn.example.com/activity.jpg');
    expect(detail.totalStamps, 10);
    expect(detail.collectedCount, 1);
    expect(detail.stamps.first.collected, isTrue);
    expect(detail.stamps.first.hasReward, isTrue);
    expect(detail.rewards.single.claimable, isTrue);
    expect(
      detail.rewards.single.imageUrl,
      'https://cdn.example.com/reward.jpg',
    );
    expect(detail.isComplete, isFalse);
  });

  test('generates short unique request ids', () {
    final first = newActivityRequestId('stamp');
    final second = newActivityRequestId('stamp');

    expect(first, startsWith('stamp-'));
    expect(first.length, lessThanOrEqualTo(64));
    expect(first, isNot(second));
  });
}
