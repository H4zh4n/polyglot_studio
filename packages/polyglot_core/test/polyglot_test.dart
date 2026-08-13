import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:polyglot_core/polyglot_core.dart';
import 'package:test/test.dart';

void main() {
  group('ImageIcoEngine Tests', () {
    test('Converts generated image to 32bpp RGBA8 PNG', () {
      final testImg = img.Image(width: 16, height: 16);
      img.fill(testImg, color: img.ColorRgba8(255, 0, 0, 255));
      final rawPng = Uint8List.fromList(img.encodePng(testImg));

      final converted = ImageIcoEngine.convertTo32bppPng(rawPng);
      expect(converted.isNotEmpty, isTrue);

      final decoded = img.decodeImage(converted);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(16));
      expect(decoded.height, equals(16));
    });

    test('Endian conversions and sub-array search', () {
      final le = ImageIcoEngine.uint32To4bLE(0x12345678);
      expect(le, equals([0x78, 0x56, 0x34, 0x12]));

      final be = ImageIcoEngine.uint32To4bBE(0x12345678);
      expect(be, equals([0x12, 0x34, 0x56, 0x78]));

      final array = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      expect(ImageIcoEngine.findSubArrayIndex(array, [3, 4]), equals(2));
      expect(ImageIcoEngine.findSubArrayIndex(array, [9, 9]), equals(-1));
    });
  });

  group('ZipEngine Tests', () {
    test('Merges and adjusts zip archives', () {
      final zip1 = ZipEngine.mergeZipArchives([]);
      expect(zip1, isEmpty);

      final adjusted = ZipEngine.adjustZipOffsets(Uint8List(0), 100);
      expect(adjusted, isEmpty);
    });
  });

  group('PdfStreamEngine Tests', () {
    test('Pads numbers properly', () {
      expect(PdfStreamEngine.padLeft(42, 5), equals('00042'));
      expect(PdfStreamEngine.padLeft(123456, 4), equals('123456'));
    });
  });

  group('PolyglotInspector Image Tests', () {
    test('Inspects standalone PNG and decodes metadata', () {
      final testImg = img.Image(width: 32, height: 32, numChannels: 4);
      img.fill(testImg, color: img.ColorRgba8(0, 255, 0, 180));
      final pngBytes = Uint8List.fromList(img.encodePng(testImg));

      final res = PolyglotInspector.inspect(bytes: pngBytes, fileName: 'icon.png');
      expect(res.detectedFormats.contains('.png'), isTrue);
      expect(res.extractedImageBytes, isNotNull);
      expect(res.imageInfo.width, equals(32));
      expect(res.imageInfo.height, equals(32));
      expect(res.imageInfo.resolutionString, equals('32x32'));
      expect(res.imageInfo.aspectRatioString, equals('1:1'));
      expect(res.imageInfo.colorDepth, equals(32));
      expect(res.imageInfo.hasAlpha, isTrue);
    });

    test('Inspects standalone JPEG image format', () {
      final testImg = img.Image(width: 64, height: 48);
      img.fill(testImg, color: img.ColorRgb8(255, 128, 0));
      final jpgBytes = Uint8List.fromList(img.encodeJpg(testImg));

      final res = PolyglotInspector.inspect(bytes: jpgBytes, fileName: 'photo.jpg');
      expect(res.detectedFormats.contains('.jpg'), isTrue);
      expect(res.extractedImageBytes, isNotNull);
      expect(res.imageInfo.width, equals(64));
      expect(res.imageInfo.height, equals(48));
      expect(res.imageInfo.format, equals('JPEG'));
      expect(res.imageInfo.aspectRatioString, equals('4:3'));
    });
  });

  group('PolyglotInspector Media Tests', () {
    test('Inspects standalone M4A audio signature', () {
      final m4aBytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x20, // size 32
        0x66, 0x74, 0x79, 0x70, // ftyp
        0x4D, 0x34, 0x41, 0x20, // M4A
        0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D,
        0x69, 0x73, 0x6F, 0x32,
        0x61, 0x76, 0x63, 0x31,
        0x6D, 0x70, 0x34, 0x31,
      ]);
      final res = PolyglotInspector.inspect(bytes: m4aBytes, fileName: 'track.m4a');

      expect(res.detectedFormats.contains('.m4a'), isTrue);
      expect(res.detectedFormats.contains('.mp4'), isFalse);
      expect(res.mediaInfo.isVideo, isFalse);
      expect(res.rawBytes, isNotNull);
    });

    test('Inspects standalone MP4 video signature', () {
      final mp4Bytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x20, // size 32
        0x66, 0x74, 0x79, 0x70, // ftyp
        0x69, 0x73, 0x6F, 0x6D, // isom
        0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D,
        0x69, 0x73, 0x6F, 0x32,
        0x61, 0x76, 0x63, 0x31,
        0x6D, 0x70, 0x34, 0x31,
      ]);
      final res = PolyglotInspector.inspect(bytes: mp4Bytes, fileName: 'movie.mp4');

      expect(res.detectedFormats.contains('.mp4'), isTrue);
      expect(res.mediaInfo.isVideo, isTrue);
      expect(res.rawBytes, isNotNull);
    });

    test('PolyglotGenerator combines PNG Image and MP4 video into Polyglot and inspector extracts media', () async {
      final testImg = img.Image(width: 16, height: 16);
      img.fill(testImg, color: img.ColorRgba8(0, 0, 255, 255));
      final pngBytes = Uint8List.fromList(img.encodePng(testImg));

      final rawMp4 = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x20, // size 32
        0x66, 0x74, 0x79, 0x70, // ftyp
        0x69, 0x73, 0x6F, 0x6D, // isom
        0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D,
        0x69, 0x73, 0x6F, 0x32,
        0x61, 0x76, 0x63, 0x31,
        0x6D, 0x70, 0x34, 0x31,
        0x00, 0x00, 0x00, 0x08, // mdat header
        0x6D, 0x64, 0x61, 0x74,
      ]);

      final result = await PolyglotGenerator.generate(PolyglotInputs(
        imageBytes: pngBytes,
        imageName: 'cover.png',
        mediaBytes: rawMp4,
        mediaName: 'video.mp4',
        isVideo: true,
      ));

      expect(result.data.length > 288, isTrue);
      expect(result.supportedExtensions.contains('.ico'), isTrue);
      expect(result.supportedExtensions.contains('.mp4'), isTrue);

      // Now inspect the generated polyglot
      final inspected = PolyglotInspector.inspect(bytes: result.data, fileName: 'polyglot.ico.mp4');
      expect(inspected.hasIcoHeader, isTrue);
      expect(inspected.hasSecondaryFtyp, isTrue);
      expect(inspected.detectedFormats.contains('.ico'), isTrue);
      expect(inspected.detectedFormats.contains('.png'), isTrue);
      expect(inspected.detectedFormats.contains('.mp4'), isTrue);
      expect(inspected.extractedImageBytes, isNotNull);
      expect(inspected.extractedMediaBytes, isNotNull);
      expect(inspected.extractedMediaBytes!.length > 32, isTrue);
    });
  });
}
