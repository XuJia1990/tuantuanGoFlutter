import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    final uri = Uri.tryParse(widget.url);
    if (uri != null && uri.hasScheme) {
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
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.url.isEmpty
                ? const Center(child: Text('广告地址为空'))
                : WebViewWidget(controller: _controller),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 20,
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
}
