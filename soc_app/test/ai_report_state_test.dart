import 'package:flutter_test/flutter_test.dart';
import 'package:soc_app/presentation/providers/ai_report_provider.dart';

void main() {
  group('AiReportState', () {
    test('default values', () {
      const state = AiReportState();
      expect(state.streamContent, '');
      expect(state.reasoningContent, isNull);
      expect(state.isGenerating, false);
      expect(state.error, isNull);
    });

    test('copyWith updates fields', () {
      const state = AiReportState();
      final modified = state.copyWith(
        streamContent: 'hello',
        reasoningContent: 'thinking...',
        isGenerating: true,
      );
      expect(modified.streamContent, 'hello');
      expect(modified.reasoningContent, 'thinking...');
      expect(modified.isGenerating, true);
      expect(modified.error, isNull);
    });

    test('copyWith clears error when null', () {
      final state = AiReportState(error: 'some error');
      expect(state.error, 'some error');
      final reset = state.copyWith(error: null);
      expect(reset.error, isNull);
    });
  });
}
