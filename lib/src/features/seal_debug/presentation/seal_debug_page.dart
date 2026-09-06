import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/ui/app_toast.dart';

class SealDebugPage extends StatefulWidget {
  const SealDebugPage({super.key});

  @override
  State<SealDebugPage> createState() => _SealDebugPageState();
}

class _SealDebugPageState extends State<SealDebugPage> {
  /// 逻辑坐标系（与 coordinateSystem=3 / H5 sealTest 一致），不是物理像素画布尺寸。
  static const _logicWidth = 800.0;
  static const _logicHeight = 600.0;
  static const _minimumPointCount = 4;
  static const _maximumPointCount = 4;
  static const _endpoint =
      'https://wvxvb.cn/app/signstore/sealrule/compareSimilarity/act004';

  final _ruleCodeController = TextEditingController(text: 'RULERsssFFEW1');
  final _authStoreCodeController = TextEditingController(text: 'UYYshiZkwrHO');
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  final _points = <Offset>[];
  final _activePointers = <int, Offset>{};
  bool _submitting = false;
  Map<String, dynamic>? _lastRequest;
  Map<String, dynamic>? _response;
  String? _error;

  @override
  void dispose() {
    _ruleCodeController.dispose();
    _authStoreCodeController.dispose();
    super.dispose();
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
      _lastRequest = null;
      _response = null;
      _error = null;
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
      _lastRequest = null;
      _response = null;
      _error = null;
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
    final ruleCode = _ruleCodeController.text.trim();
    final authStoreCode = _authStoreCodeController.text.trim();
    if (ruleCode.isEmpty || authStoreCode.isEmpty) {
      AppToast.show(context, '请填写 ruleCode 和 authStoreCode');
      return;
    }
    if (!_isValidPointCount(_points.length)) {
      AppToast.show(context, '请用四指同时按压采集 4 个点位');
      return;
    }

    final body = <String, dynamic>{
      'ruleCode': ruleCode,
      'touchPoints': _touchPoints,
      'authStoreCode': authStoreCode,
      'coordinateSystem': 3,
    };

    setState(() {
      _submitting = true;
      _lastRequest = {'method': 'POST', 'url': _endpoint, 'data': body};
      _response = null;
      _error = null;
    });

    try {
      developer.log(
        const JsonEncoder.withIndent('  ').convert(body),
        name: 'SealDebugRequest',
      );
      final response = await _dio.post<dynamic>(_endpoint, data: body);
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{'raw': response.data};
      developer.log(
        const JsonEncoder.withIndent('  ').convert(data),
        name: 'SealDebugResponse',
      );
      if (!mounted) return;
      setState(() => _response = data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
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

  void _clearPoints() {
    setState(() {
      _points.clear();
      _activePointers.clear();
      _lastRequest = null;
      _response = null;
      _error = null;
    });
  }

  void _useTemplatePoints() {
    final raw = _response?['templatePoints'];
    if (raw is! List) return;
    final points = <Offset>[];
    for (final item in raw) {
      if (item is List && item.length >= 2) {
        final x = _asDouble(item[0]);
        final y = _asDouble(item[1]);
        if (x != null && y != null) points.add(Offset(x, y));
      }
    }
    if (points.isEmpty) return;
    setState(() {
      _points
        ..clear()
        ..addAll(points.take(_maximumPointCount).map(_clampLogicPoint));
      _activePointers.clear();
      _lastRequest = null;
      _response = null;
      _error = null;
    });
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final matched = _response?['matched'] == true;
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(title: const Text('印章接口测试')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _SealCanvas(
              points: List<Offset>.of(_points),
              activePoints: List<Offset>.of(_activePointers.values),
              minimumPointCount: _minimumPointCount,
              maximumPointCount: _maximumPointCount,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerEnd: _handlePointerEnd,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PointList(points: _touchPoints),
                  if (_lastRequest != null) ...[
                    const SizedBox(height: 12),
                    _ResultPanel(
                      title: '请求参数',
                      text: const JsonEncoder.withIndent(
                        '  ',
                      ).convert(_lastRequest),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ResultPanel(title: '请求失败', text: _error!, danger: true),
                  ],
                  if (_response != null) ...[
                    const SizedBox(height: 12),
                    _ResultPanel(
                      title: matched ? '匹配成功' : '匹配失败',
                      text: const JsonEncoder.withIndent(
                        '  ',
                      ).convert(_response),
                      danger: !matched,
                      trailing: _response?['templatePoints'] is List
                          ? TextButton(
                              onPressed: _useTemplatePoints,
                              child: const Text('使用标准点位'),
                            )
                          : null,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _Field(controller: _ruleCodeController, label: 'ruleCode'),
                  const SizedBox(height: 10),
                  _Field(
                    controller: _authStoreCodeController,
                    label: 'authStoreCode',
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(text: '重新采集点位', onTap: _clearPoints),
                  const SizedBox(height: 10),
                  _SubmitButton(
                    loading: _submitting,
                    onTap: _submitting || !_isValidPointCount(_points.length)
                        ? null
                        : _submit,
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

class _SealCanvas extends StatelessWidget {
  const _SealCanvas({
    required this.points,
    required this.activePoints,
    required this.minimumPointCount,
    required this.maximumPointCount,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerEnd,
  });

  final List<Offset> points;
  final List<Offset> activePoints;
  final int minimumPointCount;
  final int maximumPointCount;
  final void Function(int pointer, Offset localPosition, Size size)
  onPointerDown;
  final void Function(int pointer, Offset localPosition, Size size)
  onPointerMove;
  final ValueChanged<int> onPointerEnd;

  @override
  Widget build(BuildContext context) {
    final statusText = activePoints.isNotEmpty
        ? '触点 ${activePoints.length}（需同时 $minimumPointCount 指）'
        : points.length >= minimumPointCount
        ? '已采集 ${points.length} 个点位，已自动请求'
        : '需要同时 4 指';

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
            child: Stack(
              children: [
                Positioned.fill(
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
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '印章按压区',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
    final bg = Paint()..color = const Color(0xFFDDDDDD);

    canvas.drawRect(Offset.zero & size, bg);

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

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onTap, child: Text(text));
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('请求接口'),
      ),
    );
  }
}

class _PointList extends StatelessWidget {
  const _PointList({required this.points});

  final List<List<int>> points;

  @override
  Widget build(BuildContext context) {
    return _ResultPanel(
      title: 'touchPoints',
      text: points.isEmpty
          ? '[]'
          : const JsonEncoder.withIndent('  ').convert(points),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.title,
    required this.text,
    this.danger = false,
    this.trailing,
  });

  final String title;
  final String text;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: danger ? const Color(0xFFFFD5D5) : const Color(0xFFEDEDED),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: danger ? Colors.red : AppTheme.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }
}
