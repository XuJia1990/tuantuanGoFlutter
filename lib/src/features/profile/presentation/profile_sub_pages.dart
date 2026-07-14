import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import '../../../core/qr/scan_code_parser.dart';
import '../../../core/storage/app_storage.dart';
import '../data/privacy_agreement_text.dart';
import '../../home/data/home_models.dart';
import '../../home/presentation/shop_summary_card.dart';
import 'profile_page.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nicknameController = TextEditingController();
  final _picker = ImagePicker();
  String? _base64;
  bool _loading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _chooseImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() => _base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    if ((_base64 == null || _base64!.isEmpty) && nickname.isEmpty) {
      _toast('请填写修改信息');
      return;
    }
    setState(() => _loading = true);
    final data = <String, dynamic>{};
    if (_base64 != null && _base64!.isNotEmpty) data['base64'] = _base64;
    if (nickname.isNotEmpty) data['nickname'] = nickname;
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(TuanTuanEndpoints.updateUser, data: data);
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!envelope.isSuccess) {
        _toast(envelope.message ?? '修改失败');
        return;
      }
      final detailRaw = await ref
          .read(apiClientProvider)
          .get(TuanTuanEndpoints.userDetail);
      final detail = ApiEnvelope.parse<Map<String, dynamic>>(
        detailRaw,
        (data) => Map<String, dynamic>.from(data as Map),
      );
      if (detail.isSuccess && detail.data != null) {
        await ref
            .read(appStorageProvider)
            .saveUserDetail(jsonEncode(detail.data));
        final avatar = detail.data!['avatar']?.toString() ?? '';
        if (avatar.isNotEmpty) {
          await ref.read(appStorageProvider).saveUserAvatar(avatar);
        }
      }
      _toast('修改成功');
      if (mounted) context.go('/profile');
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileScaffold(
      title: '修改个人信息',
      bottom: _BottomGradientButton(text: '保存', onTap: _loading ? null : _save),
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              _ShadowPanel(
                child: Row(
                  children: [
                    const SizedBox(width: 60, child: Text('头像')),
                    Expanded(
                      child: GestureDetector(
                        onTap: _chooseImage,
                        child: Container(
                          width: 150,
                          height: 150,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7.5),
                            border: Border.all(
                              color: const Color(0xFFEBEBEB),
                              style: BorderStyle.solid,
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: _base64 == null
                              ? const Icon(
                                  Icons.add,
                                  size: 36,
                                  color: Color(0xFFEBEBEB),
                                )
                              : Image.memory(
                                  base64Decode(_base64!.split(',').last),
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _ShadowPanel(
                child: Row(
                  children: [
                    const SizedBox(width: 60, child: Text('昵称')),
                    Expanded(
                      child: TextField(
                        controller: _nicknameController,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '请输入昵称',
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_loading) const _LoadingOverlay(),
        ],
      ),
    );
  }
}

class MemberCodePage extends ConsumerStatefulWidget {
  const MemberCodePage({super.key});

  @override
  ConsumerState<MemberCodePage> createState() => _MemberCodePageState();
}

class _MemberCodePageState extends ConsumerState<MemberCodePage> {
  ProfileUser? _user;
  String _avatar = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = ref.read(appStorageProvider);
    final raw = await storage.getUserDetail();
    final avatar = await storage.getUserAvatar();
    if (!mounted) return;
    setState(() {
      _user = ProfileUser.tryParse(raw);
      _avatar = avatar ?? '';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final qrData = user == null
        ? ''
        : user.mobile.isNotEmpty
        ? '${user.userId},${user.mobile}'
        : user.userId;
    return _ProfileScaffold(
      title: '二维码',
      child: _loading
          ? const _CenteredLoading()
          : user == null || qrData.isEmpty
          ? const EmptyState()
          : ColoredBox(
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 150, 0, 40),
                children: [
                  Center(
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MemberAvatar(
                            url: _avatar.isNotEmpty ? _avatar : user.avatar,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '用户账号:${user.mobile}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF999999),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: _GradientQrCode(
                      data: qrData,
                      size: 220,
                      colors: const [AppTheme.brandEnd, AppTheme.brand],
                      embeddedImage: const AssetImage(
                        'assets/static/image/header.png',
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  const Center(
                    child: SizedBox(
                      width: 260,
                      child: Text(
                        '扫一扫上面的二维码图案,创建会员',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.25,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class PayCodePage extends ConsumerStatefulWidget {
  const PayCodePage({super.key});

  @override
  ConsumerState<PayCodePage> createState() => _PayCodePageState();
}

class _PayCodePageState extends ConsumerState<PayCodePage> {
  String _payCode = '';
  int _countDown = 60;
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _createPayCode();
    _setTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countDown--);
      if (_countDown <= 0) {
        _createPayCode();
        setState(() => _countDown = 60);
      }
    });
  }

  Future<void> _createPayCode() async {
    if (mounted) setState(() => _loading = true);
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(TuanTuanEndpoints.createPayCode);
      final envelope = ApiEnvelope.parse<String>(raw, (data) {
        if (data is Map) return data['payCode']?.toString() ?? '';
        return data?.toString() ?? '';
      });
      if (!envelope.isSuccess ||
          envelope.data == null ||
          envelope.data!.isEmpty) {
        _toast('生成支付二维码失败');
        return;
      }
      if (mounted) setState(() => _payCode = envelope.data!);
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final rpx = width / 750;
    return Scaffold(
      backgroundColor: AppTheme.brand,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40 * rpx),
                  child: Column(
                    children: [
                      SizedBox(
                        height: kToolbarHeight,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Text(
                              '付款码',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 52 * rpx),
                      Container(
                        width: 670 * rpx,
                        height: 774 * rpx,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32 * rpx),
                          image: const DecorationImage(
                            image: AssetImage('assets/static/card_bg_two.png'),
                            fit: BoxFit.fill,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40 * rpx),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 120 * rpx,
                                child: Center(child: _PayCodeTitle(scale: rpx)),
                              ),
                              SizedBox(height: 70 * rpx),
                              SizedBox(
                                width: 220,
                                height: 220,
                                child: _loading && _payCode.isEmpty
                                    ? const _CenteredLoading()
                                    : _payCode.isEmpty
                                    ? const Center(
                                        child: Text(
                                          '生成支付二维码失败',
                                          style: TextStyle(
                                            color: Color(0xFF999999),
                                          ),
                                        ),
                                      )
                                    : QrImageView(
                                        data: _payCode,
                                        size: 220,
                                        version: QrVersions.auto,
                                        padding: EdgeInsets.zero,
                                        eyeStyle: const QrEyeStyle(
                                          eyeShape: QrEyeShape.square,
                                          color: Color(0xFF333333),
                                        ),
                                        dataModuleStyle:
                                            const QrDataModuleStyle(
                                              dataModuleShape:
                                                  QrDataModuleShape.square,
                                              color: Color(0xFF333333),
                                            ),
                                      ),
                              ),
                              SizedBox(height: 50 * rpx),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$_countDown ',
                                      style: const TextStyle(
                                        color: AppTheme.brand,
                                      ),
                                    ),
                                    const TextSpan(text: '秒后二维码自动刷新'),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: -8,
                top: 0,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Center(
                    child: IconButton(
                      onPressed: Navigator.of(context).pop,
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScanCodePage extends ConsumerStatefulWidget {
  const ScanCodePage({this.params = const {}, super.key});

  final Map<String, String> params;

  @override
  ConsumerState<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends ConsumerState<ScanCodePage>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _handling = false;
  bool _hasPermission = false;
  bool _checkingPermission = false;
  bool _permissionDialogShowing = false;
  bool _writeOffVisible = false;
  bool _writeOffLoading = false;
  bool _writeOffSuccess = false;
  bool _writeOffFail = false;
  String _writeOffMessage = '';
  String _lastWriteOffUuid = '';

  bool get _isShopScan => widget.params['mode'] == 'shop';

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      autoZoom: false,
    );
    WidgetsBinding.instance.addObserver(this);
    _checkCameraPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCameraPermission(requestIfNeeded: false);
    }
  }

  Future<void> _checkCameraPermission({bool requestIfNeeded = true}) async {
    if (_checkingPermission) return;
    _checkingPermission = true;
    var status = await Permission.camera.status;
    if (requestIfNeeded &&
        !status.isGranted &&
        !status.isPermanentlyDenied &&
        !status.isRestricted) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _hasPermission = true);
      _checkingPermission = false;
      return;
    }
    setState(() => _hasPermission = false);
    _checkingPermission = false;
    if (requestIfNeeded) await _showCameraPermissionDialog();
  }

  Future<void> _showCameraPermissionDialog() async {
    if (_permissionDialogShowing || !mounted) return;
    _permissionDialogShowing = true;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要相机权限'),
        content: const Text('请在系统设置中开启相机权限'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
    _permissionDialogShowing = false;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere((item) => item.isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;
    setState(() => _handling = true);
    await _controller.stop();
    await _handleScanResult(value);
  }

  Future<void> _handleScanResult(String result) async {
    if (_isShopScan) {
      await _handleShopScanResult(result);
      return;
    }
    final data = result.split(',');
    if (data.length == 2) {
      _toast('请扫商户码');
      await _resume();
      return;
    }
    final shopId = data.first.trim();
    if (shopId.isEmpty) {
      _toast('请扫商户码');
      await _resume();
      return;
    }
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.checkMember,
            data: {'shopId': shopId, 'isShopScan': 0},
          );
      final envelope = ApiEnvelope.parse<bool>(raw, (data) {
        if (data is Map) {
          return data['isMember'] == true ||
              data['isMember'] == 1 ||
              data['isMember']?.toString() == 'true';
        }
        return false;
      });
      if (!envelope.isSuccess) {
        _toast(envelope.message ?? '扫码失败');
        await _resume();
        return;
      }
      if (!mounted) return;
      if (envelope.data == true) {
        context.go('/member-consumption?shopId=${Uri.encodeComponent(shopId)}');
      } else {
        context.go(
          '/create-member?shopId=${Uri.encodeComponent(shopId)}&from=user',
        );
      }
    } catch (error) {
      _toast(error.toString());
      await _resume();
    }
  }

  Future<void> _handleShopScanResult(String result) async {
    final parsed = ScanCodeParser().parse(result);
    switch (parsed.type) {
      case ScanCodeType.pay:
        if (!mounted) return;
        context.go(
          Uri(
            path: '/member-shop-pay',
            queryParameters: {
              'payCode': parsed.raw,
              'shopId': widget.params['shopId'] ?? '',
            },
          ).toString(),
        );
        return;
      case ScanCodeType.couponWriteOff:
        final uuid = parsed.parts.isNotEmpty ? parsed.parts.first.trim() : '';
        if (uuid.isEmpty) {
          _toast('无效核销码');
          await _resume();
          return;
        }
        await _writeOff(uuid);
        return;
      case ScanCodeType.user:
        await _handleCreateMemberScan(parsed);
        return;
      case ScanCodeType.shop:
      case ScanCodeType.unknown:
        _toast('请扫用户码');
        await _resume();
        return;
    }
  }

  Future<void> _handleCreateMemberScan(ParsedScanCode parsed) async {
    final userId = parsed.parts.first.trim();
    final mobile = parsed.parts.length > 1 ? parsed.parts[1].trim() : '';
    if (userId.isEmpty || mobile.isEmpty) {
      _toast('请扫用户码');
      await _resume();
      return;
    }
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.checkMember,
            data: {'userId': userId, 'isShopScan': 1},
          );
      final envelope = ApiEnvelope.parse<bool>(raw, _parseIsMember);
      if (!envelope.isSuccess) {
        _toast(envelope.message ?? '扫码失败');
        await _resume();
        return;
      }
      if (!mounted) return;
      if (envelope.data == true) {
        _toast('当前账号已经是会员，请勿重复添加');
        await _resume();
      } else {
        context.go(
          Uri(
            path: '/create-member',
            queryParameters: {
              'userId': userId,
              'mobile': mobile,
              'from': 'shop',
              'shopId': widget.params['shopId'] ?? '',
              'shopName': widget.params['shopName'] ?? '',
            },
          ).toString(),
        );
      }
    } catch (error) {
      _toast(error.toString());
      await _resume();
    }
  }

  bool _parseIsMember(dynamic data) {
    if (data is Map) {
      final value = data['isMember'];
      return value == true || value == 1 || value?.toString() == 'true';
    }
    return false;
  }

  Future<void> _writeOff(String uuid) async {
    _lastWriteOffUuid = uuid;
    if (mounted) {
      setState(() {
        _writeOffVisible = true;
        _writeOffLoading = true;
        _writeOffSuccess = false;
        _writeOffFail = false;
        _writeOffMessage = '';
      });
    }
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(TuanTuanEndpoints.writeOff, data: {'uuid': uuid});
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!mounted) return;
      setState(() {
        _writeOffLoading = false;
        _writeOffSuccess = envelope.isSuccess;
        _writeOffFail = !envelope.isSuccess;
        _writeOffMessage =
            envelope.message ?? (envelope.isSuccess ? '核销成功' : '核销失败');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _writeOffLoading = false;
        _writeOffSuccess = false;
        _writeOffFail = true;
        _writeOffMessage = error.toString();
      });
    }
  }

  Future<void> _closeWriteOff() async {
    if (!mounted) return;
    setState(() {
      _writeOffVisible = false;
      _handling = false;
    });
    await _controller.start();
  }

  Future<void> _retryWriteOff() async {
    if (_lastWriteOffUuid.isEmpty) return;
    await _writeOff(_lastWriteOffUuid);
  }

  Future<void> _resume() async {
    if (!mounted) return;
    setState(() => _handling = false);
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_hasPermission)
            MobileScanner(controller: _controller, onDetect: _onDetect)
          else
            _CameraPermissionView(onOpenSettings: openAppSettings),
          if (_hasPermission) const _ScanOverlay(),
          if (_writeOffVisible)
            _WriteOffResultOverlay(
              loading: _writeOffLoading,
              success: _writeOffSuccess,
              fail: _writeOffFail,
              message: _writeOffMessage,
              onClose: _closeWriteOff,
              onRetry: _retryWriteOff,
            ),
          SafeArea(
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      iconSize: 34,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '扫一扫',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
          ),
          if (_handling)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ScanTargetPlaceholderPage extends StatelessWidget {
  const ScanTargetPlaceholderPage({
    required this.title,
    required this.sourcePage,
    required this.params,
    super.key,
  });

  final String title;
  final String sourcePage;
  final Map<String, String> params;

  @override
  Widget build(BuildContext context) {
    return _ProfileScaffold(
      title: title,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ShadowPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '待迁移',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.brand,
                  ),
                ),
                const SizedBox(height: 12),
                Text(sourcePage),
                if (params.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final entry in params.entries)
                    Text('${entry.key}: ${entry.value}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WriteOffResultOverlay extends StatelessWidget {
  const _WriteOffResultOverlay({
    required this.loading,
    required this.success,
    required this.fail,
    required this.message,
    required this.onClose,
    required this.onRetry,
  });

  final bool loading;
  final bool success;
  final bool fail;
  final String message;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final title = loading
        ? '正在核销中'
        : success
        ? '核销成功'
        : '核销失败';
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 32),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading)
                      Image.asset(
                        'assets/static/data.gif',
                        width: 70,
                        height: 65,
                      )
                    else if (success)
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppTheme.brand,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 46,
                        ),
                      )
                    else
                      Image.asset(
                        'assets/static/image/kq.png',
                        width: 68,
                        height: 68,
                      ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loading ? '请稍等...' : message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (fail) ...[
                      const SizedBox(height: 30),
                      GestureDetector(
                        onTap: onRetry,
                        child: Container(
                          width: 150,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: AppTheme.brandGradient,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Text(
                            '重试',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class PurchasedCouponsPage extends ConsumerStatefulWidget {
  const PurchasedCouponsPage({super.key});

  @override
  ConsumerState<PurchasedCouponsPage> createState() =>
      _PurchasedCouponsPageState();
}

class _PurchasedCouponsPageState extends ConsumerState<PurchasedCouponsPage> {
  final _items = <PurchasedCoupon>[];
  int _tab = 0;
  int _pageNo = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _pageNo = 1;
        _items.clear();
        _loading = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get(
            TuanTuanEndpoints.orderPage,
            query: {'pageNo': _pageNo, 'pageSize': 10, 'type': _tab},
          );
      final envelope = ApiEnvelope.parse<PagedResult<PurchasedCoupon>>(
        raw,
        (data) => PagedResult.parse(data, PurchasedCoupon.fromJson),
      );
      if (envelope.isSuccess && envelope.data != null) {
        setState(() {
          _items.addAll(envelope.data!.list);
          _total = envelope.data!.total;
          if (!reset) _pageNo++;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _changeTab(int index) {
    if (_tab == index) return;
    setState(() => _tab = index);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileScaffold(
      title: '我的卷包',
      child: Column(
        children: [
          _Tabs(
            labels: const ['未使用', '已使用', '已过期'],
            current: _tab,
            onTap: _changeTab,
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.brand,
              onRefresh: () => _load(reset: true),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 80) {
                    _load(reset: false);
                  }
                  return false;
                },
                child: _loading
                    ? const _CenteredLoading()
                    : _items.isEmpty
                    ? const EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _items.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          if (index == _items.length) {
                            return _LoadMoreText(hasMore: _hasMore);
                          }
                          return _PurchasedCouponCard(
                            item: _items[index],
                            index: index,
                            status: _tab,
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MyCollectionPage extends ConsumerStatefulWidget {
  const MyCollectionPage({super.key});

  @override
  ConsumerState<MyCollectionPage> createState() => _MyCollectionPageState();
}

class _MyCollectionPageState extends ConsumerState<MyCollectionPage> {
  final _items = <FavoriteShop>[];
  int _pageNo = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _pageNo = 1;
        _items.clear();
        _loading = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get(
            TuanTuanEndpoints.shopFavList,
            query: {'pageNo': _pageNo, 'pageSize': 10},
          );
      final envelope = ApiEnvelope.parse<PagedResult<FavoriteShop>>(
        raw,
        (data) => PagedResult.parse(data, FavoriteShop.fromJson),
      );
      if (envelope.isSuccess && envelope.data != null) {
        setState(() {
          _items.addAll(envelope.data!.list);
          _total = envelope.data!.total;
          if (!reset) _pageNo++;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileScaffold(
      title: '我的收藏',
      child: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: () => _load(reset: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 80) {
              _load(reset: false);
            }
            return false;
          },
          child: _loading
              ? const _CenteredLoading()
              : _items.isEmpty
              ? const EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == _items.length) {
                      return _LoadMoreText(hasMore: _hasMore);
                    }
                    return _FavoriteShopCard(
                      item: _items[index],
                      onTap: () =>
                          context.push('/shop/${_items[index].shopId}'),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  ProfileUser? _user;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await ref.read(appStorageProvider).getUserDetail();
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _user = ProfileUser.tryParse(raw);
        _version = packageInfo.version;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(TuanTuanEndpoints.logout);
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!envelope.isSuccess) {
        _toast(envelope.message ?? '退出登录失败');
        return;
      }
    } catch (error) {
      _toast(error.toString());
      return;
    }
    await ref.read(appStorageProvider).clearAuth();
    ref.read(authRevisionProvider.notifier).bump();
    if (mounted) context.go('/profile');
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确定要注销账户吗'),
        content: const Text('注意: 注销账户后所有已购优惠卷将全部丢失并且无法找回'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(apiClientProvider).delete(TuanTuanEndpoints.deleteUser);
    await ref.read(appStorageProvider).clearAuth();
    ref.read(authRevisionProvider.notifier).bump();
    if (mounted) context.go('/profile');
  }

  Future<void> _checkVersion() async {
    try {
      final raw = await ref
          .read(apiClientProvider)
          .get(
            TuanTuanEndpoints.version,
            query: {'systemType': Theme.of(context).platform.name},
          );
      final envelope = ApiEnvelope.parse<Map<String, dynamic>>(
        raw,
        (data) => Map<String, dynamic>.from(data as Map),
      );
      final data = envelope.data;
      if (!envelope.isSuccess || data == null) {
        _toast(envelope.message ?? '版本检查失败');
        return;
      }
      final latest = data['versionNum']?.toString() ?? '';
      if (latest == _version || latest.isEmpty) {
        _toast('当前已是最新版本');
        return;
      }
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => _UpdateDialog(data: data),
      );
    } catch (error) {
      _toast(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileScaffold(
      title: '设置',
      bottom: _BottomOutlineButton(text: '退出登录', onTap: _logout),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        children: [
          _SettingGroup(
            children: [
              _SettingRow(
                title: '修改密码',
                onTap: () =>
                    context.push('/forget-password?type=updatePassword'),
              ),
            ],
          ),
          if (_user?.isManager == true)
            _SettingGroup(
              children: [
                _SettingRow(title: '设置支付密码', onTap: () => _toast('设置支付密码待迁移')),
              ],
            ),
          _SettingGroup(
            children: [
              _SettingRow(
                title: '24小时服务',
                onTap: () => context.push('/service'),
              ),
            ],
          ),
          _SettingGroup(
            children: [
              _SettingRow(
                title: '法律条款及隐私政策',
                onTap: () => context.push('/privacy-agreement?type=4'),
              ),
              _SettingRow(
                title: '当前版本',
                value: 'v$_version',
                onTap: _checkVersion,
              ),
              const _SettingRow(title: 'ICP备案号', value: '辽ICP备2024041749号'),
              _SettingRow(title: '注销账号', onTap: _deleteAccount),
            ],
          ),
        ],
      ),
    );
  }
}

class AboutUsPage extends ConsumerStatefulWidget {
  const AboutUsPage({super.key});

  @override
  ConsumerState<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends ConsumerState<AboutUsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileScaffold(
      title: '关于我们',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ShadowPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'assets/static/logott.png',
                    width: 140,
                    height: 140,
                  ),
                ),
                Text(
                  '版本 $_version',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 3,
                  ),
                ),
                const _AboutText('■ 关于TuanTuanGo的应用程序'),
                const _AboutText(
                  '通过该应用，您可以搜索“TuanTuanGo”上列出的餐厅信息，并购买餐厅所提供的优惠券。',
                ),
                const _AboutText('■ 什么是“TuanTuanGo”？'),
                const _AboutText(
                  '“TuanTuanGo”是由东和软件公司提供的餐厅网站，支持查询超过2万家餐厅与其购买相关产品。无论是聚餐、年会还是社交活动，欢迎使用“TuanTuanGo”。',
                ),
                _AgreementButton(
                  title: 'ID与会员协议',
                  onTap: () => context.push('/privacy-agreement?type=1'),
                ),
                _AgreementButton(
                  title: 'APP协议',
                  onTap: () => context.push('/privacy-agreement?type=2'),
                ),
                _AgreementButton(
                  title: '用户注册协议',
                  onTap: () => context.push('/privacy-agreement?type=3'),
                ),
                _AgreementButton(
                  title: '个人信息及隐私政策',
                  onTap: () => context.push('/privacy-agreement?type=4'),
                ),
                const Text(
                  '辽ICP备2024041749号',
                  style: TextStyle(color: Color(0xFF1879F8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ServicePage extends ConsumerStatefulWidget {
  const ServicePage({super.key});

  @override
  ConsumerState<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends ConsumerState<ServicePage> {
  final _contentController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _contentController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_contentController.text.isEmpty || _emailController.text.isEmpty) {
      return;
    }
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.inquirySend,
            data: {
              'content': _contentController.text,
              'email': _emailController.text,
            },
          );
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!envelope.isSuccess) {
        _toast(envelope.message ?? '提交失败');
        return;
      }
      _toast('提交成功');
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _toast(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileScaffold(
      title: '24小时服务',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17.5, 20, 17.5, 20),
        children: [
          const Center(
            child: Text(
              'Hi,很高兴为您服务!',
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 140,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            decoration: _inputDecoration(),
            child: Stack(
              children: [
                TextField(
                  controller: _contentController,
                  maxLength: 100,
                  maxLines: null,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    hintText: '请输入您的问题,我们会在24小时内回复到您预留的邮箱',
                    filled: false,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Text('${_contentController.text.length} /100'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: _inputDecoration(),
            child: TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '请输入您的邮箱地址',
                filled: false,
              ),
            ),
          ),
          const SizedBox(height: 40),
          _BottomGradientButton(text: '完成', onTap: _submit),
        ],
      ),
    );
  }
}

class PrivacyAgreementPage extends StatelessWidget {
  const PrivacyAgreementPage({required this.type, super.key});

  final int type;

  @override
  Widget build(BuildContext context) {
    final title = privacyAgreementTitles[type] ?? '个人信息及隐私政策';
    final sections = _agreementSections(type);
    return _ProfileScaffold(
      title: title,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ShadowPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'assets/static/logott.png',
                    width: 140,
                    height: 140,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 2,
                  ),
                ),
                for (final section in sections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      section,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        height: 1.65,
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

class PurchasedCoupon {
  const PurchasedCoupon({
    required this.orderMgmtId,
    required this.shopName,
    required this.logoImageUrl,
    required this.categoryName,
    required this.couponName,
    required this.couponImage,
    required this.couponPrice,
    required this.oriPrice,
    required this.discountRate,
    required this.validPeriod,
  });

  final String orderMgmtId;
  final String shopName;
  final String logoImageUrl;
  final String categoryName;
  final String couponName;
  final String couponImage;
  final String couponPrice;
  final String oriPrice;
  final int discountRate;
  final String validPeriod;

  factory PurchasedCoupon.fromJson(Map<String, dynamic> json) {
    final categories = json['shopCategoryList'];
    final images = json['couponImageUrlList'];
    final rate = _asDouble(json['discountRate']) ?? 0;
    return PurchasedCoupon(
      orderMgmtId: json['orderMgmtId']?.toString() ?? '',
      shopName: json['shopName']?.toString() ?? '',
      logoImageUrl: json['logoImageUrl']?.toString() ?? '',
      categoryName: categories is List && categories.isNotEmpty
          ? (categories.first as Map)['categoryName']?.toString() ?? '--'
          : '--',
      couponName: json['couponName']?.toString() ?? '',
      couponImage: images is List && images.isNotEmpty
          ? images.first?.toString() ?? ''
          : '',
      couponPrice: json['couponPrice']?.toString() ?? '--',
      oriPrice: json['oriPrice']?.toString() ?? '--',
      discountRate: (rate * 100).round(),
      validPeriod: _formatDate(json['validPeriod']),
    );
  }
}

class FavoriteShop {
  const FavoriteShop({
    required this.shopId,
    required this.name,
    required this.logoImageUrl,
    required this.rating,
    required this.categoryName,
    required this.favCount,
  });

  final String shopId;
  final String name;
  final String logoImageUrl;
  final double rating;
  final String categoryName;
  final int favCount;

  factory FavoriteShop.fromJson(Map<String, dynamic> json) {
    final categories = json['categoryList'];
    return FavoriteShop(
      shopId: json['shopId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      logoImageUrl: json['logoImageUrl']?.toString() ?? '',
      rating: _asDouble(json['rating']) ?? 0,
      categoryName: categories is List
          ? categories
                .whereType<Map>()
                .map((item) => item['categoryName']?.toString() ?? '')
                .where((item) => item.isNotEmpty)
                .join('，')
          : '',
      favCount: _asInt(json['shopFavCount']) ?? 0,
    );
  }
}

class _ProfileScaffold extends StatelessWidget {
  const _ProfileScaffold({
    required this.title,
    required this.child,
    this.bottom,
  });

  final String title;
  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: Navigator.of(context).pop,
          icon: const Icon(
            Icons.chevron_left,
            color: Color(0xFF333333),
            size: 32,
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: bottom == null
          ? null
          : Container(
              color: AppTheme.pageBg,
              child: SafeArea(top: false, child: bottom!),
            ),
    );
  }
}

class _ShadowPanel extends StatelessWidget {
  const _ShadowPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 10)],
      ),
      child: child,
    );
  }
}

class _BottomGradientButton extends StatelessWidget {
  const _BottomGradientButton({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomOutlineButton extends StatelessWidget {
  const _BottomOutlineButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.brand),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.brand,
            ),
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.labels,
    required this.current,
    required this.onTap,
  });

  final List<String> labels;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 16,
                        color: i == current
                            ? AppTheme.brand
                            : AppTheme.textSecondary,
                        fontWeight: i == current ? FontWeight.w600 : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: i == current ? AppTheme.brandGradient : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PurchasedCouponCard extends StatelessWidget {
  const _PurchasedCouponCard({
    required this.item,
    required this.index,
    required this.status,
  });

  final PurchasedCoupon item;
  final int index;
  final int status;

  static const _colors = [
    [Color(0xFFFF4252), Color(0xFFFF7396)],
    [Color(0xFFFF9040), Color(0xFFFFB973)],
    [Color(0xFFFF66B2), Color(0xFFFF99D4)],
    [Color(0xFF7064F9), Color(0xFFA08DFF)],
    [Color(0xFFB266FF), Color(0xFFED8DFF)],
    [Color(0xFFFFB60C), Color(0xFFFFDD00)],
  ];

  @override
  Widget build(BuildContext context) {
    final pair = status == 0
        ? _colors[index % _colors.length]
        : const [Color(0xFF909090), Color(0xFFB5B5B5)];
    final disabled = status != 0;
    return Container(
      height: 151,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: pair,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            right: -50,
            bottom: -35,
            width: 225,
            height: 225,
            child: Opacity(
              opacity: .2,
              child: Image.asset('assets/static/image/hot-logo.png'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      _CircleNetImage(url: item.logoImageUrl, size: 40),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        item.categoryName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      image: const DecorationImage(
                        image: AssetImage(
                          'assets/static/yhj-bg-one_compressed.png',
                        ),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 65,
                              child: Row(
                                children: [
                                  const SizedBox(width: 8),
                                  _NetImage(url: item.couponImage, size: 52),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.couponName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '￥${item.couponPrice}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.brand,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '￥${item.oriPrice}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF999999),
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${item.validPeriod}到期',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 58,
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: disabled
                                        ? const Color(0xFF666666)
                                        : pair.first,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 35,
                              child: _DiscountNumber(
                                rate: item.discountRate,
                                color: disabled
                                    ? const Color(0xFF666666)
                                    : AppTheme.brandEnd,
                              ),
                            ),
                          ],
                        ),
                        if (disabled)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: _UsedStamp(
                              text: status == 1 ? '已使用' : '已过期',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteShopCard extends StatelessWidget {
  const _FavoriteShopCard({required this.item, required this.onTap});

  final FavoriteShop item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            _NetImage(url: item.logoImageUrl, size: 72),
            const SizedBox(width: 10),
            Expanded(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _SmallStars(value: item.rating),
                          const SizedBox(width: 4),
                          Text(
                            item.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.brand,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Text(
                      '${item.favCount}人收藏过',
                      style: const TextStyle(fontSize: 12),
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

class _SettingGroup extends StatelessWidget {
  const _SettingGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.title, this.value, this.onTap});

  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
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
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  value!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF999999),
                  ),
                ),
              ),
            if (onTap != null)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFCCCCCC),
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
      ),
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final force = data['forceUpdateFlg'] == true;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/static/update.png', fit: BoxFit.fitWidth),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('v${data['versionNum'] ?? ''} 发现新版本'),
                const SizedBox(height: 12),
                const Text('用户体验全面升级'),
                const SizedBox(height: 12),
                Text(data['versionContent']?.toString() ?? ''),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!force)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: Navigator.of(context).pop,
                          child: const Text('暂不体验'),
                        ),
                      ),
                    if (!force) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final url = data['appstoreUrl']?.toString();
                          if (url != null && url.isNotEmpty) {
                            await launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: const Text('立即体验'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutText extends StatelessWidget {
  const _AboutText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
    );
  }
}

class _AgreementButton extends StatelessWidget {
  const _AgreementButton({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 43,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE3E3E3)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(title),
      ),
    );
  }
}

class _NetImage extends StatelessWidget {
  const _NetImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? Container(color: const Color(0xFFF1F1F1))
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: const Color(0xFFF1F1F1)),
              ),
      ),
    );
  }
}

class _CircleNetImage extends StatelessWidget {
  const _CircleNetImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? Container(color: const Color(0x33FFFFFF))
            : Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 35,
        height: 35,
        child: url.isEmpty
            ? Image.asset('assets/static/tx.png', fit: BoxFit.cover)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Image.asset('assets/static/tx.png', fit: BoxFit.cover),
              ),
      ),
    );
  }
}

class _GradientQrCode extends StatelessWidget {
  const _GradientQrCode({
    required this.data,
    required this.size,
    required this.colors,
    this.embeddedImage,
  });

  final String data;
  final double size;
  final List<Color> colors;
  final ImageProvider? embeddedImage;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);
      },
      blendMode: BlendMode.srcIn,
      child: QrImageView(
        data: data,
        size: size,
        version: QrVersions.auto,
        padding: EdgeInsets.zero,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.white,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.white,
        ),
        embeddedImage: embeddedImage,
        embeddedImageStyle: embeddedImage == null
            ? null
            : const QrEmbeddedImageStyle(size: Size(38, 38)),
      ),
    );
  }
}

class _PayCodeTitle extends StatelessWidget {
  const _PayCodeTitle({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PayCodeTick(height: 10 * scale, scale: scale),
        SizedBox(width: 6 * scale),
        _PayCodeTick(height: 18 * scale, scale: scale),
        SizedBox(width: 16 * scale),
        Text(
          '扫一扫，向商家付款',
          style: TextStyle(fontSize: 32 * scale, color: AppTheme.textPrimary),
        ),
        SizedBox(width: 16 * scale),
        _PayCodeTick(height: 18 * scale, scale: scale),
        SizedBox(width: 6 * scale),
        _PayCodeTick(height: 10 * scale, scale: scale),
      ],
    );
  }
}

class _PayCodeTick extends StatelessWidget {
  const _PayCodeTick({required this.height, required this.scale});

  final double height;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6 * scale,
      height: height,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(3 * scale),
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scanSize = size.width * 0.68;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0x66000000))),
          Center(
            child: Container(
              width: scanSize,
              height: scanSize,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: CustomPaint(painter: _ScanCornerPainter()),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: size.height / 2 + scanSize / 2 + 24,
            child: const Text(
              '请将二维码放入框内',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPermissionView extends StatelessWidget {
  const _CameraPermissionView({required this.onOpenSettings});

  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              '需要相机权限',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请在系统设置中开启相机权限后继续扫码',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFDDDDDD), fontSize: 14),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onOpenSettings,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.brand),
              child: const Text('去设置'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.brand
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    const length = 26.0;
    canvas
      ..drawLine(Offset.zero, const Offset(length, 0), paint)
      ..drawLine(Offset.zero, const Offset(0, length), paint)
      ..drawLine(Offset(size.width, 0), Offset(size.width - length, 0), paint)
      ..drawLine(Offset(size.width, 0), Offset(size.width, length), paint)
      ..drawLine(Offset(0, size.height), Offset(length, size.height), paint)
      ..drawLine(Offset(0, size.height), Offset(0, size.height - length), paint)
      ..drawLine(
        Offset(size.width, size.height),
        Offset(size.width - length, size.height),
        paint,
      )
      ..drawLine(
        Offset(size.width, size.height),
        Offset(size.width, size.height - length),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiscountNumber extends StatelessWidget {
  const _DiscountNumber({required this.rate, required this.color});

  final int rate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$rate',
            style: TextStyle(
              fontSize: rate == 100 ? 38 : 55,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('%', style: TextStyle(fontSize: 10, color: color)),
                Text('OFF', style: TextStyle(fontSize: 10, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsedStamp extends StatelessWidget {
  const _UsedStamp({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.35,
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.brand, width: 2),
        ),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.brand),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.brand,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallStars extends StatelessWidget {
  const _SmallStars({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 1; index <= 5; index++)
          Icon(
            index <= value.round() ? Icons.star : Icons.star_border,
            size: 14,
            color: AppTheme.brand,
          ),
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x33000000),
        child: Center(
          child: Container(
            width: 70,
            height: 65,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset('assets/static/data.gif'),
          ),
        ),
      ),
    );
  }
}

class _CenteredLoading extends StatelessWidget {
  const _CenteredLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 70,
        height: 65,
        child: Image.asset('assets/static/data.gif'),
      ),
    );
  }
}

class _LoadMoreText extends StatelessWidget {
  const _LoadMoreText({required this.hasMore});

  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          hasMore ? '轻轻上拉' : '已经到底部啦～',
          style: const TextStyle(color: Color(0xFF9E9E9E)),
        ),
      ),
    );
  }
}

BoxDecoration _inputDecoration() {
  return BoxDecoration(
    color: Colors.white,
    border: Border.all(color: const Color(0xFFEEEEEE)),
    borderRadius: BorderRadius.circular(24),
  );
}

String _formatDate(dynamic value) {
  final text = value?.toString() ?? '';
  final date = DateTime.tryParse(text);
  if (date == null) return text;
  return '${date.year}-${date.month}-${date.day} ';
}

List<String> _agreementSections(int type) {
  return privacyAgreementTexts[type] ?? privacyAgreementTexts[4]!;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
