import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/ui/app_toast.dart';
import '../../member/data/member_activity_models.dart';
import '../../member/data/member_activity_repository.dart';

class SealDebugPage extends ConsumerStatefulWidget {
  const SealDebugPage({this.extra, super.key});

  final Object? extra;

  @override
  ConsumerState<SealDebugPage> createState() => _SealDebugPageState();
}

class _SealDebugPageState extends ConsumerState<SealDebugPage> {
  /// 逻辑坐标系（与 coordinateSystem=3 / H5 sealTest 一致），不是物理像素画布尺寸。
  static const _logicWidth = 800.0;
  static const _logicHeight = 600.0;
  static const _minimumPointCount = 4;
  static const _maximumPointCount = 4;
  static const _ruleCode = 'RULERsssFFEW1';
  static const _authStoreCode = 'UYYshiZkwrHO';
  static const _endpoint =
      'https://wvxvb.cn/app/signstore/sealrule/compareSimilarity/act004';

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  final _points = <Offset>[];
  final _activePointers = <int, Offset>{};
  late final String _activityId;
  late final String _shopId;
  String? _pendingStampRequestId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final data = widget.extra is Map
        ? Map<String, dynamic>.from(widget.extra! as Map)
        : const <String, dynamic>{};
    _activityId = data['activityId']?.toString() ?? '';
    _shopId = data['shopId']?.toString() ?? '';
  }

  void _handlePointerDown(int pointer, Offset localPosition, Size displaySize) {
    final point = _clampLogicPoint(_toLogicPoint(localPosition, displaySize));
    var shouldSubmit = false;
    setState(() {
      final startsNewCapture = _activePointers.isEmpty;
      if (_activePointers.length >= _maximumPointCount &&
          !_activePointers.containsKey(pointer)) {
        return;
      }
      if (startsNewCapture) _points.clear();
      _activePointers[pointer] = point;
      _captureActivePoints();
      shouldSubmit =
          _activePointers.length == _maximumPointCount && !_submitting;
    });
    if (shouldSubmit) unawaited(_submit());
  }

  void _handlePointerMove(int pointer, Offset localPosition, Size displaySize) {
    if (!_activePointers.containsKey(pointer)) return;
    final point = _clampLogicPoint(_toLogicPoint(localPosition, displaySize));
    setState(() {
      _activePointers[pointer] = point;
      _captureActivePoints();
    });
  }

  void _handlePointerEnd(int pointer) {
    if (!_activePointers.containsKey(pointer)) return;
    setState(() {
      _captureActivePoints();
      _activePointers.remove(pointer);
    });
  }

  void _captureActivePoints() {
    if (!_isValidPointCount(_activePointers.length)) return;
    _points
      ..clear()
      ..addAll(_activePointers.values);
  }

  bool _isValidPointCount(int count) {
    return count >= _minimumPointCount && count <= _maximumPointCount;
  }

  Offset _clampLogicPoint(Offset point) {
    return Offset(
      point.dx.clamp(0, _logicWidth),
      point.dy.clamp(0, _logicHeight),
    );
  }

  /// 将盖章区「实际显示尺寸」上的触点映射到逻辑 800×600（与 H5 一致）。
  Offset _toLogicPoint(Offset localPosition, Size displaySize) {
    if (displaySize.width <= 0 || displaySize.height <= 0) {
      return Offset.zero;
    }
    return Offset(
      localPosition.dx / displaySize.width * _logicWidth,
      localPosition.dy / displaySize.height * _logicHeight,
    );
  }

  List<List<int>> get _touchPoints {
    return _points
        .map((point) => [point.dx.round(), point.dy.round()])
        .toList();
  }

  Future<void> _submit() async {
    if (!_isValidPointCount(_points.length)) {
      AppToast.show(context, '请用四指同时按压采集 4 个点位');
      return;
    }

    final sealBody = <String, dynamic>{
      'ruleCode': _ruleCode,
      'touchPoints': _touchPoints,
      'authStoreCode': _authStoreCode,
      'coordinateSystem': 3,
    };
    setState(() => _submitting = true);

    try {
      developer.log(
        const JsonEncoder.withIndent('  ').convert(sealBody),
        name: 'SealDebugRequest',
      );
      final response = await _dio.post<dynamic>(_endpoint, data: sealBody);
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{'raw': response.data};
      developer.log(
        const JsonEncoder.withIndent('  ').convert(data),
        name: 'SealDebugResponse',
      );
      final stampSuccess = _stampMatched(data);
      if (_activityId.isEmpty || _shopId.isEmpty) {
        if (!mounted) return;
        AppToast.show(context, stampSuccess ? '印章识别成功' : '印章识别失败');
        return;
      }
      final requestId = _pendingStampRequestId ??= newActivityRequestId(
        'stamp',
      );
      final detail = await ref
          .read(memberActivityRepositoryProvider)
          .submitStamp(
            activityId: _activityId,
            shopId: _shopId,
            stampSuccess: stampSuccess,
            requestId: requestId,
          );
      _pendingStampRequestId = null;
      if (!mounted) return;
      if (!stampSuccess) {
        AppToast.show(context, '印章识别失败，请重新按压');
        return;
      }
      AppToast.show(context, '集章成功');
      context.pop<MemberActivityDetail>(detail);
    } catch (error) {
      if (!mounted) return;
      if (error is MemberActivityApiException && error.requiresLogin) {
        await ref.read(appStorageProvider).clearAuth();
        ref.read(authRevisionProvider.notifier).bump();
        if (!mounted) return;
        AppToast.show(context, '登录状态已过期，请重新登录');
        await context.push('/login');
        return;
      }
      AppToast.show(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data != null) return data.toString();
      return error.message ?? '请求失败';
    }
    return error.toString();
  }

  bool _stampMatched(Map<String, dynamic> response) {
    bool read(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().toLowerCase();
      return text == 'true' || text == '1' || text == 'success';
    }

    if (response.containsKey('matched')) return read(response['matched']);
    if (response.containsKey('stampSuccess')) {
      return read(response['stampSuccess']);
    }
    final nested = response['data'];
    if (nested is Map) {
      if (nested.containsKey('matched')) return read(nested['matched']);
      if (nested.containsKey('stampSuccess')) {
        return read(nested['stampSuccess']);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(title: const Text('电子印章')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 12),
            _SealCanvas(
              points: List<Offset>.of(_points),
              activePoints: List<Offset>.of(_activePointers.values),
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerEnd: _handlePointerEnd,
            ),
            const _StampGuideCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SealCanvas extends StatelessWidget {
  const _SealCanvas({
    required this.points,
    required this.activePoints,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerEnd,
  });

  final List<Offset> points;
  final List<Offset> activePoints;
  final void Function(int pointer, Offset localPosition, Size size)
  onPointerDown;
  final void Function(int pointer, Offset localPosition, Size size)
  onPointerMove;
  final ValueChanged<int> onPointerEnd;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 800 / 600,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final displaySize = Size(constraints.maxWidth, constraints.maxHeight);
          return RawGestureDetector(
            gestures: <Type, GestureRecognizerFactory>{
              EagerGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                    EagerGestureRecognizer.new,
                    (recognizer) {},
                  ),
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => onPointerDown(
                event.pointer,
                event.localPosition,
                displaySize,
              ),
              onPointerMove: (event) => onPointerMove(
                event.pointer,
                event.localPosition,
                displaySize,
              ),
              onPointerUp: (event) => onPointerEnd(event.pointer),
              onPointerCancel: (event) => onPointerEnd(event.pointer),
              child: CustomPaint(
                size: displaySize,
                painter: _SealCanvasPainter(
                  points: points,
                  activePoints: activePoints,
                  logicWidth: 800,
                  logicHeight: 600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SealCanvasPainter extends CustomPainter {
  const _SealCanvasPainter({
    required this.points,
    required this.activePoints,
    required this.logicWidth,
    required this.logicHeight,
  });

  final List<Offset> points;
  final List<Offset> activePoints;
  final double logicWidth;
  final double logicHeight;

  Offset _toDisplay(Offset logic, Size size) {
    return Offset(
      logic.dx / logicWidth * size.width,
      logic.dy / logicHeight * size.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final panel = RRect.fromRectAndRadius(bounds, const Radius.circular(12));
    final backgroundPaint = Paint()..color = Colors.white;
    final gridPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(panel, backgroundPaint);
    canvas.save();
    canvas.clipRRect(panel);
    for (var index = 1; index < 3; index++) {
      final x = size.width * index / 3;
      final y = size.height * index / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.restore();
    canvas.drawRRect(panel, gridPaint);

    final pointPaint = Paint()..color = const Color(0xFF126CFF);
    for (var i = 0; i < points.length; i++) {
      final point = _toDisplay(points[i], size);
      canvas.drawCircle(point, 7, pointPaint);
      final painter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        point - Offset(painter.width / 2, painter.height / 2),
      );
    }

    final activePaint = Paint()
      ..color = const Color(0xCCDD1F1F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final activePoint in activePoints) {
      canvas.drawCircle(_toDisplay(activePoint, size), 11, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SealCanvasPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.activePoints != activePoints ||
        oldDelegate.logicWidth != logicWidth ||
        oldDelegate.logicHeight != logicHeight;
  }
}

class _StampGuideCard extends StatelessWidget {
  const _StampGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(26, 23, 26, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '集章说明',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 14),
          Text(
            '到店消费后出示此页面，由店员完成电子盖章。点位按照采集顺序显示，后续可用于防伪校验或门店核销。',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
