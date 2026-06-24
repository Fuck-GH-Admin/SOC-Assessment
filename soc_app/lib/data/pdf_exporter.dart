import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models/calculation_params.dart';
import '../domain/models/calculation_result.dart';
import '../domain/models/resilience_result.dart';

/// Rough Unicode range check for common CJK + Latin characters
/// covered by the SimHei-subset font (3449 common chars).
bool _isPrintableInFont(int codePoint) {
  if (codePoint >= 0x20 && codePoint <= 0x7E) return true;
  if (codePoint >= 0x3000 && codePoint <= 0x303F) return true;
  if (codePoint >= 0x4E00 && codePoint <= 0x9FFF) return true;
  if (codePoint >= 0xFF00 && codePoint <= 0xFFEF) return true;
  if (codePoint >= 0x2000 && codePoint <= 0x206F) return true;
  if (codePoint >= 0x2100 && codePoint <= 0x214F) return true;
  if (codePoint >= 0x2E80 && codePoint <= 0x2EFF) return true;
  if (codePoint >= 0xF900 && codePoint <= 0xFAFF) return true;
  if (codePoint == 0x0A || codePoint == 0x0D) return true;
  return false;
}

/// Replaces characters not covered by the subset font with a safe placeholder.
String _sanitizeForPdf(String text) {
  final buf = StringBuffer();
  for (final rune in text.runes) {
    if (_isPrintableInFont(rune)) {
      buf.writeCharCode(rune);
    } else {
      buf.write('�');
    }
  }
  return buf.toString();
}

class PdfExporter {
  static Future<Uint8List> generate({
    required CalculationParams params,
    required CalculationResult result,
    ResilienceResult? resilience,
    String? aiReport,
    required List<Uint8List> chartImages,
  }) async {
    final fontData = await rootBundle.load('assets/fonts/SimHei-subset.ttf');
    final font = pw.Font.ttf(fontData);

    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text('SOC 土壤有机碳评估报告',
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold, font: font)),
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
        _resultTable(result, resilience, font),
        if (resilience != null) ...[
          pw.SizedBox(height: 16),
          _sectionTitle('土壤恢复力评估', font),
          _resilienceTable(resilience, font),
        ],
        pw.SizedBox(height: 16),
        _sectionTitle('数据图表', font),
        for (final image in chartImages) ...[
          pw.SizedBox(height: 12),
          pw.Image(pw.MemoryImage(image),
              fit: pw.BoxFit.contain, width: 180, height: 105),
        ],
        if (aiReport != null && aiReport.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _sectionTitle('AI 评估报告', font),
          pw.Paragraph(
              text: _sanitizeForPdf(aiReport
                  .replaceAll(RegExp(r'[*#`>\[\]]'), '')
                  .replaceAll(RegExp(r'\n{3,}'), '\n\n')
                  .trim()),
              style: pw.TextStyle(fontSize: 9, font: font)),
        ],
      ],
    ));

    return pdf.save();
  }

  static pw.Widget _sectionTitle(String text, pw.Font font) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300),
        ),
      ),
      child: pw.Header(
        level: 1,
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold, font: font)),
      ),
    );
  }

  static pw.Widget _paramTable(CalculationParams params, pw.Font font) {
    return pw.TableHelper.fromTextArray(
      headerCount: 1,
      headers: ['参数', '数值', '说明'],
      data: [
        ['施肥处理', params.fert,
            params.fert == 'F' ? '施氮肥' : '对照'],
        ['侵蚀强度', '${params.erosion} cm', '土壤侵蚀深度'],
        ['土壤容重', params.bd.toStringAsFixed(2), 'g/cm³'],
        ['pH值', params.ph.toStringAsFixed(1), ''],
        ['含水量', params.wc.toStringAsFixed(1), '%'],
        ['黏+粉粒', params.clay.toStringAsFixed(1), '%'],
        ['全氮含量', params.tn.toStringAsFixed(2), 'g/kg'],
      ],
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 9, font: font),
      cellStyle: pw.TextStyle(fontSize: 9, font: font),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
      },
    );
  }

  static pw.Widget _resultTable(CalculationResult result,
      ResilienceResult? resilience, pw.Font font) {
    final netChange = resilience?.netChange20yr ?? result.netChange;
    final recoveryRate = resilience?.recoveryRateAnnual ?? result.recoveryRate;
    return pw.TableHelper.fromTextArray(
      headerCount: 1,
      headers: ['指标', '数值', '单位'],
      data: [
        ['SOC 含量', result.soc.toStringAsFixed(2), 'g/kg'],
        ['碳库储量', result.carbonStorage.toStringAsFixed(2),
            'kg C/m²'],
        ['碳密度', result.carbonDensity.toStringAsFixed(2),
            'kg C/m³'],
        ['净变化量', netChange.toStringAsFixed(2),
            'kg C/m²'],
        ['恢复速率', recoveryRate.toStringAsFixed(3),
            'kg C/m²/yr'],
        ['SOC 损失率', result.lossRate.toStringAsFixed(1), '%'],
      ],
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 9, font: font),
      cellStyle: pw.TextStyle(fontSize: 9, font: font),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.grey200),
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
        ['表层碳库(0-20cm)',
            r.carbonPool020.toStringAsFixed(2), 'kg C/m²'],
        ['剖面碳库(0-60cm)',
            r.carbonPool060.toStringAsFixed(2), 'kg C/m²'],
        ['20年净变化量', r.netChange20yr.toStringAsFixed(2),
            'kg C/m²'],
        ['100年净变化量', r.netChange100yr.toStringAsFixed(2),
            'kg C/m²'],
        ['年恢复速率', r.recoveryRateAnnual.toStringAsFixed(3),
            'kg C/m²/yr'],
        ['恢复状态', r.status, ''],
      ],
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 9, font: font),
      cellStyle: pw.TextStyle(fontSize: 9, font: font),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
      },
    );
  }

  static Future<List<Uint8List>> captureCharts(
      List<GlobalKey> keys) async {
    final images = <Uint8List>[];
    for (final key in keys) {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) continue;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) images.add(byteData.buffer.asUint8List());
    }
    return images;
  }

}
