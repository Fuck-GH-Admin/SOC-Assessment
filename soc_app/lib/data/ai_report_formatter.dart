/// 对 AI 生成的报告文本做规范化处理。
///
/// 主要职责：
/// 1. 清理格式缺陷（多余空行、前后空白、残缺 Markdown）
/// 2. 校验固定模块是否存在，缺失时自动补全占位
/// 3. 返回标准化后的 Markdown 文本
class AiReportFormatter {
  /// 期望出现的模块标题（AI prompt 中要求的四个部分）。
  static const _expectedSections = [
    '数据解读',
    '侵蚀影响',
    '秸秆还田',
    '综合评价',
  ];

  /// 对 AI 输出做规范化处理。
  static String format(String raw) {
    if (raw.trim().isEmpty) return raw;

    var text = raw.trim();

    // ── 清理冗余空行 ──────────────────────────────────────
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r'(?<=\n) +'), '');
    text = text.replaceAll(RegExp(r' +(\n)'), '\n');

    // ── 修复常见 Markdown 缺陷 ────────────────────────────
    // 段落前补空行
    text = text.replaceAllMapped(
      RegExp(r'((?<!\n)\n)([^*\-\|#\n\s])'),
      (m) => '\n\n${m.group(2)!}',
    );

    // 行首缩进清理
    text = text.replaceAll(RegExp(r'^  +', multiLine: true), '');

    // ── 校验并补全缺失模块 ────────────────────────────────
    text = _ensureSections(text);

    // ── 尾部清理 ──────────────────────────────────────────
    text = text.replaceAll(RegExp(r'\n{3,}$'), '\n\n');
    text = text.trim();

    return text;
  }

  /// 检查并补全缺失的模块。
  static String _ensureSections(String text) {
    final lower = text.toLowerCase();
    final buffer = StringBuffer(text);

    for (final section in _expectedSections) {
      // 匹配多种可能的标题形式："数字. 模块名"、"### 模块名"、"模块名"
      final patterns = [
        RegExp(r'(?:^|\n)\s*\d+\.\s*' + _escape(section)),
        RegExp(r'(?:^|\n)#{1,3}\s*' + _escape(section)),
        RegExp(r'(?:^|\n)' + _escape(section)),
      ];

      final found = patterns.any((p) => p.hasMatch(text));
      if (!found) {
        buffer.write('\n\n${_sectionPlaceholder(section)}\n');
      }
    }

    return buffer.toString().trim();
  }

  static String _sectionPlaceholder(String section) {
    return '### ${section}（该部分内容 AI 生成不完整）\n\n此部分内容未能完整生成，请参考原始数据自行分析。';
  }

  static String _escape(String text) {
    return RegExp.escape(text);
  }

  /// 判断 AI 输出是否为严重缺陷（空内容、乱码、截断等）。
  static ReportQuality classify(String raw) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) return ReportQuality.empty;

    if (trimmed.length < 20) return ReportQuality.truncated;

    // 检测是否被截断（最后一个字符不是合理的结束符）
    final lastChar = trimmed.codeUnitAt(trimmed.length - 1);
    if (lastChar != '.'.codeUnitAt(0) &&
        lastChar != '!'.codeUnitAt(0) &&
        lastChar != '?'.codeUnitAt(0) &&
        lastChar != '。'.codeUnitAt(0) &&
        lastChar != '！'.codeUnitAt(0) &&
        lastChar != '？'.codeUnitAt(0) &&
        lastChar != ')'.codeUnitAt(0) &&
        lastChar != ']'.codeUnitAt(0) &&
        lastChar != '》'.codeUnitAt(0) &&
        lastChar != '"'.codeUnitAt(0)) {
      return ReportQuality.truncated;
    }

    // 检测模块完整性
    var presentSections = 0;
    for (final section in _expectedSections) {
      if (trimmed.contains(section)) presentSections++;
    }
    if (presentSections == 0) return ReportQuality.incomplete;
    if (presentSections < _expectedSections.length) {
      return ReportQuality.partial;
    }

    return ReportQuality.complete;
  }
}

/// AI 报告质量等级。
enum ReportQuality {
  /// 完全为空
  empty,

  /// 严重截断（太短或末尾不完整）
  truncated,

  /// 缺少所有模块标题
  incomplete,

  /// 部分模块缺失
  partial,

  /// 内容完整
  complete,
}
