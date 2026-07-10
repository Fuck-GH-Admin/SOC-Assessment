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
          if (aiReport != null && aiReport.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('AI 评估报告', font),
            pw.Paragraph(
              text: aiReport
                  .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
                  .replaceAll(RegExp(r'\*{1,2}([^*]+)\*{1,2}'), r'$1')
                  .replaceAll(RegExp(r'\n{3,}'), '\n\n')
                  .trim(),
              style: pw.TextStyle(fontSize: 9, font: font),
            ),
          ],
        ],
      ),
    );

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
        ['算法口径', 'v$kSocAlgorithmVersion', '用于区分历史计算版本'],
        ['施肥处理', params.fert, params.fert == 'F' ? '施肥' : '不施肥'],
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
