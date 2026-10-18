import 'package:flutter_test/flutter_test.dart';
import 'package:msmototaxi/core/auth/brazil_phone.dart';

void main() {
  test('accepts a Registro mobile in national and E.164 forms', () {
    expect(brazilMobileE164('13999999999'), '+5513999999999');
    expect(brazilMobileE164('(13) 99999-9999'), '+5513999999999');
    expect(brazilMobileE164('+55 13 99999-9999'), '+5513999999999');
    expect(brazilMobileE164('5513999999999'), '+5513999999999');
    expect(brazilMobileE164('013999999999'), '+5513999999999');
    expect(brazilMobileE164('005513999999999'), '+5513999999999');
  });

  test('keeps DDD 55 (Rio Grande do Sul) distinct from country code 55', () {
    expect(brazilMobileE164('55999999999'), '+5555999999999');
    expect(brazilMobileE164('5555999999999'), '+5555999999999');
  });

  test('rejects landlines, unknown DDDs, and non-Brazilian numbers', () {
    expect(brazilMobileE164(''), isNull);
    expect(brazilMobileE164('123'), isNull);
    expect(brazilMobileE164('1133334444'), isNull);
    expect(brazilMobileE164('11333344444'), isNull);
    expect(brazilMobileE164('10999999999'), isNull);
    expect(brazilMobileE164('+14155551234'), isNull);
  });
}
