import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_go_flutter/src/features/home/data/home_models.dart';

void main() {
  test('keeps an API error message when data is null', () {
    var parserCalled = false;

    final envelope = ApiEnvelope.parse<Map<String, dynamic>>(
      {'code': 400, 'msg': '手机号或密码错误', 'data': null},
      (data) {
        parserCalled = true;
        return Map<String, dynamic>.from(data as Map);
      },
    );

    expect(envelope.isSuccess, isFalse);
    expect(envelope.message, '手机号或密码错误');
    expect(envelope.data, isNull);
    expect(parserCalled, isFalse);
  });

  test('parses non-null response data', () {
    final envelope = ApiEnvelope.parse<Map<String, dynamic>>({
      'code': 200,
      'msg': '',
      'data': {'accessToken': 'token'},
    }, (data) => Map<String, dynamic>.from(data as Map));

    expect(envelope.isSuccess, isTrue);
    expect(envelope.data?['accessToken'], 'token');
  });
}
