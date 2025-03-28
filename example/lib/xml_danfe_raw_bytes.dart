import 'dart:io';
import 'package:danfe/danfe.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';

class XmlDanfeRawBytes {
  Future<List<int>> generate(String xmlPath) async {
    final File file = File(xmlPath);
    final danfString = file.readAsStringSync();
    Danfe danfe = DanfeParser.readFromString(danfString)!;
    DanfePrinter danfePrinter = DanfePrinter(PaperSize.mm80); // ou  PaperSize.mm50
    return await danfePrinter.bufferDanfe(danfe);
  }
}
