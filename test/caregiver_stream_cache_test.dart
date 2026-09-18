import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/core/stream_cache.dart';
import 'package:meditime/models/caregiver_profile.dart';

void main() {
  group('Caregiver and StreamCache Tests', () {
    test('CaregiverProfile serializes and deserializes external linked users correctly', () {
      final linkedProfile = CaregiverProfile(
        id: 'user_patient_456',
        name: 'Juan David Cabra Murcia',
        relationship: 'Familiar Vinculado',
        colorHex: '#4F46E5',
        isExternalUser: true,
        email: 'juandavid@example.com',
        linkedUid: 'user_patient_456',
      );

      final map = linkedProfile.toMap();
      expect(map['isExternalUser'], true);
      expect(map['email'], 'juandavid@example.com');
      expect(map['linkedUid'], 'user_patient_456');

      final reconstructed = CaregiverProfile.fromMap('user_patient_456', map);
      expect(reconstructed.id, 'user_patient_456');
      expect(reconstructed.name, 'Juan David Cabra Murcia');
      expect(reconstructed.isExternalUser, true);
      expect(reconstructed.email, 'juandavid@example.com');
      expect(reconstructed.linkedUid, 'user_patient_456');
    });

    test('StreamCache cleans up errored stream so retry can create a new subscription', () async {
      final cache = StreamCache<String, int>();
      int attempt = 0;

      Stream<int> factory() {
        attempt++;
        if (attempt == 1) {
          return Stream<int>.error(Exception('Permission denied'));
        } else {
          return Stream<int>.value(42);
        }
      }

      final completer = Completer<dynamic>();
      final stream1 = cache.getStream('patient_1', factory);
      stream1.listen(
        (_) {},
        onError: (err) {
          if (!completer.isCompleted) {
            completer.complete(err);
          }
        },
      );

      final caughtError = await completer.future;
      expect(caughtError, isNotNull);
      expect(caughtError.toString(), contains('Permission denied'));

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final stream2 = cache.getStream('patient_1', factory);
      final result = await stream2.first;

      expect(result, 42);
      expect(attempt, 2);
    });
  });
}
