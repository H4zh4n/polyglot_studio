import 'dart:convert';
import 'dart:typed_data';
import 'image_ico_engine.dart';

/// Handles PDF encapsulation, stream termination, and cross-reference table recalculation.
class PdfStreamEngine {
  /// Pads a number with leading zeros up to [targetLen].
  static String padLeft(int num, int targetLen) {
    final s = num.toString();
    if (s.length >= targetLen) return s;
    return '0' * (targetLen - s.length) + s;
  }

  /// Constructs the tail PDF payload with adjusted xref and startxref tables.
  static Uint8List buildAdjustedPdfPayload({
    required Uint8List originalPdfBytes,
    required int prefixFileSize,
  }) {
    final objectTerminator = ascii.encode('\nendstream\nendobj\n');
    final terminatorLength = objectTerminator.length;

    // Buffer: terminator + original PDF + extra padding
    final totalLen = originalPdfBytes.length + terminatorLength + 32;
    final pdfBuffer = Uint8List(totalLen);
    pdfBuffer.setRange(0, terminatorLength, objectTerminator);
    pdfBuffer.setRange(terminatorLength, terminatorLength + originalPdfBytes.length, originalPdfBytes);

    try {
      final xrefTag = ascii.encode('\nxref');
      final zeroEntryTag = ascii.encode('\n0000000000');
      final startxrefTag = ascii.encode('\nstartxref');

      final xrefStart = ImageIcoEngine.findSubArrayIndex(pdfBuffer, xrefTag) + 1;
      final offsetStart = ImageIcoEngine.findSubArrayIndex(pdfBuffer, zeroEntryTag, xrefStart > 0 ? xrefStart : 0) + 1;
      final startxrefStart = ImageIcoEngine.findSubArrayIndex(pdfBuffer, startxrefTag, xrefStart > 0 ? xrefStart : 0) + 1;

      if (xrefStart <= 0 || offsetStart <= 0 || startxrefStart <= 0) {
        throw const FormatException('Could not locate PDF xref table structure.');
      }

      int startxrefEnd = pdfBuffer.indexOf(0x0A, startxrefStart + 11);
      if (startxrefEnd == -1) {
        startxrefEnd = pdfBuffer.indexOf(0x0D, startxrefStart + 11);
      }
      if (startxrefEnd == -1) startxrefEnd = pdfBuffer.length;

      // Extract entry count from xref header
      final xrefHeaderRaw = ascii.decode(pdfBuffer.sublist(xrefStart, offsetStart));
      final cleanHeader = xrefHeaderRaw.trim().replaceAll('\r', ' ').replaceAll('\n', ' ');
      final tokens = cleanHeader.split(' ').where((t) => t.isNotEmpty).toList();
      final count = int.parse(tokens.last);

      // Adjust all xref entries
      int curr = offsetStart;
      final shiftAmount = prefixFileSize + terminatorLength;

      for (int i = 0; i < count; i++) {
        if (curr + 10 > pdfBuffer.length) break;
        final offsetStr = ascii.decode(pdfBuffer.sublist(curr, curr + 10)).trim();
        final originalOffset = int.tryParse(offsetStr);
        if (originalOffset != null) {
          final newOffset = originalOffset + shiftAmount;
          final padded = padLeft(newOffset, 10).substring(0, 10);
          pdfBuffer.setRange(curr, curr + 10, ascii.encode(padded));
        }

        // Move to next line
        final nextLf = pdfBuffer.indexOf(0x0A, curr + 1);
        if (nextLf == -1) break;
        curr = nextLf + 1;
      }

      // Adjust startxref offset
      final startxrefStr = ascii.decode(pdfBuffer.sublist(startxrefStart + 10, startxrefEnd)).trim();
      final originalStartxref = int.parse(startxrefStr);
      final newStartxref = (originalStartxref + shiftAmount).toString();
      final newStartxrefBytes = ascii.encode(newStartxref);

      pdfBuffer.setRange(startxrefStart + 10, startxrefStart + 10 + newStartxrefBytes.length, newStartxrefBytes);

      // Write %%EOF marker
      final eofMarker = ascii.encode('\n%%EOF\n');
      final eofPos = startxrefStart + 10 + newStartxrefBytes.length;
      pdfBuffer.setRange(eofPos, eofPos + eofMarker.length, eofMarker);

      final finalPayloadLength = eofPos + eofMarker.length;
      return pdfBuffer.sublist(0, finalPayloadLength);
    } catch (_) {
      // If xref adjustment encounters unusual PDF formats, return clean terminator + PDF
      return Uint8List.fromList([...objectTerminator, ...originalPdfBytes]);
    }
  }
}
