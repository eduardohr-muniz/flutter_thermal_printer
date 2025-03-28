import 'dart:typed_data';
import 'package:image/image.dart' as img;

List<int> testeImageRaster(
  img.Image image, {
  int printerWidth = 384,
  bool highDensityHorizontal = true,
  bool highDensityVertical = true,
  bool alignCenter = true,
}) {
  final bytes = <int>[];

  // 1. Pré-processamento da imagem
  final processedImage = _prepareImage(image, printerWidth);

  // 2. Alinhamento (se necessário)
  if (alignCenter) {
    bytes.addAll([0x1B, 0x61, 0x01]); // Centralizar
  }

  // 3. Configuração de qualidade
  bytes.addAll([0x1D, 0x28, 0x4C, 0x02, 0x00, 0x33]); // Densidade de impressão

  // 4. Converter para formato raster
  final rasterData = _toOptimizedRasterFormat(processedImage);

  // 5. Construir comando gráfico
  final densityByte = (highDensityVertical ? 0 : 1) + (highDensityHorizontal ? 0 : 2);
  final widthBytes = (processedImage.width + 7) ~/ 8;

  bytes.addAll([0x1D, 0x76, 0x30, densityByte]); // GS v 0
  bytes.addAll(_intToLowHigh(widthBytes, 2)); // xL xH
  bytes.addAll(_intToLowHigh(processedImage.height, 2)); // yL yH
  bytes.addAll(rasterData);

  // 6. Finalização
  bytes.addAll([0x0A, 0x1D, 0x56, 0x01]); // Avançar e cortar

  return bytes;
}

img.Image _prepareImage(img.Image original, int targetWidth) {
  // Converter para tons de cinza
  var image = img.grayscale(original);

  // Redimensionar mantendo proporção
  final ratio = targetWidth / image.width;
  final targetHeight = (image.height * ratio).toInt();

  image = img.copyResize(
    image,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );

  // Aplicar filtros para melhor qualidade
  image = img.adjustColor(
    image,
    contrast: 1.3,
    gamma: 0.8,
  );

  // Binarização com limiar adaptativo
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final luminance = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
      final value = luminance < 140 ? 0 : 255;
      image.setPixelRgba(x, y, value, value, value, value);
    }
  }

  return image;
}

List<int> _toOptimizedRasterFormat(img.Image image) {
  final width = image.width;
  final height = image.height;
  final widthBytes = (width + 7) ~/ 8;
  final rasterData = Uint8List(widthBytes * height);

  // Converter pixels para formato raster
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.r < 128) {
        // Pixel preto
        final byteIndex = y * widthBytes + (x ~/ 8);
        final bitPosition = 7 - (x % 8);
        rasterData[byteIndex] |= (1 << bitPosition);
      }
    }
  }

  return rasterData.toList();
}

List<int> _intToLowHigh(int value, int bytes) {
  final result = <int>[];
  for (var i = 0; i < bytes; i++) {
    result.add(value & 0xFF);
    value >>= 8;
  }
  return result;
}
