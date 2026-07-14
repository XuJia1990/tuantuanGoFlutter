import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import '../../../core/storage/app_storage.dart';
import '../../home/data/home_models.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  ProfileUser? _user;
  String _avatar = '';
  bool _hasLoaded = false;
  ProviderSubscription<int>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<int>(authRevisionProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProfile();
      });
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _authSubscription?.close();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final storage = ref.read(appStorageProvider);
    final rawDetail = await storage.getUserDetail();
    final avatar = await storage.getUserAvatar();
    final localUser = ProfileUser.tryParse(rawDetail);
    if (mounted) {
      setState(() {
        _user = localUser;
        _avatar = avatar ?? localUser?.avatar ?? '';
        _hasLoaded = true;
      });
    }

    final token = await storage.getAccessToken();
    if (token == null || token.isEmpty) return;
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get(TuanTuanEndpoints.userDetail);
      final envelope = ApiEnvelope.parse<ProfileUser>(
        raw,
        (data) => ProfileUser.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      if (!envelope.isSuccess || envelope.data == null) return;
      final user = envelope.data!;
      await storage.saveUserDetail(jsonEncode(user.raw));
      if (user.avatar.isNotEmpty) {
        await storage.saveUserAvatar(user.avatar);
      }
      if (mounted) {
        setState(() {
          _user = user;
          _avatar = user.avatar;
        });
      }
    } catch (_) {
      // uni-app 这里失败时保持本地缓存展示，不打断页面使用。
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _requireLogin() {
    if (_user != null) return true;
    _toast('请登录后使用此功能');
    return false;
  }

  void _goLogin() {
    context.push('/login');
  }

  void _pushLoginRequired(String path) {
    if (!_requireLogin()) return;
    context.push(path);
  }

  void _showCodeSheet() {
    if (!_requireLogin()) return;
    final pageContext = context;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CodeSheetItem(
                text: '会员码',
                onTap: () {
                  Navigator.of(context).pop();
                  pageContext.push('/member-code');
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F1F1)),
              _CodeSheetItem(
                text: '付款码',
                onTap: () {
                  Navigator.of(context).pop();
                  pageContext.push('/pay-code');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _scan() {
    if (!_requireLogin()) return;
    context.push('/scan-code');
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      body: !_hasLoaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppTheme.brand,
              onRefresh: _loadProfile,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (user == null)
                    _GuestHeader(onLogin: _goLogin)
                  else
                    _UserHeader(
                      user: user,
                      avatar: _avatar,
                      onEdit: () => _pushLoginRequired('/edit-profile'),
                      onCode: _showCodeSheet,
                    ),
                  Transform.translate(
                    offset: const Offset(0, -15),
                    child: _ProfileContent(
                      isLoggedIn: user != null,
                      onScan: _scan,
                      items: [
                        _ProfileMenuGroup(
                          items: [
                            _ProfileMenuItem(
                              icon: 'assets/static/image/my-1.png',
                              title: '已购券包',
                              onTap: () =>
                                  _pushLoginRequired('/purchased-coupons'),
                            ),
                            _ProfileMenuItem(
                              icon: 'assets/static/image/my-2.png',
                              title: '我的收藏',
                              onTap: () => _pushLoginRequired('/my-collection'),
                            ),
                          ],
                        ),
                        _ProfileMenuGroup(
                          items: [
                            _ProfileMenuItem(
                              icon: 'assets/static/image/my-3.png',
                              title: '设置',
                              onTap: () => _pushLoginRequired('/settings'),
                            ),
                            _ProfileMenuItem(
                              icon: 'assets/static/image/my-4.png',
                              title: '关于我们',
                              onTap: () => _pushLoginRequired('/about-us'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

class ProfileUser {
  const ProfileUser({
    required this.raw,
    required this.userId,
    required this.mobile,
    required this.nickname,
    required this.showId,
    required this.avatar,
    required this.isManager,
    required this.shopName,
    required this.salesCount,
  });

  final Map<String, dynamic> raw;
  final String userId;
  final String mobile;
  final String nickname;
  final String showId;
  final String avatar;
  final bool isManager;
  final String shopName;
  final int salesCount;

  static ProfileUser? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      return ProfileUser.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return null;
    }
  }

  factory ProfileUser.fromJson(Map<String, dynamic> json) {
    return ProfileUser(
      raw: json,
      userId: json['userId']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '--',
      showId: json['showId']?.toString() ?? '--',
      avatar: json['avatar']?.toString() ?? '',
      isManager: json['isManager'] == true || json['isManager'] == 1,
      shopName: json['shopName']?.toString() ?? '',
      salesCount: _asInt(json['salesCount']) ?? 0,
    );
  }
}

class _GuestHeader extends StatelessWidget {
  const _GuestHeader({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 216,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.brand, AppTheme.brandEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, .91],
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            right: -35,
            bottom: -15,
            width: 150,
            height: 150,
            child: Image.asset('assets/static/image/my-img.png'),
          ),
          Positioned(
            left: 20,
            bottom: 95,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Hi～欢迎来到团团GO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '人生苦短，幸好还好有烤肉火锅麻辣香锅',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Color(0xB3FFFFFF)),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            bottom: 35,
            child: GestureDetector(
              onTap: onLogin,
              child: Container(
                width: 112,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text(
                  '登录/注册',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.brand,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.user,
    required this.avatar,
    required this.onEdit,
    required this.onCode,
  });

  final ProfileUser user;
  final String avatar;
  final VoidCallback onEdit;
  final VoidCallback onCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.brand, AppTheme.brandEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, .91],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          alignment: Alignment.center,
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF834D), Color(0xFFFFB854)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: avatar.isNotEmpty
                              ? Image.network(
                                  avatar,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _DefaultAvatar(size: 56),
                                )
                              : _DefaultAvatar(size: 56),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF834D), AppTheme.brand],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Image.asset(
                              'assets/static/image/pencil82.png',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  user.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID：${user.showId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          ),
          Positioned(
            top: 30,
            right: 5,
            child: GestureDetector(
              onTap: onCode,
              child: SizedBox(
                width: 25,
                height: 25,
                child: Image.asset('assets/static/image/ewCode.png'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/static/image/header.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.isLoggedIn,
    required this.onScan,
    required this.items,
  });

  final bool isLoggedIn;
  final VoidCallback onScan;
  final List<_ProfileMenuGroup> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.pageBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.5)),
      ),
      child: Column(
        children: [
          if (isLoggedIn) ...[
            GestureDetector(
              onTap: onScan,
              child: Container(
                width: double.infinity,
                height: 50,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/static/image/s-code.png',
                      width: 23,
                      height: 23,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '扫一扫',
                      style: TextStyle(fontSize: 17, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
          for (final group in items) ...[group, const SizedBox(height: 16)],
        ],
      ),
    );
  }
}

class _ProfileMenuGroup extends StatelessWidget {
  const _ProfileMenuGroup({required this.items});

  final List<_ProfileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(child: items[i]),
            if (i < items.length - 1)
              const Divider(height: 1, color: Color(0xFFF7F7F7)),
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final String icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Image.asset(icon, width: 25, height: 25),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.brand,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chevron_right,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeSheetItem extends StatelessWidget {
  const _CodeSheetItem({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
          ),
        ),
      ),
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
