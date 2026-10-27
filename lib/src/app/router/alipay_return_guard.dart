import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// This link only asks the app to check its own pending order. No payment result
/// or order ID supplied by the browser is trusted.
class AlipayReturnLink {
  static const appUrl = 'tuantuango://app/payment-return';

  static bool matches(Uri uri) =>
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      uri.path == '/payment-return' &&
      ((uri.scheme == 'tuantuango' && uri.host == 'app') ||
          (uri.scheme == 'https' && uri.host == 'share.tuantuan-go.com'));
}

OnEnter alipayReturnGuard({
  required VoidCallback checkPendingPayment,
}) => (context, current, next, router) {
  if (kDebugMode &&
      (next.uri.scheme == 'tuantuango' || next.uri.path == '/payment-return')) {
    debugPrint(
      '[AlipayReturn] scheme=${next.uri.scheme}, host=${next.uri.host}, '
      'path=${next.uri.path}, matched=${AlipayReturnLink.matches(next.uri)}, '
      'currentPage=${current.uri.path}',
    );
  }
  if (!AlipayReturnLink.matches(next.uri)) return const Allow();
  // A normal deep-link navigation would dispose the recharge page and lose
  // the pending order. Keep the existing page and trigger a server check.
  return Block.then(() {
    if (current.uri.path == '/member-recharge') {
      checkPendingPayment();
    } else {
      router.go('/member');
    }
  });
};
