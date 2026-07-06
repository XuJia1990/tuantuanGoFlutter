import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import '../../../core/storage/app_storage.dart';
import '../../home/data/home_models.dart';

enum _Region {
  japan(label: '日本 +81', code: '+81', icon: 'assets/static/image/login-1.png'),
  china(label: '中国 +86', code: '+86', icon: 'assets/static/image/zh-cn.png');

  const _Region({required this.label, required this.code, required this.icon});

  final String label;
  final String code;
  final String icon;
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({this.messageType, super.key});

  final String? messageType;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _mobileController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  var _region = _Region.japan;
  var _loginBySms = true;
  var _agreed = false;
  var _isSubmitting = false;
  var _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(_rebuild);
    _codeController.addListener(_rebuild);
    _passwordController.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showEntryMessage());
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mobileController.removeListener(_rebuild);
    _codeController.removeListener(_rebuild);
    _passwordController.removeListener(_rebuild);
    _mobileController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showEntryMessage() {
    final type = widget.messageType;
    if (type == 'register') {
      _toast('恭喜你！完成账号注册，现在登录试试吧');
    } else if (type == 'resetPassword') {
      _toast('您已成功设置账号密码，现在登录试试吧');
    } else if (type == 'updatePassword') {
      _toast('您已成功重置账号密码，请重新登录');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _normalizedMobile() {
    return _normalizeMobile(
      _mobileController.text.trim(),
      _region,
      onError: _toast,
    );
  }

  Future<void> _sendCode() async {
    if (_countdown > 0) return;
    final mobile = _normalizedMobile();
    if (mobile == null) return;
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.sendSmsCode,
            data: {'mobile': mobile, 'scene': 1},
          );
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!envelope.isSuccess) {
        _toast(envelope.message ?? '验证码发送失败');
        return;
      }
      _toast(envelope.message ?? '成功发送验证码');
      _startCountdown(60);
    } catch (error) {
      _toast(error.toString());
    }
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _countdown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _countdown = 0);
        return;
      }
      if (mounted) setState(() => _countdown--);
    });
  }

  Future<void> _login() async {
    if (!_agreed) {
      _toast('请先同意《法律条款及隐私政策》');
      return;
    }
    if (_mobileController.text.trim().isEmpty) {
      _toast('请输入手机号码');
      return;
    }
    if (_loginBySms && _codeController.text.trim().isEmpty) {
      _toast('请输入验证码');
      return;
    }
    if (!_loginBySms && _passwordController.text.trim().isEmpty) {
      _toast('请输入密码');
      return;
    }
    final mobile = _normalizedMobile();
    if (mobile == null) return;
    setState(() => _isSubmitting = true);
    try {
      final endpoint = _loginBySms
          ? TuanTuanEndpoints.smsLogin
          : TuanTuanEndpoints.passwordLogin;
      final data = _loginBySms
          ? {'mobile': mobile, 'code': _codeController.text.trim()}
          : {'mobile': mobile, 'password': _passwordController.text};
      final raw = await ref.read(apiClientProvider).post(endpoint, data: data);
      final envelope = ApiEnvelope.parse<Map<String, dynamic>>(
        raw,
        (data) => Map<String, dynamic>.from(data as Map),
      );
      if (!envelope.isSuccess || envelope.data == null) {
        _toast(envelope.message ?? '登录失败');
        return;
      }
      final storage = ref.read(appStorageProvider);
      await storage.saveUser(jsonEncode(envelope.data));
      await _refreshUserDetail();
      ref.read(authRevisionProvider.notifier).bump();
      if (mounted) context.go('/profile');
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _refreshUserDetail() async {
    final raw = await ref
        .read(apiClientProvider)
        .get(TuanTuanEndpoints.userDetail);
    final envelope = ApiEnvelope.parse<Map<String, dynamic>>(
      raw,
      (data) => Map<String, dynamic>.from(data as Map),
    );
    if (!envelope.isSuccess || envelope.data == null) return;
    final user = envelope.data!;
    final storage = ref.read(appStorageProvider);
    await storage.saveUserDetail(jsonEncode(user));
    final avatar = user['avatar']?.toString() ?? '';
    if (avatar.isNotEmpty) await storage.saveUserAvatar(avatar);
    final userId = user['userId']?.toString();
    if (userId == null || userId.isEmpty) return;
    final groupRaw = await ref
        .read(apiClientProvider)
        .post(TuanTuanEndpoints.isGroupManager, data: {'userId': userId});
    final groupEnvelope = ApiEnvelope.parse<bool>(
      groupRaw,
      (data) => data == true || data == 1 || data?.toString() == 'true',
    );
    await storage.saveIsGroupManager(
      groupEnvelope.isSuccess && groupEnvelope.data == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/static/image/login-top.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                        Positioned(
                          top: 60,
                          left: 25,
                          child: GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  _PhoneInputRow(
                    region: _region,
                    mobileController: _mobileController,
                    onRegionTap: () async {
                      final region = await _showRegionPicker(context, _region);
                      if (region != null) setState(() => _region = region);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_loginBySms)
                    _CodeInputRow(
                      controller: _codeController,
                      countdown: _countdown,
                      mobileLength: _mobileController.text.length,
                      onSendCode: _sendCode,
                    )
                  else
                    _AuthInputBox(
                      controller: _passwordController,
                      hint: '请输入密码',
                      obscureText: true,
                      maxLength: 20,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 12, 30, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _loginBySms = !_loginBySms),
                          child: Text(
                            _loginBySms ? '用密码登录' : '用手机验证码登录',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.brandEnd,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (!_loginBySms)
                          GestureDetector(
                            onTap: () => context.push('/forget-password'),
                            child: const Text(
                              '忘记密码',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.brandEnd,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 38),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _agreed = !_agreed),
                        child: Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _agreed
                                ? AppTheme.brand
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: _agreed
                                ? null
                                : Border.all(color: const Color(0xFF999999)),
                          ),
                          child: _agreed
                              ? const Icon(
                                  Icons.check,
                                  size: 13,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _agreed = !_agreed),
                        child: const Text(
                          '同意',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _toast('法律条款及隐私政策待迁移'),
                        child: const Text(
                          '《法律条款及隐私政策》',
                          style: TextStyle(fontSize: 14, color: AppTheme.brand),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  _GradientButton(
                    text: _isSubmitting ? '登录中...' : '登录',
                    enabled: !_isSubmitting,
                    onTap: _login,
                  ),
                  const SizedBox(height: 20),
                  _OutlineButton(
                    text: '注册账号',
                    onTap: () => context.push('/register'),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _mobileController = TextEditingController();
  final _codeController = TextEditingController();
  var _region = _Region.japan;
  var _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(_rebuild);
    _codeController.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mobileController.removeListener(_rebuild);
    _codeController.removeListener(_rebuild);
    _mobileController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendCode() => _sendCodeShared(
    context: context,
    ref: ref,
    mobile: _mobileController.text,
    region: _region,
    scene: 5,
    onCountdown: _startCountdown,
  );

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _countdown = seconds - 1);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _countdown = 0);
      } else if (mounted) {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _next() async {
    if (_mobileController.text.length != 11 ||
        _codeController.text.length != 4) {
      return;
    }
    final mobile = _normalizeMobile(
      _mobileController.text,
      _region,
      onError: _toast,
    );
    if (mobile == null) return;
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.validateSmsCode,
            data: {'scene': 5, 'code': _codeController.text, 'mobile': mobile},
          );
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!envelope.isSuccess) {
        _toast(envelope.message ?? '验证码校验失败');
        return;
      }
      if (!mounted) return;
      context.push(
        '/set-password?type=register&mobile=${Uri.encodeComponent(mobile)}&code=${_codeController.text}',
      );
    } catch (error) {
      _toast(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: '注册账号',
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            '当前账号注册仅支持日本手机号注册',
            style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          _PhoneInputRow(
            region: _region,
            mobileController: _mobileController,
            onRegionTap: () async {
              final region = await _showRegionPicker(context, _region);
              if (region != null) setState(() => _region = region);
            },
          ),
          const SizedBox(height: 16),
          _CodeInputRow(
            controller: _codeController,
            countdown: _countdown,
            mobileLength: _mobileController.text.length,
            onSendCode: _sendCode,
          ),
          const SizedBox(height: 40),
          _GradientButton(
            text: '下一步',
            enabled:
                _mobileController.text.length == 11 &&
                _codeController.text.length == 4,
            onTap: _next,
          ),
        ],
      ),
    );
  }
}

class ForgetPasswordPage extends ConsumerStatefulWidget {
  const ForgetPasswordPage({this.type = 'resetPassword', super.key});

  final String type;

  @override
  ConsumerState<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends ConsumerState<ForgetPasswordPage> {
  final _mobileController = TextEditingController();
  final _codeController = TextEditingController();
  var _region = _Region.japan;
  var _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(_rebuild);
    _codeController.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mobileController.removeListener(_rebuild);
    _codeController.removeListener(_rebuild);
    _mobileController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendCode() => _sendCodeShared(
    context: context,
    ref: ref,
    mobile: _mobileController.text,
    region: _region,
    scene: widget.type == 'resetPassword' ? 4 : 3,
    onCountdown: (seconds) {
      _timer?.cancel();
      setState(() => _countdown = seconds - 1);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_countdown <= 1) {
          timer.cancel();
          if (mounted) setState(() => _countdown = 0);
        } else if (mounted) {
          setState(() => _countdown--);
        }
      });
    },
  );

  Future<void> _next() async {
    if (_mobileController.text.length != 11 ||
        _codeController.text.length != 4) {
      return;
    }
    final scene = widget.type == 'resetPassword' ? 4 : 3;
    final mobile = _normalizeMobile(
      _mobileController.text,
      _region,
      onError: _toast,
    );
    if (mobile == null) return;
    try {
      final raw = await ref
          .read(apiClientProvider)
          .post(
            TuanTuanEndpoints.validateSmsCode,
            data: {
              'scene': scene,
              'code': _codeController.text,
              'mobile': mobile,
            },
          );
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!envelope.isSuccess) {
        _toast(envelope.message ?? '验证码校验失败');
        return;
      }
      if (!mounted) return;
      context.push(
        '/set-password?type=${widget.type}&mobile=${Uri.encodeComponent(mobile)}&code=${_codeController.text}',
      );
    } catch (error) {
      _toast(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'resetPassword' ? '忘记密码' : '修改密码';
    return _AuthScaffold(
      title: title,
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            '通过手机号验证后，可重新设置登录密码',
            style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          _PhoneInputRow(
            region: _region,
            mobileController: _mobileController,
            onRegionTap: () async {
              final region = await _showRegionPicker(context, _region);
              if (region != null) setState(() => _region = region);
            },
          ),
          const SizedBox(height: 16),
          _CodeInputRow(
            controller: _codeController,
            countdown: _countdown,
            mobileLength: _mobileController.text.length,
            onSendCode: _sendCode,
          ),
          const SizedBox(height: 40),
          _GradientButton(
            text: '下一步',
            enabled:
                _mobileController.text.length == 11 &&
                _codeController.text.length == 4,
            onTap: _next,
          ),
        ],
      ),
    );
  }
}

class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({
    required this.type,
    required this.mobile,
    required this.code,
    super.key,
  });

  final String type;
  final String mobile;
  final String code;

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final _passwordOneController = TextEditingController();
  final _passwordTwoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _passwordOneController.addListener(_rebuild);
    _passwordTwoController.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _passwordOneController.removeListener(_rebuild);
    _passwordTwoController.removeListener(_rebuild);
    _passwordOneController.dispose();
    _passwordTwoController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final passwordOne = _passwordOneController.text;
    final passwordTwo = _passwordTwoController.text;
    if (passwordOne.isEmpty || passwordTwo.isEmpty) return;
    if (passwordOne != passwordTwo) {
      _toast('两次密码不一致，请检查设置的密码');
      return;
    }
    final mobile = _normalizeSubmittedMobile(widget.mobile);
    final endpoint = switch (widget.type) {
      'register' => TuanTuanEndpoints.smsRegister,
      'resetPassword' => TuanTuanEndpoints.resetPassword,
      'updatePassword' => TuanTuanEndpoints.updatePassword,
      _ => TuanTuanEndpoints.smsRegister,
    };
    final data = {
      'mobile': mobile,
      'code': widget.code,
      'password': passwordOne,
    };
    try {
      final client = ref.read(apiClientProvider);
      final raw = widget.type == 'register'
          ? await client.post(endpoint, data: data)
          : await client.put(endpoint, data: data);
      final envelope = ApiEnvelope.parse<void>(raw, (_) {});
      if (!envelope.isSuccess) {
        _toast(envelope.message ?? '提交失败');
        return;
      }
      if (widget.type == 'updatePassword') {
        await ref.read(appStorageProvider).clearAuth();
        ref.read(authRevisionProvider.notifier).bump();
      }
      if (!mounted) return;
      context.go('/login?type=${widget.type}');
    } catch (error) {
      _toast(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.type == 'resetPassword' || widget.type == 'updatePassword'
        ? '设置新密码'
        : '设置账号密码';
    return _AuthScaffold(
      title: title,
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            '设置账号密码，可用于登录账号',
            style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          _AuthInputBox(
            controller: _passwordOneController,
            hint: '输入需设置的账号密码',
            obscureText: true,
            maxLength: 11,
          ),
          const SizedBox(height: 16),
          _AuthInputBox(
            controller: _passwordTwoController,
            hint: '两次输入需设置的账号密码',
            obscureText: true,
            maxLength: 11,
          ),
          const SizedBox(height: 40),
          _GradientButton(
            text: '完成',
            enabled:
                _passwordOneController.text.isNotEmpty &&
                _passwordTwoController.text.isNotEmpty,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: Navigator.of(context).pop,
            icon: const Icon(Icons.chevron_left, color: Color(0xFF333333)),
          ),
          centerTitle: true,
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

class _PhoneInputRow extends StatelessWidget {
  const _PhoneInputRow({
    required this.region,
    required this.mobileController,
    required this.onRegionTap,
  });

  final _Region region;
  final TextEditingController mobileController;
  final VoidCallback onRegionTap;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRegionTap,
            child: Row(
              children: [
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(region.icon, width: 36, height: 30),
                ),
                const SizedBox(width: 8),
                Text(
                  region.code,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: mobileController,
              selectAllOnFocus: false,
              keyboardType: TextInputType.number,
              maxLength: 11,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _authInputDecoration(
                '请输入手机号',
                suffixIcon: mobileController.text.isEmpty
                    ? null
                    : _ClearButton(onTap: mobileController.clear),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeInputRow extends StatelessWidget {
  const _CodeInputRow({
    required this.controller,
    required this.countdown,
    required this.mobileLength,
    required this.onSendCode,
  });

  final TextEditingController controller;
  final int countdown;
  final int mobileLength;
  final VoidCallback onSendCode;

  @override
  Widget build(BuildContext context) {
    final enabled = mobileLength == 11 && countdown == 0;
    return _FieldShell(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              selectAllOnFocus: false,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _authInputDecoration(
                '请输入验证码',
                suffixIcon: controller.text.isEmpty
                    ? null
                    : _ClearButton(onTap: controller.clear),
              ),
            ),
          ),
          GestureDetector(
            onTap: enabled ? onSendCode : null,
            child: Container(
              width: 104,
              height: 36,
              margin: const EdgeInsets.only(right: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: enabled ? AppTheme.brandGradient : null,
                color: enabled ? null : const Color(0xFFCCCCCC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                countdown > 0 ? '${countdown}s' : '获取验证码',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthInputBox extends StatefulWidget {
  const _AuthInputBox({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final int? maxLength;

  @override
  State<_AuthInputBox> createState() => _AuthInputBoxState();
}

class _AuthInputBoxState extends State<_AuthInputBox> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      child: TextField(
        controller: widget.controller,
        selectAllOnFocus: false,
        obscureText: _obscured,
        maxLength: widget.maxLength,
        decoration: _authInputDecoration(
          widget.hint,
          suffixIcon: widget.obscureText
              ? _PasswordVisibilityButton(
                  obscured: _obscured,
                  onTap: () => setState(() => _obscured = !_obscured),
                )
              : widget.controller.text.isEmpty
              ? null
              : _ClearButton(onTap: widget.controller.clear),
        ),
      ),
    );
  }
}

class _PasswordVisibilityButton extends StatelessWidget {
  const _PasswordVisibilityButton({
    required this.obscured,
    required this.onTap,
  });

  final bool obscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(
          obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: const Color(0xFF999999),
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const SizedBox(
        width: 36,
        height: 36,
        child: Icon(Icons.cancel, size: 18, color: Color(0xFFCCCCCC)),
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Container(
      width: width - 60,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.pageBg,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  final String text;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: width - 60,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled ? AppTheme.brandGradient : null,
          color: enabled ? null : const Color(0xFFCCCCCC),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width - 60,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.brandEnd),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.brandEnd,
          ),
        ),
      ),
    );
  }
}

InputDecoration _authInputDecoration(String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    counterText: '',
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    filled: false,
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 16),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
  );
}

Future<_Region?> _showRegionPicker(BuildContext context, _Region current) {
  return showModalBottomSheet<_Region>(
    context: context,
    backgroundColor: Colors.white,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final region in _Region.values)
              ListTile(
                title: Text(region.label),
                trailing: region == current
                    ? const Icon(Icons.check, color: AppTheme.brand)
                    : null,
                onTap: () => Navigator.of(context).pop(region),
              ),
          ],
        ),
      );
    },
  );
}

Future<void> _sendCodeShared({
  required BuildContext context,
  required WidgetRef ref,
  required String mobile,
  required _Region region,
  required int scene,
  required ValueChanged<int> onCountdown,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final normalized = _normalizeMobile(
    mobile,
    region,
    onError: (message) =>
        messenger.showSnackBar(SnackBar(content: Text(message))),
  );
  if (normalized == null) return;
  try {
    final raw = await ref
        .read(apiClientProvider)
        .post(
          TuanTuanEndpoints.sendSmsCode,
          data: {'mobile': normalized, 'scene': scene},
        );
    final envelope = ApiEnvelope.parse<void>(raw, (_) {});
    if (!envelope.isSuccess) {
      messenger.showSnackBar(
        SnackBar(content: Text(envelope.message ?? '验证码发送失败')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(envelope.message ?? '成功发送验证码')),
    );
    onCountdown(59);
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

String? _normalizeMobile(
  String raw,
  _Region region, {
  required ValueChanged<String> onError,
}) {
  final mobile = raw.trim();
  if (mobile.length < 11) {
    onError('请检查输入的手机号是否有误');
    return null;
  }
  final isJapanese = _isJapaneseMobile(mobile);
  if (region == _Region.japan && !isJapanese) {
    onError('请输入日本手机号码');
    return null;
  }
  if (region == _Region.china && isJapanese) {
    onError('请输入中国手机号码');
    return null;
  }
  if (region == _Region.japan) return '+81${mobile.substring(1)}';
  return '+86$mobile';
}

String _normalizeSubmittedMobile(String raw) {
  final mobile = raw.trim();
  if (mobile.startsWith('+')) return mobile;
  if (_isJapaneseMobile(mobile)) return '+81${mobile.substring(1)}';
  return '+86$mobile';
}

bool _isJapaneseMobile(String mobile) {
  return mobile.startsWith('070') ||
      mobile.startsWith('080') ||
      mobile.startsWith('090');
}
