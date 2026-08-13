import 'dart:typed_data';
import '../models/polyglot_inputs.dart';
import '../models/polyglot_result.dart';
import 'image_ico_engine.dart';
import 'media_converter.dart';
import 'mp4_box_engine.dart';
import 'pdf_stream_engine.dart';
import 'zip_engine.dart';

/// Primary orchestrator that produces the multi-format polyglot file.
class PolyglotGenerator {
  /// Generates the complete polyglot binary from the provided [inputs].
  static Future<PolyglotResult> generate(PolyglotInputs inputs) async {
    final warnings = <String>[];
    final mediaExt = inputs.isVideo ? '.mp4' : '.m4a';
    final supportedExtensions = <String>['.ico', mediaExt];

    // 1. Process & normalize input image to 32bpp PNG
    final pngBytes = ImageIcoEngine.convertTo32bppPng(inputs.imageBytes);

    // 2. Normalize input video/audio to MP4/M4A container if FFmpeg is available
    final normalizedMp4Bytes = await MediaConverter.normalizeToMp4(
      inputMediaBytes: inputs.mediaBytes,
      isVideo: inputs.isVideo,
      originalFilename: inputs.mediaName,
    );

    // 3. Build Core MP4/M4A + ICO + HTML + PDF
    final mediaPolyglotBytes = Mp4BoxEngine.buildPolyglotMp4(
      originalMp4Bytes: normalizedMp4Bytes,
      pngBytes: pngBytes,
      htmlContent: inputs.htmlContent,
      extraHeaderData: inputs.extraHeaderData,
      pdfBytes: inputs.pdfBytes,
    );

    final outputBuilder = BytesBuilder(copy: false);
    outputBuilder.add(mediaPolyglotBytes);

    if (inputs.htmlContent != null && inputs.htmlContent!.isNotEmpty) {
      supportedExtensions.add('.html');
    }

    // 4. PDF Pass 2 (if present)
    int? pdfOffset;
    if (inputs.pdfBytes != null && inputs.pdfBytes!.isNotEmpty) {
      pdfOffset = outputBuilder.length;
      final pdfPayload = PdfStreamEngine.buildAdjustedPdfPayload(
        originalPdfBytes: inputs.pdfBytes!,
        prefixFileSize: mediaPolyglotBytes.length,
      );
      outputBuilder.add(pdfPayload);
      supportedExtensions.add('.pdf');
    }

    // 5. Append arbitrary raw binaries (if any)
    for (final appendable in inputs.appendables) {
      if (appendable.isNotEmpty) {
        outputBuilder.add(appendable);
      }
    }

    // 6. Merge & adjust ZIP archives (if any)
    int? zipOffset;
    if (inputs.zipArchives.isNotEmpty) {
      zipOffset = outputBuilder.length;
      final mergedZip = ZipEngine.mergeZipArchives(inputs.zipArchives);
      if (mergedZip.isNotEmpty) {
        final adjustedZip = ZipEngine.adjustZipOffsets(mergedZip, zipOffset);
        outputBuilder.add(adjustedZip);
        supportedExtensions.add('.zip');
      }
    }

    final finalBytes = outputBuilder.toBytes();
    final htmlLen = inputs.htmlContent != null && inputs.htmlContent!.isNotEmpty
        ? ('--><style>body{font-size:0}</style><div style=font-size:initial>${inputs.htmlContent}</div><!--').length
        : 0;
    final pngOffset = 288 + 8 + htmlLen;

    return PolyglotResult(
      data: finalBytes,
      pngOffset: pngOffset,
      pngSize: pngBytes.length,
      mp4Size: mediaPolyglotBytes.length,
      pdfOffset: pdfOffset,
      zipOffset: zipOffset,
      supportedExtensions: supportedExtensions,
      warnings: warnings,
    );
  }
}
