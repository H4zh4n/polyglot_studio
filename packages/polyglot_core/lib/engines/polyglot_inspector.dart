import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'mp4_box_engine.dart';

/// Information about a single file stored inside an embedded ZIP archive.
class ZipEntryInfo {
  final String name;
  final int size;
  final int compressedSize;
  final bool isDirectory;
  final DateTime? lastModified;

  const ZipEntryInfo({
    required this.name,
    required this.size,
    required this.compressedSize,
    this.isDirectory = false,
    this.lastModified,
  });
}

/// Metadata extracted from decoded image streams (PNG, ICO, JPEG, WEBP, BMP, GIF).
class ImageMetadataInfo {
  final int? width;
  final int? height;
  final String? format;
  final int? colorDepth;
  final int? numChannels;
  final bool hasAlpha;
  final int? byteOffset;
  final int? byteSize;

  const ImageMetadataInfo({
    this.width,
    this.height,
    this.format,
    this.colorDepth,
    this.numChannels,
    this.hasAlpha = false,
    this.byteOffset,
    this.byteSize,
  });

  String get resolutionString => (width != null && height != null) ? '${width}x$height' : 'Unknown';
  String get colorDepthString => colorDepth != null ? '${colorDepth}bpp' : (numChannels != null ? '${numChannels! * 8}bpp' : '');
  String get aspectRatioString {
    if (width == null || height == null || height == 0) return '';
    if (width == height) return '1:1';
    final gcd = _gcd(width!, height!);
    return '${width! ~/ gcd}:${height! ~/ gcd}';
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
}

/// Metadata extracted from the ISOBMFF / MP4 container structure.
class MediaMetadataInfo {
  final int? width;
  final int? height;
  final double? durationSeconds;
  final String? videoCodec;
  final String? audioCodec;
  final List<String> atomBoxes;
  final bool isVideo;
  final int? sampleRate;
  final int? channels;
  final int? bitrate;

  const MediaMetadataInfo({
    this.width,
    this.height,
    this.durationSeconds,
    this.videoCodec,
    this.audioCodec,
    this.atomBoxes = const [],
    this.isVideo = true,
    this.sampleRate,
    this.channels,
    this.bitrate,
  });
}

/// Detailed metadata and structural breakdown of embedded or standalone HTML documents.
class HtmlMetadataInfo {
  final String? title;
  final int scriptCount;
  final int styleCount;
  final int linkCount;
  final int imageTagCount;
  final int anchorCount;
  final int formCount;
  final int canvasCount;
  final int svgCount;
  final int buttonCount;
  final int inputCount;
  final bool hasInlineStyles;
  final bool hasJavaScript;
  final bool hasCss;
  final List<String> scriptSources;
  final List<String> stylesheetHrefs;
  final String? cleanBodyHtml;
  final int lineCount;
  final int characterCount;

  const HtmlMetadataInfo({
    this.title,
    this.scriptCount = 0,
    this.styleCount = 0,
    this.linkCount = 0,
    this.imageTagCount = 0,
    this.anchorCount = 0,
    this.formCount = 0,
    this.canvasCount = 0,
    this.svgCount = 0,
    this.buttonCount = 0,
    this.inputCount = 0,
    this.hasInlineStyles = false,
    this.hasJavaScript = false,
    this.hasCss = false,
    this.scriptSources = const [],
    this.stylesheetHrefs = const [],
    this.cleanBodyHtml,
    this.lineCount = 0,
    this.characterCount = 0,
  });
}

/// Analysis result produced by inspecting a polyglot file header and byte map.
class PolyglotInspectionResult {
  final String fileName;
  final int fileSize;
  final Uint8List headerBytes; // first 288 bytes (or full file if < 288)
  final String extraHeaderString; // decoded ASCII from byte 22..255
  final bool hasIcoHeader;
  final bool hasSecondaryFtyp;
  final bool hasHtmlWrapper;
  final bool hasPdfStream;
  final bool hasZipEocd;
  final int? pngOffset;
  final int? pdfOffset;
  final int? zipOffset;
  final int? appendableOffset;
  final int? appendableSize;
  final Uint8List? appendableBytes;
  final String? appendablePreviewText;
  final List<String> detectedFormats;

  final Uint8List? rawBytes;
  final Uint8List? extractedImageBytes;
  final Uint8List? extractedAudioBytes;
  final Uint8List? extractedMediaBytes;
  final ImageMetadataInfo imageInfo;
  final List<ZipEntryInfo> zipEntries;
  final String? extractedHtmlContent;
  final HtmlMetadataInfo htmlInfo;
  final Uint8List? extractedPdfBytes;
  final String? pdfVersion;
  final int pdfPageCount;
  final MediaMetadataInfo mediaInfo;

  PolyglotInspectionResult({
    required this.fileName,
    required this.fileSize,
    required this.headerBytes,
    required this.extraHeaderString,
    required this.hasIcoHeader,
    required this.hasSecondaryFtyp,
    required this.hasHtmlWrapper,
    required this.hasPdfStream,
    required this.hasZipEocd,
    this.pngOffset,
    this.pdfOffset,
    this.zipOffset,
    this.appendableOffset,
    this.appendableSize,
    this.appendableBytes,
    this.appendablePreviewText,
    required this.detectedFormats,
    this.rawBytes,
    this.extractedImageBytes,
    this.extractedAudioBytes,
    this.extractedMediaBytes,
    this.imageInfo = const ImageMetadataInfo(),
    this.zipEntries = const [],
    this.extractedHtmlContent,
    this.htmlInfo = const HtmlMetadataInfo(),
    this.extractedPdfBytes,
    this.pdfVersion,
    this.pdfPageCount = 0,
    this.mediaInfo = const MediaMetadataInfo(),
  });
}

/// Standalone analyzer that extracts magic headers, dead space data, and polyglot atoms.
class PolyglotInspector {
  /// Inspects raw [bytes] of any file and decodes its polyglot structures.
  static PolyglotInspectionResult inspect({
    required Uint8List bytes,
    required String fileName,
  }) {
    final fileSize = bytes.length;
    final headerLen = bytes.length >= 288 ? 288 : bytes.length;
    final headerBytes = bytes.sublist(0, headerLen);

    // 1. Check Standalone Image Signatures
    bool isStandalonePng = false;
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      isStandalonePng = true;
    }

    bool isStandaloneJpeg = false;
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      isStandaloneJpeg = true;
    }

    bool isStandaloneWebp = false;
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      isStandaloneWebp = true;
    }

    bool isStandaloneGif = false;
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      isStandaloneGif = true;
    }

    bool isStandaloneBmp = false;
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      isStandaloneBmp = true;
    }

    // 2. Check Standalone Audio Signatures (M4A container)
    bool isStandaloneM4a = false;
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
      if (brand.startsWith('m4a') || brand.startsWith('m4b') || brand.startsWith('m4p') || fileName.toLowerCase().endsWith('.m4a')) {
        isStandaloneM4a = true;
      }
    }

    // Standalone Video Signatures (MP4, MOV, MKV, AVI)
    bool isStandaloneMp4 = false;
    if (bytes.length >= 8 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70 &&
        !isStandaloneM4a) {
      isStandaloneMp4 = true;
    }

    bool isStandaloneAvi = false;
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x41 &&
        bytes[9] == 0x56 &&
        bytes[10] == 0x49 &&
        bytes[11] == 0x20) {
      isStandaloneAvi = true;
    }

    bool isStandaloneMkv = false;
    if (bytes.length >= 4 &&
        bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3) {
      isStandaloneMkv = true;
    }

    // 3. Check ICO / MP4 Box 0..3
    bool hasIco = false;
    if (bytes.length >= 4) {
      if (bytes[0] == 0 && bytes[1] == 0 && bytes[2] == 1 && bytes[3] == 0) {
        hasIco = true;
      }
    }

    // 4. Extract Dead Space / Extra Header Data (Byte 22..255)
    String extraHeaderString = '';
    if (bytes.length > 22) {
      final end = bytes.length >= 256 ? 256 : bytes.length;
      final deadSpaceBytes = bytes.sublist(22, end);
      int lastNonZero = deadSpaceBytes.length - 1;
      while (lastNonZero >= 0 && deadSpaceBytes[lastNonZero] == 0) {
        lastNonZero--;
      }
      if (lastNonZero >= 0) {
        final content = deadSpaceBytes.sublist(0, lastNonZero + 1);
        try {
          extraHeaderString = utf8.decode(content, allowMalformed: true);
        } catch (_) {
          extraHeaderString = String.fromCharCodes(content.where((b) => b >= 32 && b <= 126));
        }
      }
    }

    // 5. Check Secondary FTYP at byte 256
    bool hasSecondaryFtyp = false;
    if (bytes.length >= 264) {
      final ftypTag = String.fromCharCodes(bytes.sublist(260, 264));
      if (ftypTag == 'ftyp') {
        hasSecondaryFtyp = true;
      }
    }

    // 6. Check Image Extraction & PNG Offset from ICO directory (bytes 18..21 in Little Endian)
    int? pngOffset;
    Uint8List? extractedImageBytes;

    if (isStandalonePng || isStandaloneJpeg || isStandaloneWebp || isStandaloneGif || isStandaloneBmp) {
      extractedImageBytes = bytes;
      if (isStandalonePng) pngOffset = 0;
    } else if (hasIco && bytes.length >= 22) {
      final offset = bytes[18] | (bytes[19] << 8) | (bytes[20] << 16) | (bytes[21] << 24);
      final icoImageSize = bytes[14] | (bytes[15] << 8) | (bytes[16] << 16) | (bytes[17] << 24);

      if (offset > 0 && offset < bytes.length) {
        pngOffset = offset;

        // Try extracting PNG stream (from pngOffset to IEND chunk)
        if (pngOffset + 8 <= bytes.length &&
            bytes[pngOffset] == 0x89 &&
            bytes[pngOffset + 1] == 0x50 &&
            bytes[pngOffset + 2] == 0x4E &&
            bytes[pngOffset + 3] == 0x47) {
          int iendIdx = -1;
          for (int i = pngOffset; i + 8 <= bytes.length; i++) {
            if (bytes[i] == 0x49 && bytes[i + 1] == 0x45 && bytes[i + 2] == 0x4E && bytes[i + 3] == 0x44) {
              iendIdx = i + 4 + 4; // IEND chunk + 4 bytes CRC
              break;
            }
          }
          if (iendIdx != -1 && iendIdx <= bytes.length) {
            extractedImageBytes = bytes.sublist(pngOffset, iendIdx);
          } else if (icoImageSize > 0 && pngOffset + icoImageSize <= bytes.length) {
            extractedImageBytes = bytes.sublist(pngOffset, pngOffset + icoImageSize);
          } else {
            extractedImageBytes = bytes.sublist(pngOffset);
          }
        } else if (icoImageSize > 0 && pngOffset + icoImageSize <= bytes.length) {
          extractedImageBytes = bytes.sublist(pngOffset, pngOffset + icoImageSize);
        }
      }

      // Standalone or non-PNG ICO fallback: decode via img library
      if (extractedImageBytes == null) {
        try {
          final decodedIco = img.decodeIco(bytes) ?? img.decodeImage(bytes);
          if (decodedIco != null) {
            extractedImageBytes = Uint8List.fromList(img.encodePng(decodedIco));
          }
        } catch (_) {}
      }
    }

    // Decode Rich Image Metadata
    ImageMetadataInfo imageInfo = const ImageMetadataInfo();
    if (extractedImageBytes != null && extractedImageBytes.isNotEmpty) {
      try {
        final decoded = img.decodeImage(extractedImageBytes);
        if (decoded != null) {
          String imgFmt = 'PNG';
          if (hasIco) {
            imgFmt = 'ICO (PNG)';
          } else if (isStandaloneJpeg) {
            imgFmt = 'JPEG';
          } else if (isStandaloneWebp) {
            imgFmt = 'WebP';
          } else if (isStandaloneGif) {
            imgFmt = 'GIF';
          } else if (isStandaloneBmp) {
            imgFmt = 'BMP';
          }

          final numChannels = decoded.numChannels;
          final bpp = decoded.bitsPerChannel * numChannels;

          imageInfo = ImageMetadataInfo(
            width: decoded.width,
            height: decoded.height,
            format: imgFmt,
            colorDepth: bpp > 0 ? bpp : (decoded.hasAlpha ? 32 : 24),
            numChannels: numChannels,
            hasAlpha: decoded.hasAlpha,
            byteOffset: pngOffset,
            byteSize: extractedImageBytes.length,
          );
        }
      } catch (_) {
        // Fallback info if decoding encounters partial stream
        imageInfo = ImageMetadataInfo(
          format: hasIco ? 'ICO' : (isStandalonePng ? 'PNG' : 'Image'),
          byteOffset: pngOffset,
          byteSize: extractedImageBytes.length,
        );
      }
    }

    // 7. Check HTML wrapper & extract content
    bool hasHtml = false;
    String? extractedHtmlContent;
    HtmlMetadataInfo htmlInfo = const HtmlMetadataInfo();
    final sampleString = String.fromCharCodes(bytes.sublist(0, bytes.length >= 65536 ? 65536 : bytes.length));

    final isStandaloneHtml = fileName.toLowerCase().endsWith('.html') || fileName.toLowerCase().endsWith('.htm');
    if (isStandaloneHtml) {
      hasHtml = true;
      try {
        extractedHtmlContent = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        extractedHtmlContent = String.fromCharCodes(bytes);
      }
    } else {
      if (sampleString.contains('<style>body{font-size:0}</style>') ||
          sampleString.contains('<!--') ||
          sampleString.contains('<!DOCTYPE html>') ||
          sampleString.contains('<html') ||
          sampleString.contains('<body')) {
        hasHtml = true;

        // Extract full HTML text
        int startIdx = sampleString.indexOf('<!DOCTYPE');
        if (startIdx == -1) startIdx = sampleString.indexOf('<html');
        if (startIdx == -1) startIdx = sampleString.indexOf('<style>body{font-size:0}</style>');
        if (startIdx == -1) startIdx = sampleString.indexOf('<!--');
        if (startIdx != -1) {
          int endIdx = sampleString.indexOf('</html>', startIdx);
          if (endIdx != -1) {
            extractedHtmlContent = sampleString.substring(startIdx, endIdx + 7);
          } else {
            final closeComment = sampleString.indexOf('<!--', startIdx + 10);
            if (closeComment != -1) {
              extractedHtmlContent = sampleString.substring(startIdx, closeComment + 4);
            } else {
              extractedHtmlContent = sampleString.substring(startIdx);
            }
          }
        }
      }
    }

    if (extractedHtmlContent != null && extractedHtmlContent.isNotEmpty) {
      htmlInfo = _analyzeHtml(extractedHtmlContent);
    }

    // 8. Check PDF stream & extract metadata
    bool hasPdf = false;
    int? pdfOffset;
    Uint8List? extractedPdfBytes;
    String? pdfVersion;
    int pdfPageCount = 0;

    if (sampleString.contains('%PDF-') || sampleString.contains('1 0 obj')) {
      hasPdf = true;
      final idx = sampleString.indexOf('%PDF-');
      if (idx >= 0) {
        pdfOffset = idx;
        final pdfSub = sampleString.substring(idx);
        final verMatch = RegExp(r'%PDF-(\d+\.\d+)').firstMatch(pdfSub);
        if (verMatch != null) {
          pdfVersion = verMatch.group(1);
        }
        pdfPageCount = RegExp(r'/Type\s*/Page\b').allMatches(pdfSub).length;
        if (pdfPageCount == 0 && pdfSub.contains('/Page')) pdfPageCount = 1;

        final eofIdx = pdfSub.indexOf('%%EOF');
        if (eofIdx != -1) {
          extractedPdfBytes = bytes.sublist(idx, idx + eofIdx + 5);
        } else {
          extractedPdfBytes = bytes.sublist(idx);
        }
      }
    }

    // 9. Check ZIP EOCD signature (PK\x05\x06) & decode entries
    bool hasZip = false;
    int? zipOffset;
    final zipEntries = <ZipEntryInfo>[];

    for (int i = bytes.length - 22; i >= 0 && i >= bytes.length - 65536; i--) {
      if (bytes[i] == 0x50 && bytes[i + 1] == 0x4B && bytes[i + 2] == 0x05 && bytes[i + 3] == 0x06) {
        hasZip = true;
        // Search back for start of ZIP archive (First Local File Header PK\x03\x04)
        for (int j = 0; j < i; j++) {
          if (bytes[j] == 0x50 && bytes[j + 1] == 0x4B && bytes[j + 2] == 0x03 && bytes[j + 3] == 0x04) {
            zipOffset = j;
            break;
          }
        }
        zipOffset ??= i;

        // Decode internal files using archive ZipDecoder
        try {
          final zipData = bytes.sublist(zipOffset);
          final archive = ZipDecoder().decodeBytes(zipData, verify: false);
          for (final file in archive.files) {
            zipEntries.add(
              ZipEntryInfo(
                name: file.name,
                size: file.size,
                compressedSize: file.rawContent?.length ?? file.size,
                isDirectory: !file.isFile || file.name.endsWith('/'),
                lastModified: file.lastModDateTime,
              ),
            );
          }
        } catch (_) {}

        break;
      }
    }

    // 10. MP4 / Audio Media Metadata & Atom traversal
    final atomBoxes = <String>[];
    String? videoCodec;
    String? audioCodec;
    double? durationSeconds;
    int? videoWidth;
    int? videoHeight;

    final isAudioExtension = fileName.toLowerCase().endsWith('.mp3') ||
        fileName.toLowerCase().endsWith('.m4a') ||
        fileName.toLowerCase().endsWith('.aac') ||
        fileName.toLowerCase().endsWith('.wav');

    int mediaCursor = isStandaloneMp4 ? 0 : 288;
    if (bytes.length > mediaCursor + 8) {
      while (mediaCursor + 8 <= bytes.length) {
        final boxSize = (bytes[mediaCursor] << 24) |
            (bytes[mediaCursor + 1] << 16) |
            (bytes[mediaCursor + 2] << 8) |
            bytes[mediaCursor + 3];
        if (boxSize < 8 || mediaCursor + boxSize > bytes.length) {
          break;
        }
        final t0 = bytes[mediaCursor + 4];
        final t1 = bytes[mediaCursor + 5];
        final t2 = bytes[mediaCursor + 6];
        final t3 = bytes[mediaCursor + 7];
        final isAscii = (t0 >= 32 && t0 <= 126) &&
            (t1 >= 32 && t1 <= 126) &&
            (t2 >= 32 && t2 <= 126) &&
            (t3 >= 32 && t3 <= 126);
        if (!isAscii) {
          break;
        }

        final type = String.fromCharCodes(bytes.sublist(mediaCursor + 4, mediaCursor + 8));
        atomBoxes.add(type);

        if (type == 'moov') {
          final moovBytes = bytes.sublist(mediaCursor, mediaCursor + boxSize);
          final moovStr = String.fromCharCodes(moovBytes.where((b) => b >= 32 && b <= 126));
          if (moovStr.contains('avc1')) videoCodec = 'H.264 (AVC1)';
          if (moovStr.contains('hvc1') || moovStr.contains('hev1')) videoCodec = 'H.265 (HEVC)';
          if (moovStr.contains('vp09') || moovStr.contains('vp08')) videoCodec = 'VP8/VP9';
          if (moovStr.contains('av01')) videoCodec = 'AV1 Video';
          if (moovStr.contains('vide')) videoCodec ??= 'Native Video Track';

          if (moovStr.contains('mp4a')) audioCodec = 'AAC Audio';
          if (moovStr.contains('opus')) audioCodec = 'Opus Audio';
          if (moovStr.contains('mp3')) audioCodec = 'MP3 Audio';
          if (moovStr.contains('soun')) audioCodec ??= 'Native Audio Track';
        }

        mediaCursor += boxSize;
      }
    }

    bool isVideoMedia = false;
    if (isStandaloneM4a) {
      audioCodec ??= 'AAC Audio (M4A)';
      isVideoMedia = false;
    } else if (isAudioExtension && !isStandaloneMp4) {
      audioCodec ??= 'Audio Stream';
      isVideoMedia = false;
    } else if (hasSecondaryFtyp || isStandaloneMp4) {
      // In an MP4 container, check if it has a video stream or is audio-only
      if (videoCodec == null && audioCodec != null) {
        isVideoMedia = false;
      } else {
        isVideoMedia = true;
      }
    } else if (isStandaloneAvi || isStandaloneMkv) {
      isVideoMedia = true;
    }

    // 11. Locate Appendable Payload Section
    int? appendableOffset;
    int? appendableSize;
    Uint8List? appendableBytes;
    String? appendablePreviewText;

    if (bytes.length > 288 && (hasIco || hasSecondaryFtyp)) {
      int mp4Cursor = 288;
      while (mp4Cursor + 8 <= bytes.length) {
        final boxSize = (bytes[mp4Cursor] << 24) |
            (bytes[mp4Cursor + 1] << 16) |
            (bytes[mp4Cursor + 2] << 8) |
            bytes[mp4Cursor + 3];
        if (boxSize < 8 || mp4Cursor + boxSize > bytes.length) {
          break;
        }
        final t0 = bytes[mp4Cursor + 4];
        final t1 = bytes[mp4Cursor + 5];
        final t2 = bytes[mp4Cursor + 6];
        final t3 = bytes[mp4Cursor + 7];
        final isAscii = (t0 >= 32 && t0 <= 126) &&
            (t1 >= 32 && t1 <= 126) &&
            (t2 >= 32 && t2 <= 126) &&
            (t3 >= 32 && t3 <= 126);
        if (!isAscii) {
          break;
        }
        mp4Cursor += boxSize;
      }

      int payloadStart = mp4Cursor;

      // If PDF is present, find the %%EOF marker
      if (hasPdf) {
        final pdfSub = String.fromCharCodes(bytes.sublist(payloadStart < bytes.length ? payloadStart : 0));
        final eofIdx = pdfSub.indexOf('%%EOF');
        if (eofIdx != -1) {
          payloadStart += eofIdx + 5;
          while (payloadStart < bytes.length && (bytes[payloadStart] == 10 || bytes[payloadStart] == 13)) {
            payloadStart++;
          }
        }
      }

      final payloadEnd = zipOffset ?? bytes.length;
      if (payloadStart < payloadEnd && (payloadEnd - payloadStart) > 0) {
        appendableOffset = payloadStart;
        appendableSize = payloadEnd - payloadStart;
        appendableBytes = bytes.sublist(payloadStart, payloadEnd);

        // Decode preview string (up to 1000 characters)
        final previewSlice = appendableBytes.sublist(0, appendableBytes.length > 1000 ? 1000 : appendableBytes.length);
        try {
          appendablePreviewText = utf8.decode(previewSlice, allowMalformed: true);
        } catch (_) {
          appendablePreviewText = String.fromCharCodes(previewSlice.where((b) => b >= 32 && b <= 126));
        }
      }
    }

    // Determine detected formats
    final formats = <String>[];
    if (hasIco) formats.add('.ico');
    if (pngOffset != null || isStandalonePng) {
      if (!formats.contains('.png')) formats.add('.png');
    }
    if (isStandaloneJpeg && !formats.contains('.jpg')) formats.add('.jpg');
    if (isStandaloneWebp && !formats.contains('.webp')) formats.add('.webp');
    if (isStandaloneBmp && !formats.contains('.bmp')) formats.add('.bmp');
    if (isStandaloneGif && !formats.contains('.gif')) formats.add('.gif');

    if (isStandaloneM4a && !formats.contains('.m4a')) formats.add('.m4a');
    if (isStandaloneAvi && !formats.contains('.avi')) formats.add('.avi');
    if (isStandaloneMkv && !formats.contains('.mkv')) formats.add('.mkv');

    if (hasSecondaryFtyp || isStandaloneMp4) {
      if (isVideoMedia) {
        if (!formats.contains('.mp4')) formats.add('.mp4');
      } else {
        if (!formats.contains('.m4a')) formats.add('.m4a');
      }
    }

    if (hasHtml && !formats.contains('.html')) formats.add('.html');
    if (hasPdf && !formats.contains('.pdf')) formats.add('.pdf');
    if (hasZip && !formats.contains('.zip')) formats.add('.zip');
    if (appendableBytes != null && appendableBytes.isNotEmpty) {
      if (!formats.contains('.bin')) formats.add('.bin');
    }

    // Extract pure audio / media byte slices for playback and export
    Uint8List? extractedAudioBytes;
    Uint8List? extractedMediaBytes;

    if (hasIco && hasSecondaryFtyp) {
      // Dual-purpose MP4 container payload starts at offset 256
      if (bytes.length > 256) {
        final extractedSlice = Uint8List.fromList(bytes.sublist(256));
        try {
          final extractedBoxes = Mp4BoxEngine.parseTopLevelBoxes(extractedSlice);
          final moovBox = extractedBoxes.firstWhere((b) => b.type == 'moov');
          final moovData = Uint8List.fromList(extractedSlice.sublist(moovBox.offset, moovBox.offset + moovBox.size));
          Mp4BoxEngine.shiftChunkOffsets(moovData, -256);
          extractedSlice.setRange(moovBox.offset, moovBox.offset + moovBox.size, moovData);
        } catch (_) {}
        extractedMediaBytes = extractedSlice;
        if (!isVideoMedia) {
          extractedAudioBytes = extractedSlice;
        }
      }
    } else {
      // Standalone audio or media file
      if (isStandaloneM4a || (isAudioExtension && !isStandaloneMp4)) {
        extractedAudioBytes = bytes;
      } else if (isStandaloneMp4 || isStandaloneAvi || isStandaloneMkv) {
        extractedMediaBytes = bytes;
      }
    }

    return PolyglotInspectionResult(
      fileName: fileName,
      fileSize: fileSize,
      headerBytes: headerBytes,
      extraHeaderString: extraHeaderString,
      hasIcoHeader: hasIco,
      hasSecondaryFtyp: hasSecondaryFtyp,
      hasHtmlWrapper: hasHtml,
      hasPdfStream: hasPdf,
      hasZipEocd: hasZip,
      pngOffset: pngOffset,
      pdfOffset: pdfOffset,
      zipOffset: zipOffset,
      appendableOffset: appendableOffset,
      appendableSize: appendableSize,
      appendableBytes: appendableBytes,
      appendablePreviewText: appendablePreviewText,
      detectedFormats: formats,
      rawBytes: bytes,
      extractedImageBytes: extractedImageBytes,
      extractedAudioBytes: extractedAudioBytes,
      extractedMediaBytes: extractedMediaBytes,
      imageInfo: imageInfo,
      zipEntries: zipEntries,
      extractedHtmlContent: extractedHtmlContent,
      htmlInfo: htmlInfo,
      extractedPdfBytes: extractedPdfBytes,
      pdfVersion: pdfVersion,
      pdfPageCount: pdfPageCount,
      mediaInfo: MediaMetadataInfo(
        width: videoWidth,
        height: videoHeight,
        durationSeconds: durationSeconds,
        videoCodec: videoCodec,
        audioCodec: audioCodec,
        atomBoxes: atomBoxes,
        isVideo: isVideoMedia,
      ),
    );
  }

  static HtmlMetadataInfo _analyzeHtml(String htmlContent) {
    if (htmlContent.isEmpty) return const HtmlMetadataInfo();

    // Extract <title>
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(htmlContent);
    final title = titleMatch?.group(1)?.trim();

    // Count scripts & extract sources
    final scriptMatches = RegExp(r'<script\b([^>]*)>(.*?)</script>', caseSensitive: false, dotAll: true).allMatches(htmlContent).toList();
    final selfClosingScripts = RegExp(r'<script\b([^>]*)/?>', caseSensitive: false).allMatches(htmlContent).length;
    final scriptCount = scriptMatches.isNotEmpty ? scriptMatches.length : selfClosingScripts;

    final scriptSources = <String>[];
    for (final m in RegExp(r'<script[^>]+src=["' "'" r']([^"' "'" r']+)["' "'" r']', caseSensitive: false).allMatches(htmlContent)) {
      final src = m.group(1);
      if (src != null && src.isNotEmpty) scriptSources.add(src);
    }

    // Count styles & stylesheets
    final styleCount = RegExp(r'<style\b[^>]*>', caseSensitive: false).allMatches(htmlContent).length;
    final linkMatches = RegExp(r'<link\b[^>]*>', caseSensitive: false).allMatches(htmlContent).toList();
    final stylesheetHrefs = <String>[];
    for (final m in RegExp(r'<link[^>]+(?:rel=["' "'" r']stylesheet["' "'" r'])[^>]+href=["' "'" r']([^"' "'" r']+)["' "'" r']', caseSensitive: false).allMatches(htmlContent)) {
      final href = m.group(1);
      if (href != null && href.isNotEmpty) stylesheetHrefs.add(href);
    }

    // Tag counts
    final imgCount = RegExp(r'<img\b', caseSensitive: false).allMatches(htmlContent).length;
    final anchorCount = RegExp(r'<a\b', caseSensitive: false).allMatches(htmlContent).length;
    final formCount = RegExp(r'<form\b', caseSensitive: false).allMatches(htmlContent).length;
    final canvasCount = RegExp(r'<canvas\b', caseSensitive: false).allMatches(htmlContent).length;
    final svgCount = RegExp(r'<svg\b', caseSensitive: false).allMatches(htmlContent).length;
    final buttonCount = RegExp(r'<button\b', caseSensitive: false).allMatches(htmlContent).length;
    final inputCount = RegExp(r'<input\b', caseSensitive: false).allMatches(htmlContent).length;

    final hasInlineStyles = RegExp(r'\bstyle=["' "'" r'][^"' "'" r']+["' "'" r']', caseSensitive: false).hasMatch(htmlContent);
    final hasInlineEvents = RegExp(r'\bon[a-z]+=["' "'" r'][^"' "'" r']+["' "'" r']', caseSensitive: false).hasMatch(htmlContent);
    final hasJavaScript = scriptCount > 0 || hasInlineEvents || htmlContent.contains('javascript:');
    final hasCss = styleCount > 0 || stylesheetHrefs.isNotEmpty || hasInlineStyles;

    // Clean body extract if polyglot wrapper
    String? cleanBody;
    if (htmlContent.contains('<style>body{font-size:0}</style><div style=font-size:initial>')) {
      final start = htmlContent.indexOf('<div style=font-size:initial>') + '<div style=font-size:initial>'.length;
      final end = htmlContent.indexOf('</div><!--', start);
      if (end != -1) {
        cleanBody = htmlContent.substring(start, end);
      }
    }

    final lines = htmlContent.split('\n').length;

    return HtmlMetadataInfo(
      title: title,
      scriptCount: scriptCount,
      styleCount: styleCount,
      linkCount: linkMatches.length,
      imageTagCount: imgCount,
      anchorCount: anchorCount,
      formCount: formCount,
      canvasCount: canvasCount,
      svgCount: svgCount,
      buttonCount: buttonCount,
      inputCount: inputCount,
      hasInlineStyles: hasInlineStyles,
      hasJavaScript: hasJavaScript,
      hasCss: hasCss,
      scriptSources: scriptSources,
      stylesheetHrefs: stylesheetHrefs,
      cleanBodyHtml: cleanBody,
      lineCount: lines,
      characterCount: htmlContent.length,
    );
  }
}
