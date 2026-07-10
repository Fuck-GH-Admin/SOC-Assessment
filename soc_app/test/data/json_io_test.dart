import 'package:flutter_test/flutter_test.dart';
import 'package:soc_app/data/json_io.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/calculation_result.dart';
import 'package:soc_app/domain/models/resilience_result.dart';

void main() {
  const record = ExportRecord(
    params: CalculationParams(bd: 1.3, erosion: 30, depth: 35),
    result: CalculationResult(soc: 10.54, netChange: -0.67),
    resilience: ResilienceResult(
      carbonPool020: 3.5,
      carbonPool060: 7.2,
      status: '低于CK',
    ),
    label: '样例',
    createdAt: 1700000000000,
    algorithmVersion: 2,
  );

  test('version 2 export round-trips algorithm metadata', () {
    final data = JsonIo.buildExportData([record]);
    expect(data['version'], 2);

    final parsed = JsonIo.parseExportData(data);
    expect(parsed, hasLength(1));
    expect(parsed.single.params.depth, 35);
    expect(parsed.single.result.netChange, -0.67);
    expect(parsed.single.resilience?.carbonPool060, 7.2);
    expect(parsed.single.algorithmVersion, 2);
    expect(parsed.single.createdAt, 1700000000000);
  });

  test('legacy version 1 records default to algorithm version 1', () {
    final data = {
      'version': 1,
      'records': [
        {
          'params': const CalculationParams().toJson(),
          'result': const CalculationResult(soc: 12).toJson(),
          'createdAt': 1700000000000.0,
        },
      ],
    };

    final parsed = JsonIo.parseExportData(data);
    expect(parsed.single.algorithmVersion, 1);
    expect(parsed.single.createdAt, 1700000000000);
  });

  test('rejects unsupported future versions', () {
    expect(
      () => JsonIo.parseExportData({'version': 99, 'records': []}),
      throwsFormatException,
    );
  });

  test('rejects a document without a records array', () {
    expect(() => JsonIo.parseExportData({'version': 2}), throwsFormatException);
  });

  test('rejects malformed record objects with a useful format error', () {
    expect(
      () => JsonIo.parseExportData({
        'version': 2,
        'records': [
          {'params': {}, 'result': 'not-an-object'},
        ],
      }),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('第1条历史记录无效'),
        ),
      ),
    );
  });

  test('rejects non-positive algorithm versions', () {
    expect(
      () => JsonIo.parseExportData({
        'version': 2,
        'records': [
          {
            'params': const CalculationParams().toJson(),
            'result': const CalculationResult().toJson(),
            'algorithmVersion': 0,
          },
        ],
      }),
      throwsFormatException,
    );
  });
}
