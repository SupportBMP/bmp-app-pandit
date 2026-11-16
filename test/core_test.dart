import 'package:bookmypoojapandit/core/state/session.dart';
import 'package:bookmypoojapandit/core/storage/legacy_async_storage.dart';
import 'package:bookmypoojapandit/core/utils/format.dart';
import 'package:bookmypoojapandit/core/utils/phone.dart';
import 'package:bookmypoojapandit/features/bookings/booking_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legacy AsyncStorage values', () {
    test('token written with JSON.stringify decodes to the raw token', () {
      expect(LegacyAsyncStorage.decode('"eyJhbGciOi.abc"'), 'eyJhbGciOi.abc');
    });
    test('double-encoded USER decodes to a map', () {
      const raw = r'"{\"name\":\"Ram\",\"KYCStatus\":\"approved\"}"';
      final v = LegacyAsyncStorage.decode(raw);
      expect(v, isA<Map>());
      expect((v as Map)['KYCStatus'], 'approved');
    });
    test('language code', () => expect(LegacyAsyncStorage.decode('"hi"'), 'hi'));
    test('null stays null', () => expect(LegacyAsyncStorage.decode(null), isNull));
  });

  group('post-login routing (Splash / Verify parity)', () {
    const full = {'name': 'a', 'address': 'b', 'city': 'c', 'state': 'd', 'pincode': '1'};
    test('approved + seen intro → home', () {
      expect(destinationFor({'KYCStatus': 'approved', 'hasSeenIntroduction': true}), AuthDestination.home);
    });
    test('approved, first time → intro', () {
      expect(destinationFor({'KYCStatus': 'approved'}), AuthDestination.intro);
    });
    test('approved new account (201) → referral', () {
      expect(destinationFor({'KYCStatus': 'approved'}, isNewAccount: true), AuthDestination.referral);
    });
    test('rejected → waiting', () => expect(destinationFor({'KYCStatus': 'rejected'}), AuthDestination.waiting));
    test('pending with basic info → waiting', () {
      expect(destinationFor({...full, 'KYCStatus': 'pending'}), AuthDestination.waiting);
    });
    test('pending without basic info → profile form', () {
      expect(destinationFor({'KYCStatus': 'pending', 'name': 'x'}), AuthDestination.profileInfo);
    });
  });

  group('time formatting', () {
    test('to12Hour', () {
      expect(to12Hour('00:05'), '12:05 AM');
      expect(to12Hour('13:30'), '1:30 PM');
      expect(to12Hour(null), 'TBD');
    });
    test('to24Hour', () {
      expect(to24Hour('12:00', 'AM'), '00:00');
      expect(to24Hour('7:15', 'PM'), '19:15');
    });
  });

  group('phone parsing', () {
    test('+91 number', () {
      final p = parsePhone('+91 98765 43210');
      expect(p.code, '91');
      expect(p.number, '9876543210');
    });
    test('UAE number', () {
      final p = parsePhone('+971 50 123 4567');
      expect(p.code, '971');
      expect(p.number, '501234567');
    });
    test('local 10-digit defaults to India', () => expect(parsePhone('9876543210').code, '91'));
  });

  group('booking timing', () {
    final now = DateTime.utc(2026, 1, 10, 10).toLocal();
    test('within start/end is now', () {
      final d = {
        'startDateTime': DateTime.utc(2026, 1, 10, 9).toIso8601String(),
        'endDateTime': DateTime.utc(2026, 1, 10, 11).toIso8601String(),
      };
      expect(bookingTiming(d, now), (true, false));
    });
    test('after end is over', () {
      final d = {
        'startDateTime': DateTime.utc(2026, 1, 9, 9).toIso8601String(),
        'endDateTime': DateTime.utc(2026, 1, 9, 11).toIso8601String(),
      };
      expect(bookingTiming(d, now), (false, true));
    });
  });
}
