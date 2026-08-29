import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../shared/widgets/cached_image.dart';

class AdWebViewPage extends StatefulWidget {
  const AdWebViewPage({required this.url, super.key});

  final String url;

  @override
  State<AdWebViewPage> createState() => _AdWebViewPageState();
}

class _AdWebViewPageState extends State<AdWebViewPage> {
  late final WebViewController _controller;
  Timer? _timer;
  int _countDown = 5;

  bool get _isImageAd {
    final uri = Uri.tryParse(widget.url);
    final path = (uri?.path ?? widget.url).toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif');
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    final uri = Uri.tryParse(widget.url);
    if (!_isImageAd && uri != null && uri.hasScheme) {
      _controller.loadRequest(uri);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countDown <= 1) {
        timer.cancel();
        setState(() => _countDown = 0);
      } else {
        setState(() => _countDown -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _closeAd() {
    _timer?.cancel();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildAdContent()),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            right: 20,
            child: GestureDetector(
              onTap: _closeAd,
              child: Container(
                height: 35,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _countDown > 0 ? '${_countDown}s 跳过' : '关闭广告',
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdContent() {
    if (widget.url.isEmpty) {
      return const Center(
        child: Text('广告地址为空', style: TextStyle(color: Colors.white)),
      );
    }
    if (_isImageAd) {
      return AppCachedNetworkImage(
        imageUrl: widget.url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorWidget: const Center(
          child: Text('广告加载失败', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    return WebViewWidget(controller: _controller);
  }
}
