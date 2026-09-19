class MemberActivitySummary {
  const MemberActivitySummary({
    required this.activityId,
    required this.shopId,
    required this.activityType,
    required this.activityName,
    required this.imageUrl,
    required this.startTime,
    required this.endTime,
    required this.active,
  });

  final String activityId;
  final String shopId;
  final String activityType;
  final String activityName;
  final String imageUrl;
  final String startTime;
  final String endTime;
  final bool active;

  factory MemberActivitySummary.fromJson(Map<String, dynamic> json) {
    return MemberActivitySummary(
      activityId: json['activityId']?.toString() ?? '',
      shopId: json['shopId']?.toString() ?? '',
      activityType: json['activityType']?.toString() ?? '',
      activityName: json['activityName']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      active: _asBool(json['activeFlg']),
    );
  }
}

class MemberActivityStamp {
  const MemberActivityStamp({
    required this.number,
    required this.collected,
    required this.hasReward,
  });

  final int number;
  final bool collected;
  final bool hasReward;

  factory MemberActivityStamp.fromJson(Map<String, dynamic> json) {
    return MemberActivityStamp(
      number: _asInt(json['stampNo']),
      collected: _asBool(json['collected']),
      hasReward: _asBool(json['hasReward']),
    );
  }
}

class MemberActivityReward {
  const MemberActivityReward({
    required this.rewardId,
    required this.requiredProgress,
    required this.requiredStampNo,
    required this.name,
    required this.content,
    required this.imageUrl,
    required this.claimable,
    required this.claimed,
  });

  final String rewardId;
  final int requiredProgress;
  final int requiredStampNo;
  final String name;
  final String content;
  final String imageUrl;
  final bool claimable;
  final bool claimed;

  factory MemberActivityReward.fromJson(Map<String, dynamic> json) {
    return MemberActivityReward(
      rewardId: json['rewardId']?.toString() ?? '',
      requiredProgress: _asInt(json['requiredProgress']),
      requiredStampNo: _asInt(json['requiredStampNo']),
      name: json['rewardName']?.toString() ?? '',
      content: json['rewardContent']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      claimable: _asBool(json['claimable']),
      claimed: _asBool(json['claimed']),
    );
  }
}

class MemberActivityDetail {
  const MemberActivityDetail({
    required this.activityId,
    required this.shopId,
    required this.activityType,
    required this.activityName,
    required this.imageUrl,
    required this.startTime,
    required this.endTime,
    required this.active,
    required this.notes,
    required this.totalStamps,
    required this.collectedCount,
    required this.stamps,
    required this.rewards,
  });

  final String activityId;
  final String shopId;
  final String activityType;
  final String activityName;
  final String imageUrl;
  final String startTime;
  final String endTime;
  final bool active;
  final String notes;
  final int totalStamps;
  final int collectedCount;
  final List<MemberActivityStamp> stamps;
  final List<MemberActivityReward> rewards;

  bool get isComplete => totalStamps > 0 && collectedCount >= totalStamps;

  factory MemberActivityDetail.fromJson(Map<String, dynamic> json) {
    final activityData = json['activityData'];
    final typedData = activityData is Map
        ? Map<String, dynamic>.from(activityData)
        : const <String, dynamic>{};
    final rawStamps = typedData['stamps'] ?? json['stamps'];
    final stamps = rawStamps is List
        ? rawStamps
              .whereType<Map>()
              .map(
                (item) => MemberActivityStamp.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <MemberActivityStamp>[];
    final totalStamps = _asInt(typedData['totalStamps'] ?? json['totalStamps']);
    if (stamps.isEmpty && totalStamps > 0) {
      stamps.addAll(
        List<MemberActivityStamp>.generate(
          totalStamps,
          (index) => MemberActivityStamp(
            number: index + 1,
            collected: false,
            hasReward: false,
          ),
        ),
      );
    }

    final rawRewards = json['rewards'];
    return MemberActivityDetail(
      activityId: json['activityId']?.toString() ?? '',
      shopId: json['shopId']?.toString() ?? '',
      activityType: json['activityType']?.toString() ?? '',
      activityName: json['activityName']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      active: _asBool(json['activeFlg']),
      notes: json['notes']?.toString() ?? '',
      totalStamps: totalStamps,
      collectedCount: _asInt(
        typedData['collectedCount'] ?? json['collectedCount'],
      ),
      stamps: stamps,
      rewards: rawRewards is List
          ? rawRewards
                .whereType<Map>()
                .map(
                  (item) => MemberActivityReward.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class ActivityRewardClaimResult {
  const ActivityRewardClaimResult({
    required this.claimId,
    required this.rewardId,
    required this.couponId,
    required this.orderMgmtId,
    required this.claimed,
  });

  final String claimId;
  final String rewardId;
  final String couponId;
  final String orderMgmtId;
  final bool claimed;

  factory ActivityRewardClaimResult.fromJson(Map<String, dynamic> json) {
    return ActivityRewardClaimResult(
      claimId: json['claimId']?.toString() ?? '',
      rewardId: json['rewardId']?.toString() ?? '',
      couponId: json['couponId']?.toString() ?? '',
      orderMgmtId: json['orderMgmtId']?.toString() ?? '',
      claimed: _asBool(json['claimed']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}
