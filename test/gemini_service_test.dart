import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiService - Tool Schemas', () {
    test('All function definitions strictly declare a valid parameters object', () {
      final tools = GeminiService.tools;
      expect(tools.isNotEmpty, isTrue);

      for (final tool in tools) {
        expect(tool['type'], equals('function'));
        final function = tool['function'] as Map<String, dynamic>;
        expect(function['name'], isNotNull);
        expect(function['parameters'], isNotNull,
            reason: "Function \${function['name']} must declare parameters object");
        final parameters = function['parameters'] as Map<String, dynamic>;
        expect(parameters['type'], equals('object'),
            reason: "Function \${function['name']} parameters must be of type object");
      }
    });

    test('Zero-argument tools have empty properties object to prevent Groq 400', () {
      final zeroArgToolNames = [
        'get_today_medications',
        'get_tomorrow_medications',
        'get_active_treatments',
        'show_adherence_chart',
      ];

      final tools = GeminiService.tools;
      for (final name in zeroArgToolNames) {
        final tool = tools.firstWhere(
          (t) => (t['function'] as Map<String, dynamic>)['name'] == name,
        );
        final function = tool['function'] as Map<String, dynamic>;
        final parameters = function['parameters'] as Map<String, dynamic>;
        expect(parameters['type'], equals('object'));
        expect(parameters['properties'], isA<Map<String, dynamic>>());
      }
    });
  });

  group('GeminiService - API Key Resolution', () {
    test('Uses explicit API key when provided', () async {
      final service = GeminiService(apiKey: 'gsk_explicit_key');
      final effectiveKey = await service.getEffectiveApiKey();
      expect(effectiveKey, equals('gsk_explicit_key'));
    });

    test('Falls back to environment variable when explicit key is null or empty', () async {
      final service = GeminiService(apiKey: null);
      final effectiveKey = await service.getEffectiveApiKey();
      expect(effectiveKey, isA<String>());
    });
  });
}
