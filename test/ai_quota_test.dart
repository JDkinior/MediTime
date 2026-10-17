import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/services/ai_quota_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AiQuotaService quotaService;
  const testUserId = 'test_user_123';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    quotaService = const AiQuotaService();
  });

  group('AiQuotaService - Daily limits and quotas', () {
    test('Default limits: Free is 20, Premium is 120', () {
      expect(quotaService.getDailyLimit(isPremium: false), equals(20));
      expect(quotaService.getDailyLimit(isPremium: true), equals(120));
    });

    test('Initial state: zero used, all messages remaining, can send', () async {
      final used = await quotaService.getUsedCount(testUserId);
      final remainingFree = await quotaService.getRemainingMessages(testUserId, isPremium: false);
      final remainingPrem = await quotaService.getRemainingMessages(testUserId, isPremium: true);
      final canSend = await quotaService.canSendMessage(testUserId, isPremium: false);

      expect(used, equals(0));
      expect(remainingFree, equals(20));
      expect(remainingPrem, equals(120));
      expect(canSend, isTrue);
    });

    test('Records messages accurately and decrements remaining quota', () async {
      await quotaService.recordMessageSent(testUserId);
      await quotaService.recordMessageSent(testUserId);
      await quotaService.recordMessageSent(testUserId);

      final used = await quotaService.getUsedCount(testUserId);
      final remaining = await quotaService.getRemainingMessages(testUserId, isPremium: false);

      expect(used, equals(3));
      expect(remaining, equals(17));
    });

    test('Enforces free tier quota cutoff at 20 messages', () async {
      for (int i = 0; i < 20; i++) {
        expect(await quotaService.canSendMessage(testUserId, isPremium: false), isTrue);
        await quotaService.recordMessageSent(testUserId);
      }

      final used = await quotaService.getUsedCount(testUserId);
      final remaining = await quotaService.getRemainingMessages(testUserId, isPremium: false);
      final canSend = await quotaService.canSendMessage(testUserId, isPremium: false);

      expect(used, equals(20));
      expect(remaining, equals(0));
      expect(canSend, isFalse);

      // But premium user with 20 used can still send
      expect(await quotaService.canSendMessage(testUserId, isPremium: true), isTrue);
      expect(await quotaService.getRemainingMessages(testUserId, isPremium: true), equals(100));
    });

    test('Automatic midnight rollover resets count when date changes', () async {
      final prefs = await SharedPreferences.getInstance();
      // Simulate yesterday's date
      await prefs.setString('ai_quota_date_$testUserId', '2020-01-01');
      await prefs.setInt('ai_quota_count_$testUserId', 20);

      // Next check today should see 0 used
      final used = await quotaService.getUsedCount(testUserId);
      final canSend = await quotaService.canSendMessage(testUserId, isPremium: false);

      expect(used, equals(0));
      expect(canSend, isTrue);

      // Next message should initialize today's count to 1
      await quotaService.recordMessageSent(testUserId);
      expect(await quotaService.getUsedCount(testUserId), equals(1));
    });

    test('Anti-burst cooldown blocks immediate consecutive sends', () async {
      expect(await quotaService.isCoolingDown(testUserId), isFalse);

      await quotaService.recordMessageSent(testUserId);

      // Immediately after, cooldown must be active
      expect(await quotaService.isCoolingDown(testUserId), isTrue);

      // Zero-duration cooldown check
      expect(await quotaService.isCoolingDown(testUserId, cooldown: Duration.zero), isFalse);
    });

    test('resetQuota clears all user storage keys', () async {
      await quotaService.recordMessageSent(testUserId);
      expect(await quotaService.getUsedCount(testUserId), equals(1));

      await quotaService.resetQuota(testUserId);

      expect(await quotaService.getUsedCount(testUserId), equals(0));
      expect(await quotaService.isCoolingDown(testUserId), isFalse);
    });
  });
}
