import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soc_app/data/pdf_report_storage.dart';

void main() {
  late Directory tempDir;
  late PdfReportStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('soc-pdf-storage-');
    storage = PdfReportStorage(documentsDirectoryProvider: () async => tempDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('uses a stable file name for a history record', () {
    expect(storage.fileNameFor(recordId: 42), 'soc-report-42.pdf');
  });

  test('uses a timestamp file name when no history record exists', () {
    final generatedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    expect(
      storage.fileNameFor(generatedAt: generatedAt),
      'soc-report-1700000000000.pdf',
    );
  });

  test('saves and overwrites one persistent copy per history record', () async {
    final first = await storage.save(Uint8List.fromList([1, 2]), recordId: 7);
    final second = await storage.save(Uint8List.fromList([3, 4]), recordId: 7);

    expect(second.path, first.path);
    expect(
      first.path,
      p.join(
        tempDir.path,
        PdfReportStorage.appDirectoryName,
        PdfReportStorage.reportDirectoryName,
        'soc-report-7.pdf',
      ),
    );
    expect(await second.readAsBytes(), [3, 4]);
  });

  test('deleteIfExists removes a saved report', () async {
    final file = await storage.save(Uint8List.fromList([1]), recordId: 9);
    await storage.deleteIfExists(file.path);
    expect(await file.exists(), isFalse);
  });

  test(
    'deleteIfExists refuses paths outside the managed report directory',
    () async {
      final outside = File(p.join(tempDir.path, 'unrelated.pdf'));
      await outside.writeAsBytes([1, 2, 3]);

      expect(
        () => storage.deleteIfExists(outside.path),
        throwsA(isA<ArgumentError>()),
      );
      expect(await outside.exists(), isTrue);
    },
  );
}
