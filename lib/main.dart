import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/core/payment/wechat_pay_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WeChatPayService.instance.init();
  runApp(const ProviderScope(child: TuanTuanGoApp()));
}
