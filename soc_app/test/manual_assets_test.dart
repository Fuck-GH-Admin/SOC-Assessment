import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('内置说明书资源齐全且为非空 UTF-8 文本', () async {
    const files = [
      'assets/manual/quick-start.md',
      'assets/manual/user-guide.md',
      'assets/manual/scientific-basis.md',
      'assets/manual/faq.md',
      'assets/manual/glossary.md',
      'assets/manual/changelog.md',
    ];
    for (final f in files) {
      final content = await rootBundle.loadString(f);
      expect(content, isNotEmpty, reason: '$f 不应为空');
    }
    // 口径锚点：说明书关键章节应包含核心口径表述
    final basis = await rootBundle.loadString('assets/manual/scientific-basis.md');
    expect(basis, contains('静态差异'));
    expect(basis, contains('CK'));
    final quickStart = await rootBundle.loadString('assets/manual/quick-start.md');
    expect(quickStart, contains('评估流程'));
  });
}
