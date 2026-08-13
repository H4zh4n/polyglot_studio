import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Handles image normalization and dual-purpose ICO header construction.
class ImageIcoEngine {
  /// Converts an input image to a clean 32bpp RGBA8 PNG without extra metadata.
  static Uint8List convertTo32bppPng(Uint8List inputImageBytes) {
    final decoded = img.decodeImage(inputImageBytes);
    if (decoded == null) {
      throw const FormatException('Unable to decode image format.');
    }

    // Ensure 8-bit RGBA channels (32-bit color depth)
    final rgbaImage = decoded.convert(numChannels: 4);
    final pngBytes = img.encodePng(rgbaImage, filter: img.PngFilter.none);
    return Uint8List.fromList(pngBytes);
  }

  /// Converts a 32-bit integer to a 4-byte Little-Endian Uint8List.
  static Uint8List uint32To4bLE(int value) {
    final buffer = Uint8List(4);
    final byteData = ByteData.sublistView(buffer);
    byteData.setUint32(0, value, Endian.little);
    return buffer;
  }

  /// Converts a 32-bit integer to a 4-byte Big-Endian Uint8List.
  static Uint8List uint32To4bBE(int value) {
    final buffer = Uint8List(4);
    final byteData = ByteData.sublistView(buffer);
    byteData.setUint32(0, value, Endian.big);
    return buffer;
  }

  /// Finds the index of a sub-array within a Uint8List array.
  static int findSubArrayIndex(Uint8List array, List<int> subArray, [int startIndex = 0]) {
    if (subArray.isEmpty || array.length < subArray.length) return -1;
    final maxIdx = array.length - subArray.length;
    for (int i = startIndex; i <= maxIdx; i++) {
      bool match = true;
      for (int j = 0; j < subArray.length; j++) {
        if (array[i + j] != subArray[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}
