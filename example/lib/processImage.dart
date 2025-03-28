import 'dart:io';
import 'package:image/image.dart' as img;

String convertImageToHighQualityEscPos(String imagePath, {int printerWidth = 384}) {
  // 1. Carregar a imagem original
  final originalImage = img.decodeImage(File(imagePath).readAsBytesSync())!;

  // 2. Pré-processamento com técnicas específicas para impressoras térmicas
  final processedImage = _preprocessForThermalPrint(originalImage, printerWidth);

  // 3. Converter para ESC/POS com algoritmo de pontilhamento adaptado
  return _generateEscPosFromImage(processedImage, printerWidth);
}

img.Image _preprocessForThermalPrint(img.Image original, int targetWidth) {
  // Converter para tons de cinza com ajuste de contraste
  var image = img.grayscale(original);

  // Redimensionar com proporção mantida (método Lanczos para melhor qualidade)
  final scaleFactor = targetWidth / image.width;
  final targetHeight = (image.height * scaleFactor).toInt();

  image = img.copyResize(
    image,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );

  // Aplicar sharpening para melhorar detalhes textuais
  image = img.convolution(image, filter: [
    0,
    -1,
    0,
    -1,
    5,
    -1,
    0,
    -1,
    0
  ]);

  return image;
}

String _generateEscPosFromImage(img.Image image, int printerWidth) {
  final commands = StringBuffer();

  // Configurações iniciais para melhor qualidade
  commands.write('\x1B\x40'); // Inicializa impressora
  commands.write('\x1D\x28\x4C\x02\x00\x33'); // Configura densidade de impressão

  // Usar modo gráfico de alta resolução (24-dot double density)
  const mode = 39; // ESC * mode 39 (24-dot double density)

  // Processar a imagem em blocos de 24 linhas (altura de 3 bytes)
  for (var y = 0; y < image.height; y += 24) {
    final blockHeight = (y + 24 > image.height) ? image.height - y : 24;

    // Cabeçalho do comando gráfico
    commands.write('\x1B*${String.fromCharCode(mode)}');
    commands.write(String.fromCharCode(printerWidth % 256));
    commands.write(String.fromCharCode(printerWidth ~/ 256));
    commands.write(String.fromCharCode(blockHeight % 256));
    commands.write(String.fromCharCode(blockHeight ~/ 256));

    // Converter pixels para bytes ESC/POS com pontilhamento adaptativo
    for (var x = 0; x < printerWidth; x++) {
      var byte1 = 0; // Byte superior (8 primeiros pixels)
      var byte2 = 0; // Byte médio (8 pixels seguintes)
      var byte3 = 0; // Byte inferior (8 últimos pixels)

      for (var k = 0; k < 8; k++) {
        if (y + k < image.height && x < image.width) {
          final pixel = image.getPixel(x, y + k);
          final luminance = getLuminance(pixel);
          if (luminance < 160) byte1 |= 1 << (7 - k);
        }

        if (y + k + 8 < image.height && x < image.width) {
          final pixel = image.getPixel(x, y + k + 8);
          final luminance = getLuminance(pixel);
          if (luminance < 160) byte2 |= 1 << (7 - k);
        }

        if (y + k + 16 < image.height && x < image.width) {
          final pixel = image.getPixel(x, y + k + 16);
          final luminance = getLuminance(pixel);
          if (luminance < 160) byte3 |= 1 << (7 - k);
        }
      }

      commands.write(String.fromCharCode(byte1));
      commands.write(String.fromCharCode(byte2));
      commands.write(String.fromCharCode(byte3));
    }
  }

  // Finalização
  commands.write('\x0A\x0A'); // Avançar papel
  commands.write('\x1B\x69'); // Corte parcial

  return commands.toString();
}

int getLuminance(img.Color c) {
  // Extrai os componentes de cor corretamente
  final r = c.r;
  final g = c.g;
  final b = c.b;

  // Fórmula de luminância perceptiva (Rec. 709)
  return (0.2126 * r + 0.7152 * g + 0.0722 * b).toInt();
}
