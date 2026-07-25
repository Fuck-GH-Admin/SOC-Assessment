import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/engine/soc_calculator.dart';
import '../domain/models/calculation_params.dart';
import '../domain/models/calculation_result.dart';
import '../domain/models/resilience_result.dart';

class PdfExporter {
  static Future<Uint8List> generate({
    required CalculationParams params,
    required CalculationResult result,
    ResilienceResult? resilience,
    String? aiReport,
    required List<Uint8List> chartImages,
  }) async {
    final fontData = await rootBundle.load('assets/fonts/SimHei.ttf');
    final font = pw.Font.ttf(fontData);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'SOC 土壤有机碳评估报告',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                font: font,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '生成时间: ${DateTime.now().toString().substring(0, 19)}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, font: font),
          ),
          pw.SizedBox(height: 16),
          _sectionTitle('输入参数', font),
          _paramTable(params, font),
          pw.SizedBox(height: 16),
          _sectionTitle('计算结果', font),
          _resultTable(result, font),
          pw.SizedBox(height: 6),
          pw.Text(
            '口径说明：当前没有逐年模拟末期数据。报告中的20年/100年字段'
            '只沿用源文档对应的分析范围，数值表示当前侵蚀处理相对'
            '同施肥CK（侵蚀0cm）的静态碳库差，'
            '不代表真实时间序列预测。',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
              font: font,
            ),
          ),
          if (resilience != null) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('CK参考剖面差与管理情景', font),
            _resilienceTable(resilience, font),
            pw.SizedBox(height: 10),
            _strawScenarioTable(resilience, font),
          ],
          pw.SizedBox(height: 16),
          _sectionTitle('数据图表', font),
          for (final image in chartImages) ...[
            pw.SizedBox(height: 12),
            pw.Image(
              pw.MemoryImage(image),
              fit: pw.BoxFit.contain,
              width: 515,
              height: 300,
            ),
          ],
        ],
      ),
    );

    if (aiReport != null && aiReport.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'AI 评估报告',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  font: font,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            ..._renderMarkdown(aiReport, font),
          ],
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _sectionTitle(String text, pw.Font font) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Header(
        level: 1,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            font: font,
          ),
        ),
      ),
    );
  }

  static pw.Widget _paramTable(CalculationParams params, pw.Font font) {
    return pw.TableHelper.fromTextArray(
      headerCount: 1,
      headers: ['参数', '数值', '说明'],
      data: [
        ['算法口径', 'v\$kSocAlgorithmVersion', '用于区分历史计算版本'],
        ['施肥处理', params.fert == 'F' ? '施肥' : '不施肥', ''],
        ['侵蚀强度', '${params.erosion} cm', '土壤侵蚀深度'],
        ['土层', depthDefinitionFor(params.depth).label, '当前计算土层'],
        ['统一土壤容重', params.bd.toStringAsFixed(2), 'g/cm^3；用于全部土层'],
        ['pH值', params.ph.toStringAsFixed(1), '辅助观测，不进入核心公式'],
        ['含水量', params.wc.toStringAsFixed(1), '%；辅助观测'],
        ['黏+粉粒', params.clay.toStringAsFixed(1), '%；辅助观测'],
        ['全氮含量', params.tn.toStringAsFixed(2), 'g/kg；辅助观测'],
        ['秸秆生物量', params.cropBiomass.toStringAsFixed(0), 'kg/ha'],
        ['秸秆碳含量比例', params.strawCarbonRatio.toStringAsFixed(3), '0-1'],
        ['基础凋落物碳输入', params.litterCarbonInput.toStringAsFixed(3), 'kg C/m^2'],
      ],
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        font: font,
      ),
      cellStyle: pw.TextStyle(fontSize: 9, font: font),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
      },
    );
  }

  static pw.Widget _resultTable(CalculationResult result, pw.Font font) {
    return pw.TableHelper.fromTextArray(
      headerCount: 1,
      headers: ['指标', '数值', '单位'],
      data: [
        ['SOC 含量', result.soc.toStringAsFixed(2), 'g/kg'],
        ['当前土层碳库储量', result.carbonStorage.toStringAsFixed(2), 'kg C/m^2'],
        ['碳密度', result.carbonDensity.toStringAsFixed(2), 'kg C/m^3'],
        ['当前土层相对CK碳库差', result.netChange.toStringAsFixed(2), 'kg C/m^2'],
        [
          '当前土层差值/20年（折算）',
          result.recoveryRate.toStringAsFixed(3),
          'kg C/m^2/yr',
        ],
        ['当前土层相对CK损失率', result.lossRate.toStringAsFixed(1), '%'],
      ],
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        font: font,
      ),
      cellStyle: pw.TextStyle(fontSize: 9, font: font),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
      },
    );
  }

  static pw.Widget _resilienceTable(ResilienceResult r, pw.Font font) {
    return pw.TableHelper.fromTextArray(
      headerCount: 1,
      headers: ['指标', '数值', '单位'],
      data: [
        ['表层碳库(0-20cm)', r.carbonPool020.toStringAsFixed(2), 'kg C/m^2'],
        ['剖面碳库(0-60cm)', r.carbonPool060.toStringAsFixed(2), 'kg C/m^2'],
        [
          '0-60cm相对CK差（源文档20年范围）',
          r.netChange20yr.toStringAsFixed(2),
          'kg C/m^2',
        ],
        [
          '0-20cm相对CK差（源文档100年范围）',
          r.netChange100yr.toStringAsFixed(2),
          'kg C/m^2',
        ],
        [
          '0-60cm差值/20年（折算代理）',
          r.recoveryRateAnnual.toStringAsFixed(3),
          'kg C/m^2/yr',
        ],
        ['相对CK状态', r.status, ''],
      ],
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        font: font,
      ),
      cellStyle: pw.TextStyle(fontSize: 9, font: font),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
      },
    );
  }

  static pw.Widget _strawScenarioTable(ResilienceResult r, pw.Font font) {
    return pw.TableHelper.fromTextArray(
      headerCount: 1,
      headers: ['秸秆还田情景', '秸秆碳输入', '系统总碳输入'],
      data: r.strawScenarios
          .map(
            (scenario) => [
              scenario.label,
              scenario.strawInput.toStringAsFixed(3),
              scenario.totalInput.toStringAsFixed(3),
            ],
          )
          .toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        font: font,
      ),
      cellStyle: pw.TextStyle(fontSize: 9, font: font),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
      },
    );
  }

  // ── Markdown rendering helpers ───────────────────────────────────

  static List<pw.Widget> _renderMarkdown(String markdown, pw.Font font) {
    final lines = markdown.split('\n');
    final widgets = <pw.Widget>[];
    var i = 0;

    while (i < lines.length) {
      final trimmed = lines[i].trim();

      // Skip empty lines
      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // Section header: "数字. 文本" (e.g., "1. 数据解读")
      final sectionMatch = RegExp(r'^\d+\.\s+(.+)$').firstMatch(trimmed);
      if (sectionMatch != null) {
        widgets.add(_sectionTitle(sectionMatch.group(1)!, font));
        i++;
        continue;
      }

      // Sub-section: "### 文本"
      final h3Match = RegExp(r'^#{2,3}\s+(.+)$').firstMatch(trimmed);
      if (h3Match != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.Text(
              h3Match.group(1)!,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                font: font,
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      // Regular heading: "# 文本"
      final hMatch = RegExp(r'^#\s+(.+)$').firstMatch(trimmed);
      if (hMatch != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.Text(
              hMatch.group(1)!,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                font: font,
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      // Table detection
      if (trimmed.startsWith('|') && i + 1 < lines.length) {
        final tableLines = <String>[trimmed];
        i++;
        // Collect separator line
        if (i < lines.length && RegExp(r'^\|\s*-+:\s*(\|-)*\s*$').hasMatch(lines[i].trim())) {
          i++;
        }
        // Collect remaining table rows
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          tableLines.add(lines[i].trim());
          i++;
        }
        final table = _parseMarkdownTable(tableLines);
        if (table != null) {
          widgets.add(_renderPdfTable(table, font));
        }
        continue;
      }

      // List item: "- " or "* "
      final listMatch = RegExp(r'^[-*]\s+(.+)$').firstMatch(trimmed);
      if (listMatch != null) {
        widgets.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: pw.TextStyle(fontSize: 10, font: font)),
              Expanded(
                child: pw.Text(
                  _formatInlineText(listMatch.group(1)!, font),
                  style: pw.TextStyle(fontSize: 10, font: font),
                ),
              ),
            ],
          ),
        );
        i++;
        continue;
      }

      // Block quote
      if (trimmed.startsWith('> ')) {
        widgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.grey300, width: 3),
              ),
            ),
            child: pw.Text(
              trimmed.substring(2),
              style: pw.TextStyle(
                fontSize: 9,
                font: font,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      // Horizontal rule
      if (trimmed.startsWith('---') || trimmed.startsWith('***')) {
        widgets.add(pw.Divider(thickness: 0.5));
        i++;
        continue;
      }

      // Bold: **text** or __text__
      if (trimmed.startsWith('**') || trimmed.startsWith('__')) {
        final boldMatch = RegExp(r'\*\*(.+?)\*\*|__(.+?)__').firstMatch(trimmed);
        if (boldMatch != null) {
          widgets.add(
            pw.Text(
              _formatInlineText(trimmed, font),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                font: font,
              ),
            ),
          );
        } else {
          widgets.add(
            pw.Text(trimmed, style: pw.TextStyle(fontSize: 10, font: font)),
          );
        }
        i++;
        continue;
      }

      // Normal paragraph
      widgets.add(
        pw.Text(
          _formatInlineText(trimmed, font),
          style: pw.TextStyle(fontSize: 10, font: font),
        ),
      );
      i++;
    }

    return widgets;
  }

  static String _formatInlineText(String text, pw.Font font) {
    // Remove trailing asterisks from list items
    text = text.replaceAll(RegExp(r'\s+[*]+$'), '');
    // Bold markers
    text = text.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
    text = text.replaceAll(RegExp(r'__(.+?)__'), r'$1');
    return text;
  }

  static List<List<String>>? _parseMarkdownTable(List<String> lines) {
    if (lines.length < 2) return null;

    final parseRow = (String line) =>
        line.replaceAll('^\\|', '').replaceAll('\\|\$', '').split('|')
            .map((s) => s.trim())
            .toList();

    final headers = parseRow(lines[0]);
    final rows = <List<String>>[];
    for (int i = 1; i < lines.length; i++) {
      if (RegExp(r'^\|\s*-+:\s*(\|-)*\s*$').hasMatch(lines[i].trim())) continue;
      rows.add(parseRow(lines[i]));
    }

    return [headers, ...rows];
  }

  static pw.Widget _renderPdfTable(List<List<String>> table, pw.Font font) {
    final maxCols = table.map((row) => row.length).reduce((a, b) => a > b ? a : b);
    final cells = <pw.Widget>[][];
    for (final row in table) {
      final rowCells = <pw.Widget>[];
      for (int c = 0; c < maxCols; c++) {
        rowCells.add(
          pw.Text(
            c < row.length ? row[c] : '',
            style: pw.TextStyle(fontSize: 8, font: font),
          ),
        );
      }
      cells.add(rowCells);
    }

    return pw.TableHelper.fromWidgetsArray(
      headerCount: 1,
      headerWidgets: cells[0],
      dataWidgets: cells.sublist(1),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8,
        font: font,
      ),
      cellStyle: pw.TextStyle(fontSize: 8, font: font),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  // ── Chart capture ────────────────────────────────────────────────

  static Future<List<Uint8List>> captureCharts(List<GlobalKey> keys) async {
    await WidgetsBinding.instance.endOfFrame;
    final images = <Uint8List>[];
    for (final key in keys) {
      try {
        final boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) continue;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) images.add(byteData.buffer.asUint8List());
      } catch (e, st) {
        debugPrint('PdfExporter.captureCharts: skipped key $key → $e\n$st');
      }
    }
    return images;
  }
}
