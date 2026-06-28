import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AdWebViewPage extends StatefulWidget {
  const AdWebViewPage({required this.url, super.key});

  final String url;

  @override
  State<AdWebViewPage> createState() => _AdWebViewPageState();
}

class _AdWebViewPageState extends State<AdWebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    final uri = Uri.tryParse(widget.url);
    if (uri != null && uri.hasScheme) {
      _controller.loadRequest(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.url.isEmpty
          ? const Center(child: Text('广告地址为空'))
          : WebViewWidget(controller: _controller),
    );
  }
}
