import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/alarm_sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alarm Sound Options and Channel Mapping Tests', () {
    test('AlarmSoundOption defines 4 high-quality custom tones', () {
      expect(AlarmSoundOption.customTones.length, 4);
      final ids = AlarmSoundOption.customTones.map((t) => t.id).toList();
      expect(ids, contains('custom_meditime_campana'));
      expect(ids, contains('custom_meditime_clasica'));
      expect(ids, contains('custom_meditime_digital'));
      expect(ids, contains('custom_meditime_suave'));

      for (var tone in AlarmSoundOption.customTones) {
        expect(tone.category, 'custom');
        expect(tone.resourceName, isNotNull);
        expect(tone.title.isNotEmpty, true);
        expect(tone.subtitle.isNotEmpty, true);
      }
    });

    test('AlarmSoundOption defines system phone alarm and ringtone options', () {
      expect(AlarmSoundOption.systemAlarmDefault.id, 'system_alarm');
      expect(AlarmSoundOption.systemAlarmDefault.category, 'phone');
      expect(AlarmSoundOption.systemAlarmDefault.uri, 'content://settings/system/alarm_alert');

      expect(AlarmSoundOption.systemRingtoneDefault.id, 'system_ringtone');
      expect(AlarmSoundOption.systemRingtoneDefault.category, 'phone');
      expect(AlarmSoundOption.systemRingtoneDefault.uri, 'content://settings/system/ringtone');
    });

    test('NotificationService.getAlarmChannelId returns distinct IDs based on sound', () {
      final customId = NotificationService.getAlarmChannelId(
        type: 'custom',
        resourceName: 'meditime_campana',
      );
      expect(customId, 'meditime_alarm_custom_meditime_campana');

      final defaultId = NotificationService.getAlarmChannelId(
        type: 'system_alarm',
      );
      expect(defaultId, 'meditime_alarm_sys_default');

      final ringtoneId = NotificationService.getAlarmChannelId(
        type: 'system_ringtone',
      );
      expect(ringtoneId, 'meditime_alarm_sys_ringtone');

      final phoneToneId = NotificationService.getAlarmChannelId(
        type: 'phone_tone',
        uri: 'content://media/internal/audio/media/42',
      );
      expect(phoneToneId.startsWith('meditime_alarm_phone_'), true);
    });

    test('NotificationService.getAlarmSound returns correct AndroidNotificationSound types', () {
      final customSound = NotificationService.getAlarmSound(
        type: 'custom',
        resourceName: 'meditime_clasica',
      );
      expect(customSound, isA<RawResourceAndroidNotificationSound>());
      expect((customSound as RawResourceAndroidNotificationSound).sound, 'meditime_clasica');

      final defaultSound = NotificationService.getAlarmSound(
        type: 'system_alarm',
      );
      expect(defaultSound, isA<UriAndroidNotificationSound>());
      expect((defaultSound as UriAndroidNotificationSound).sound, 'content://settings/system/alarm_alert');

      final ringtoneSound = NotificationService.getAlarmSound(
        type: 'system_ringtone',
      );
      expect(ringtoneSound, isA<UriAndroidNotificationSound>());
      expect((ringtoneSound as UriAndroidNotificationSound).sound, 'content://settings/system/ringtone');

      final pickedSound = NotificationService.getAlarmSound(
        type: 'phone_tone',
        uri: 'content://media/internal/audio/media/99',
      );
      expect(pickedSound, isA<UriAndroidNotificationSound>());
      expect((pickedSound as UriAndroidNotificationSound).sound, 'content://media/internal/audio/media/99');
    });
  });

  group('PreferenceService Alarm Sound Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default values return system_alarm and default URI', () async {
      final pref = PreferenceService();
      expect(await pref.getAlarmSoundType(), 'system_alarm');
      expect(await pref.getAlarmSoundTitle(), 'Alarma del teléfono (Predeterminada)');
      expect(await pref.getAlarmSoundUri(), 'content://settings/system/alarm_alert');
      expect(await pref.getAlarmSoundResource(), isNull);
    });

    test('saveAlarmSound and retrieve custom tone properly', () async {
      final pref = PreferenceService();
      await pref.saveAlarmSound(
        type: 'custom',
        title: 'Campana Médica',
        resourceName: 'meditime_campana',
      );

      expect(await pref.getAlarmSoundType(), 'custom');
      expect(await pref.getAlarmSoundTitle(), 'Campana Médica');
      expect(await pref.getAlarmSoundResource(), 'meditime_campana');
      expect(await pref.getAlarmSoundUri(), isNull);
    });

    test('saveAlarmSound and retrieve picked phone tone properly', () async {
      final pref = PreferenceService();
      await pref.saveAlarmSound(
        type: 'phone_tone',
        title: 'Morning Song',
        uri: 'content://media/internal/audio/media/105',
      );

      expect(await pref.getAlarmSoundType(), 'phone_tone');
      expect(await pref.getAlarmSoundTitle(), 'Morning Song');
      expect(await pref.getAlarmSoundUri(), 'content://media/internal/audio/media/105');
      expect(await pref.getAlarmSoundResource(), isNull);
    });
  });
}
