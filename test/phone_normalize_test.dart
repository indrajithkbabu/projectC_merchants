import 'package:flutter_test/flutter_test.dart';
import 'package:project_c/helper/phone_normalize.dart';

void main() {
  group('PhoneNormalize.toE164', () {
    test('normalizes Indian 10-digit mobiles', () {
      expect(PhoneNormalize.toE164('9876543210'), '+919876543210');
      expect(PhoneNormalize.toE164('09876543210'), '+919876543210');
      expect(PhoneNormalize.toE164('91 98765 43210'), '+919876543210');
      expect(PhoneNormalize.toE164('+91 98765-43210'), '+919876543210');
    });

    test('strips trunk 0 after +91', () {
      expect(PhoneNormalize.toE164('+91 09876543210'), '+919876543210');
    });

    test('accepts already-E.164 values', () {
      expect(PhoneNormalize.toE164('+14155552671'), '+14155552671');
    });

    test('accepts Android-style digits without plus for long numbers', () {
      expect(PhoneNormalize.toE164('14155552671'), '+14155552671');
    });
  });

  group('PhoneNormalize.nationalKey', () {
    test('returns last 10 digits across formats', () {
      expect(PhoneNormalize.nationalKey('+919876543210'), '9876543210');
      expect(PhoneNormalize.nationalKey('9876543210'), '9876543210');
      expect(PhoneNormalize.nationalKey('91-98765-43210'), '9876543210');
    });
  });
}
