import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:flutter_thermal_printer_example/image_utils.dart';
import 'package:flutter_thermal_printer_example/process_image_bytes.dart';
import 'package:flutter_thermal_printer_example/xml_danfe_raw_bytes.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _flutterThermalPrinterPlugin = FlutterThermalPrinter.instance;

  String _ip = '192.168.0.100';
  String _port = '9100';

  List<Printer> printers = [];

  StreamSubscription<List<Printer>>? _devicesStreamSubscription;

  void startScan() async {
    _devicesStreamSubscription?.cancel();
    await _flutterThermalPrinterPlugin.getPrinters(connectionTypes: [
      ConnectionType.USB,
    ]);
    _devicesStreamSubscription = _flutterThermalPrinterPlugin.devicesStream.listen((List<Printer> event) {
      log(event.map((e) => e.name).toList().toString());
      setState(() {
        printers = event;
        printers.removeWhere((element) => element.name == null || element.name == '');
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      startScan();
    });
  }

  stopScan() {
    _flutterThermalPrinterPlugin.stopScan();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'NETWORK',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _ip,
                decoration: const InputDecoration(
                  labelText: 'Enter IP Address',
                ),
                onChanged: (value) {
                  _ip = value;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _port,
                decoration: const InputDecoration(
                  labelText: 'Enter Port',
                ),
                onChanged: (value) {
                  _port = value;
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final service = FlutterThermalPrinterNetwork(
                          _ip,
                          port: int.parse(_port),
                        );
                        await service.connect();
                        final profile = await CapabilityProfile.load();
                        final generator = Generator(PaperSize.mm80, profile);
                        List<int> bytes = [];
                        if (context.mounted) {
                          bytes = await FlutterThermalPrinter.instance.screenShotWidget(
                            context,
                            generator: generator,
                            widget: receiptWidget("Network"),
                          );
                          bytes += generator.cut();
                          await service.printTicket(bytes);
                        }
                        await service.disconnect();
                      },
                      child: const Text('Test network printer'),
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final service = FlutterThermalPrinterNetwork(_ip, port: int.parse(_port));
                        await service.connect();
                        final bytes = await _generateReceipt();
                        await service.printTicket(bytes);
                        final danfeBytes = await _generateDanfe();
                        await service.printTicket(danfeBytes);
                        await service.disconnect();
                      },
                      child: const Text('Test network printer widget'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 22),
              Text(
                'USB/BLE',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        startScan();
                      },
                      child: const Text('Get Printers'),
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        stopScan();
                      },
                      child: const Text('Stop Scan'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: printers.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      onTap: () async {
                        if (printers[index].isConnected ?? false) {
                          await _flutterThermalPrinterPlugin.disconnect(printers[index]);
                        } else {
                          await _flutterThermalPrinterPlugin.connect(printers[index]);
                        }
                      },
                      title: Text(printers[index].name ?? 'No Name'),
                      subtitle: Text("Connected: ${printers[index].isConnected}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.connect_without_contact),
                        onPressed: () async {
                          await _printReceiveTest(_flutterThermalPrinterPlugin, printers[index], context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<int>> _generateReceipt() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    bytes += generator.text(
      "Teste Network print",
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size3,
        width: PosTextSize.size3,
      ),
    );
    bytes += generator.cut();
    return bytes;
  }
}

Widget _buildReceiptRow(String leftText, String rightText, {bool isBold = false}) {
  return DefaultTextStyle(
    style: GoogleFonts.robotoMono(color: Colors.black),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            leftText,
            style: TextStyle(
              fontSize: 26,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            rightText,
            style: TextStyle(
              fontSize: 26,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}

img.Image applyThreshold(img.Image grayscaleImage, int threshold) {
  for (int y = 0; y < grayscaleImage.height; y++) {
    for (int x = 0; x < grayscaleImage.width; x++) {
      final int grayscaleValue = (grayscaleImage.getPixel(x, y).r).toInt();

      if (grayscaleValue > threshold) {
        grayscaleImage.setPixel(x, y, img.ColorRgb8(255, 255, 255));
      } else {
        grayscaleImage.setPixel(x, y, img.ColorRgb8(0, 0, 0));
      }
    }
  }
  return grayscaleImage;
}

Future<void> _printReceiveTest(FlutterThermalPrinter service, Printer printer, BuildContext context) async {
  try {
    // List<int> bytes = [];

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    // bytes += generator.reset();

    // bytes += generator.text(
    //   "Teste Network Print",
    //   styles: const PosStyles(
    //     bold: true,
    //     height: PosTextSize.size3,
    //     width: PosTextSize.size3,
    //   ),
    // );

    // final ByteData data = await rootBundle.load('assets/desenho.png');
    // final Uint8List imageBytes = data.buffer.asUint8List();

    // final img.Image originalImage = img.decodeImage(imageBytes)!;

    // const int maxWidth = 576;
    // final img.Image resizedImage = img.copyResize(
    //   originalImage,
    //   width: maxWidth,
    //   interpolation: img.Interpolation.linear,
    // );

    // await _saveImageInAssets(resizedImage);

    // bytes += generator.imageRaster(
    //   resizedImage,
    //   imageFn: PosImageFn.bitImageRaster,
    //   highDensityVertical: true,
    //   highDensityHorizontal: true,
    // );

    // bytes += generator.feed(2);
    // bytes += generator.cut();

    // await service.printData(printer, bytes, longData: true);
    // final danfeBytes = await _generateDanfe();
    // await service.printData(printer, danfeBytes, longData: true);
    List<int> bytesScreen = await FlutterThermalPrinter.instance.screenShotWidget(
      context,
      generator: generator,
      widget: receiptWidget("Network"),
    );
    final imageFile = File('assets/order.png').readAsBytesSync();
    final originalImage = img.decodeImage(imageFile)!;
    bytesScreen += generator.cut();
    bytesScreen += generator.imageRaster(originalImage, highDensityVertical: true, highDensityHorizontal: true);
    final b = testeImageRaster(originalImage);
    await service.printData(printer, bytesScreen, longData: true);
  } catch (e) {
    print('Erro ao imprimir: $e');
  }
}

Future<void> _saveImageInAssets(img.Image image) async {
  try {
    const String assetsSubPath = 'assets/saved';

    final Directory directory = Directory(assetsSubPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final String fileName = 'imagem_processada_${DateTime.now().millisecondsSinceEpoch}.png';

    final String filePath = '${directory.path}/$fileName';

    final List<int> encodedImage = img.encodePng(image);

    final File file = File(filePath);
    await file.writeAsBytes(encodedImage);

    print('Imagem salva com sucesso no diretório: $filePath');
  } catch (e) {
    print('Erro ao salvar a imagem no diretório assets/saved: $e');
  }
}

Future<List<int>> _generateDanfe() {
  return XmlDanfeRawBytes().generate('assets/cupom.xml');
}

Widget receiptWidget(String printerType) {
  return SizedBox(
    width: 550,
    child: Material(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'FLUTTER THERMAL PRINTER',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(thickness: 2),
            const SizedBox(height: 10),
            _buildReceiptRow('Item', 'Price'),
            const Divider(),
            _buildReceiptRow('Apple', '\$1.00'),
            _buildReceiptRow('Banana', '\$0.50'),
            _buildReceiptRow('Orange', '\$0.75'),
            _buildReceiptRow('Grapes', '\$2.00'),
            _buildReceiptRow('Watermelon', '\$3.00'),
            _buildReceiptRow('Pineapple', '\$2.50'),
            _buildReceiptRow('Strawberry', '\$1.50'),
            _buildReceiptRow('Blueberry', '\$2.25'),
            _buildReceiptRow('Mango', '\$1.75'),
            _buildReceiptRow('Peach', '\$1.25'),
            _buildReceiptRow('Plum', '\$1.00'),
            _buildReceiptRow('Kiwi', '\$1.50'),
            _buildReceiptRow('Papaya', '\$2.00'),
            _buildReceiptRow('Cherry', '\$2.50'),
            _buildReceiptRow('Pomegranate', '\$3.00'),
            _buildReceiptRow('Lemon', '\$0.75'),
            _buildReceiptRow('Lime', '\$0.50'),
            _buildReceiptRow('Coconut', '\$2.00'),
            _buildReceiptRow('Avocado', '\$1.50'),
            _buildReceiptRow('Fig', '\$2.25'),
            _buildReceiptRow('Guava', '\$1.75'),
            _buildReceiptRow('Lychee', '\$2.50'),
            _buildReceiptRow('Nectarine', '\$1.25'),
            _buildReceiptRow('Passion Fruit', '\$2.00'),
            _buildReceiptRow('Pear', '\$1.50'),
            _buildReceiptRow('Raspberry', '\$2.75'),
            _buildReceiptRow('Blackberry', '\$2.50'),
            _buildReceiptRow('Cantaloupe', '\$3.00'),
            _buildReceiptRow('Honeydew', '\$3.00'),
            _buildReceiptRow('Tangerine', '\$1.00'),
            _buildReceiptRow('Cranberry', '\$2.25'),
            _buildReceiptRow('Dragon Fruit', '\$3.50'),
            _buildReceiptRow('Durian', '\$5.00'),
            _buildReceiptRow('Jackfruit', '\$4.00'),
            _buildReceiptRow('Starfruit', '\$2.75'),
            _buildReceiptRow('Mulberry', '\$2.50'),
            _buildReceiptRow('Persimmon', '\$1.75'),
            _buildReceiptRow('Quince', '\$2.00'),
            _buildReceiptRow('Rambutan', '\$2.50'),
            _buildReceiptRow('Soursop', '\$3.00'),
            _buildReceiptRow('Tamarind', '\$1.50'),
            _buildReceiptRow('Ugli Fruit', '\$2.75'),
            _buildReceiptRow('Yuzu', '\$3.00'),
            _buildReceiptRow('Zucchini', '\$1.25'),
            _buildReceiptRow('Apricot', '\$1.50'),
            _buildReceiptRow('Clementine', '\$1.00'),
            _buildReceiptRow('Elderberry', '\$2.75'),
            _buildReceiptRow('Gooseberry', '\$2.50'),
            _buildReceiptRow('Huckleberry', '\$2.75'),
            _buildReceiptRow('Jujube', '\$2.00'),
            _buildReceiptRow('Kumquat', '\$1.75'),
            _buildReceiptRow('Loquat', '\$2.25'),
            _buildReceiptRow('Medlar', '\$2.50'),
            _buildReceiptRow('Olive', '\$1.50'),
            _buildReceiptRow('Pawpaw', '\$2.75'),
            _buildReceiptRow('Salak', '\$3.00'),
            _buildReceiptRow('Sapodilla', '\$2.50'),
            _buildReceiptRow('Sorrel', '\$1.75'),
            _buildReceiptRow('Tomato', '\$1.00'),
            _buildReceiptRow('Uva', '\$2.25'),
            _buildReceiptRow('Vanilla', '\$3.50'),
            _buildReceiptRow('Walnut', '\$2.75'),
            _buildReceiptRow('Xigua', '\$3.00'),
            _buildReceiptRow('Yam', '\$1.50'),
            _buildReceiptRow('Ziziphus', '\$2.75'),
            const Divider(thickness: 2),
            _buildReceiptRow('Total', '\$2.25', isBold: true),
            const SizedBox(height: 20),
            _buildReceiptRow('Printer Type', printerType),
            const SizedBox(height: 50),
            Center(
              child: Text(
                'Thank you for your purchase!',
                style: GoogleFonts.robotoMono(fontSize: 16, color: Colors.black, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
