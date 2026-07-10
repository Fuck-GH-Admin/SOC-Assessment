import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();

class PdfReportStorage {
  static const appDirectoryName = 'SOC-Shield';
  static const reportDirectoryName = 'report_pdfs';

  final DocumentsDirectoryProvider _documentsDirectoryProvider;

  PdfReportStorage({DocumentsDirectoryProvider? documentsDirectoryProvider})
    : _documentsDirectoryProvider =
          documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  String fileNameFor({int? recordId, DateTime? generatedAt}) {
    final reportKey =
        recordId?.toString() ??
        (generatedAt ?? DateTime.now()).millisecondsSinceEpoch.toString();
    return 'soc-report-$reportKey.pdf';
  }

  Future<Directory> getReportDirectory() async {
    final documentsDirectory = await _documentsDirectoryProvider();
    final reportDirectory = Directory(
      p.join(documentsDirectory.path, appDirectoryName, reportDirectoryName),
    );
    await reportDirectory.create(recursive: true);
    return reportDirectory;
  }

  Future<File> save(
    Uint8List bytes, {
    int? recordId,
    DateTime? generatedAt,
  }) async {
    final reportDirectory = await getReportDirectory();
    final file = File(
      p.join(
        reportDirectory.path,
        fileNameFor(recordId: recordId, generatedAt: generatedAt),
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> deleteIfExists(String path) async {
    final reportDirectory = await getReportDirectory();
    final managedRoot = p.normalize(p.absolute(reportDirectory.path));
    final targetPath = p.normalize(p.absolute(path));
    final isManaged =
        p.isWithin(managedRoot, targetPath) &&
        p.extension(targetPath).toLowerCase() == '.pdf';
    if (!isManaged) {
      throw ArgumentError.value(path, 'path', '拒绝删除应用报告目录之外的文件');
    }

    final file = File(targetPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
