// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:flutter_thermal_printer_example/image_utils.dart';
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

  // Get Printer List
  void startScan() async {
    _devicesStreamSubscription?.cancel();
    await _flutterThermalPrinterPlugin.getPrinters(connectionTypes: [
      ConnectionType.USB,
      // ConnectionType.BLE,
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
                        // startScan();
                        startScan();
                      },
                      child: const Text('Get Printers'),
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // startScan();
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
                          // final profile = await CapabilityProfile.load();
                          // final generator = Generator(PaperSize.mm80, profile);
                          // List<int> bytes = [];
                          // if (context.mounted) {
                          //   bytes = await FlutterThermalPrinter.instance.screenShotWidget(
                          //     context,
                          //     generator: generator,
                          //     widget: receiptWidget("Network"),
                          //   );
                          //   bytes += generator.reset();
                          //   bytes += generator.text(
                          //     "Teste Network print",
                          //     styles: const PosStyles(
                          //       bold: true,
                          //       height: PosTextSize.size3,
                          //       width: PosTextSize.size3,
                          //     ),
                          //   );
                          //   bytes += generator.cut();
                          //   await _flutterThermalPrinterPlugin.printData(printers[index], bytes);
                          // }
                          await _printReceiveTest(_flutterThermalPrinterPlugin, printers[index]);
                          // await _flutterThermalPrinterPlugin.printWidget(
                          //   context,
                          //   printer: printers[index],
                          //   cutAfterPrinted: false,
                          //   widget: receiptWidget(
                          //     printers[index].connectionTypeString,
                          //   ),
                          // );
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

  Widget receiptWidget(String printerType) {
    return SizedBox(
      width: 500,
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
              const Divider(thickness: 2),
              _buildReceiptRow('Total', '\$2.25', isBold: true),
              const SizedBox(height: 20),
              _buildReceiptRow('Printer Type', printerType),
              const SizedBox(height: 50),
              const Center(
                child: Text(
                  'Thank you for your purchase!',
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildReceiptRow(String leftText, String rightText, {bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          leftText,
          style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        ),
        Text(
          rightText,
          style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    ),
  );
}

/// Aplica a binarização (thresholding) para converter a imagem em preto-e-branco

/// Aplica a binarização (thresholding) para converter a imagem para preto e branco

img.Image applyThreshold(img.Image grayscaleImage, int threshold) {
  for (int y = 0; y < grayscaleImage.height; y++) {
    for (int x = 0; x < grayscaleImage.width; x++) {
      // Obtém o valor de cinza do pixel (intensidade 0-255)
      final int grayscaleValue = (grayscaleImage.getPixel(x, y).r).toInt();

      // Define o pixel como branco ou preto com base no valor do threshold
      if (grayscaleValue > threshold) {
        // Define branco
        grayscaleImage.setPixel(x, y, img.ColorRgb8(255, 255, 255)); // Branco
      } else {
        // Define preto
        grayscaleImage.setPixel(x, y, img.ColorRgb8(0, 0, 0)); // Preto
      }
    }
  }
  return grayscaleImage;
}

Future<void> _printReceiveTest(FlutterThermalPrinter service, Printer printer) async {
  try {
    List<int> bytes = [];

    // Carrega o perfil da impressora
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    // Reseta a configuração da impressora
    bytes += generator.reset();

    // Adiciona texto inicial
    bytes += generator.text(
      "Teste Network Print",
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size3,
        width: PosTextSize.size3,
      ),
    );

    // Carrega a imagem da pasta `assets`
    final ByteData data = await rootBundle.load('assets/desenho.png');
    final Uint8List imageBytes = data.buffer.asUint8List();

    // Decodifica a imagem carregada
    final img.Image originalImage = img.decodeImage(imageBytes)!;

    // Redimensiona a imagem para a largura máxima suportada pela impressora
    const int maxWidth = 576; // Largura máxima (80mm em pixels)
    final img.Image resizedImage = img.copyResize(
      originalImage,
      width: maxWidth,
      interpolation: img.Interpolation.linear, // Interpolação linear
    );

    // Converte para escala de cinza
    // final img.Image grayscaleImage = img.grayscale(resizedImage);

    // Aplica a binarização (threshold) para conversão em preto e branco
    // final img.Image binarizedImage = applyThreshold(grayscaleImage, 128); // Threshold padrão de 128

    // Salva a imagem binarizada no diretório `assets/saved`
    await _saveImageInAssets(resizedImage);

    // Adiciona a imagem processada à fila de impressão
    bytes += generator.imageRaster(
      resizedImage,
      imageFn: PosImageFn.bitImageRaster,
      highDensityVertical: true,
      highDensityHorizontal: true,
    );

    // Corte e avanço do papel
    bytes += generator.feed(2);
    bytes += generator.cut();

    // Envia os dados para a impressora
    await service.printData(printer, bytes, longData: true);
  } catch (e) {
    print('Erro ao imprimir: $e');
  }
}

/// Salva a imagem no diretório "assets/saved" do seu projeto
Future<void> _saveImageInAssets(img.Image image) async {
  try {
    // Diretório onde a imagem será salva (subpasta do seu projeto)
    const String assetsSubPath = 'assets/saved';

    // Cria o diretório, se não existir
    final Directory directory = Directory(assetsSubPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true); // Cria subdiretórios, se necessário
    }

    // Nome único para o arquivo baseado no timestamp
    final String fileName = 'imagem_processada_${DateTime.now().millisecondsSinceEpoch}.png';

    // Caminho completo onde o arquivo será salvo
    final String filePath = '${directory.path}/$fileName';

    // Converte a imagem processada para bytes no formato PNG
    final List<int> encodedImage = img.encodePng(image);

    // Salva a imagem como arquivo no disco
    final File file = File(filePath);
    await file.writeAsBytes(encodedImage);

    print('Imagem salva com sucesso no diretório: $filePath');
  } catch (e) {
    print('Erro ao salvar a imagem no diretório assets/saved: $e');
  }
}
