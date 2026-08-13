import 'dart:convert';
import 'dart:typed_data';
import 'image_ico_engine.dart';

/// Represents a parsed MP4 box/atom.
class Mp4Box {
  final int offset;
  final int size;
  final String type;
  final int headerSize;

  const Mp4Box({
    required this.offset,
    required this.size,
    required this.type,
    required this.headerSize,
  });

  int get contentOffset => offset + headerSize;
  int get contentSize => size - headerSize;
}

/// Pure Dart MP4 box manipulation and atom rewriting engine.
/// Replaces the external `mp4edit` binary completely.
class Mp4BoxEngine {
  /// Parses top-level MP4 boxes from a binary buffer.
  static List<Mp4Box> parseTopLevelBoxes(Uint8List data) {
    final boxes = <Mp4Box>[];
    final byteData = ByteData.sublistView(data);
    int offset = 0;

    while (offset + 8 <= data.length) {
      int size = byteData.getUint32(offset, Endian.big);
      final type = String.fromCharCodes(data.sublist(offset + 4, offset + 8));
      int headerSize = 8;

      if (size == 1) {
        // 64-bit large size
        if (offset + 16 > data.length) break;
        size = byteData.getUint64(offset + 8, Endian.big);
        headerSize = 16;
      } else if (size == 0) {
        // Box extends to end of file
        size = data.length - offset;
      }

      if (size < headerSize || offset + size > data.length) {
        // Truncated or malformed box
        boxes.add(Mp4Box(
          offset: offset,
          size: data.length - offset,
          type: type,
          headerSize: headerSize,
        ));
        break;
      }

      boxes.add(Mp4Box(
        offset: offset,
        size: size,
        type: type,
        headerSize: headerSize,
      ));

      offset += size;
    }

    return boxes;
  }

  /// Recursively or iteratively searches and updates all `stco` and `co64`
  /// chunk offset tables inside the `moov` box by adding [delta].
  static void shiftChunkOffsets(Uint8List moovBytes, int delta) {
    if (delta == 0) return;
    final byteData = ByteData.sublistView(moovBytes);

    // Search for 'stco' (0x73, 0x74, 0x63, 0x6F)
    final stcoTag = [0x73, 0x74, 0x63, 0x6F];
    int searchIdx = 0;
    while (true) {
      final found = ImageIcoEngine.findSubArrayIndex(moovBytes, stcoTag, searchIdx);
      if (found == -1) break;

      final boxStart = found - 4;
      if (boxStart >= 0 && boxStart + 16 <= moovBytes.length) {
        final boxSize = byteData.getUint32(boxStart, Endian.big);
        // stco format: 4B size, 4B type, 1B version, 3B flags, 4B entry count
        final entryCount = byteData.getUint32(found + 8, Endian.big);
        final tableStart = found + 12;

        if (tableStart + (entryCount * 4) <= moovBytes.length && tableStart + (entryCount * 4) <= boxStart + boxSize) {
          for (int i = 0; i < entryCount; i++) {
            final entryOffset = tableStart + (i * 4);
            final currentOffset = byteData.getUint32(entryOffset, Endian.big);
            byteData.setUint32(entryOffset, currentOffset + delta, Endian.big);
          }
        }
      }
      searchIdx = found + 4;
    }

    // Search for 'co64' (0x63, 0x6F, 0x36, 0x34)
    final co64Tag = [0x63, 0x6F, 0x36, 0x34];
    searchIdx = 0;
    while (true) {
      final found = ImageIcoEngine.findSubArrayIndex(moovBytes, co64Tag, searchIdx);
      if (found == -1) break;

      final boxStart = found - 4;
      if (boxStart >= 0 && boxStart + 16 <= moovBytes.length) {
        final boxSize = byteData.getUint32(boxStart, Endian.big);
        // co64 format: 4B size, 4B type, 1B version, 3B flags, 4B entry count
        final entryCount = byteData.getUint32(found + 8, Endian.big);
        final tableStart = found + 12;

        if (tableStart + (entryCount * 8) <= moovBytes.length && tableStart + (entryCount * 8) <= boxStart + boxSize) {
          for (int i = 0; i < entryCount; i++) {
            final entryOffset = tableStart + (i * 8);
            final currentOffset = byteData.getUint64(entryOffset, Endian.big);
            byteData.setUint64(entryOffset, currentOffset + delta, Endian.big);
          }
        }
      }
      searchIdx = found + 4;
    }
  }

  /// Builds the crafted MP4 binary with the dual-purpose ICO header and embedded skip box.
  static Uint8List buildPolyglotMp4({
    required Uint8List originalMp4Bytes,
    required Uint8List pngBytes,
    String? htmlContent,
    String extraHeaderData = '',
    Uint8List? pdfBytes,
  }) {
    final originalBoxes = parseTopLevelBoxes(originalMp4Bytes);
    final ftypIndex = originalBoxes.indexWhere((b) => b.type == 'ftyp');
    final origFtypSize = ftypIndex != -1 ? originalBoxes[ftypIndex].size : 0;

    // 1. Prepare HTML wrapper string
    final htmlString = htmlContent != null && htmlContent.isNotEmpty
        ? '--><style>body{font-size:0}</style><div style=font-size:initial>$htmlContent</div><!--'
        : '';
    final htmlBytes = utf8.encode(htmlString);

    // 2. Prepare skip box containing HTML + PNG
    final skipPayloadLength = htmlBytes.length + pngBytes.length;
    final skipBoxLength = skipPayloadLength + 8;
    final skipBuffer = Uint8List(skipBoxLength);
    final skipByteData = ByteData.sublistView(skipBuffer);
    skipByteData.setUint32(0, skipBoxLength, Endian.big);
    skipBuffer.setRange(4, 8, ascii.encode('skip'));
    if (htmlBytes.isNotEmpty) {
      skipBuffer.setRange(8, 8 + htmlBytes.length, htmlBytes);
    }
    skipBuffer.setRange(8 + htmlBytes.length, skipBoxLength, pngBytes);

    // 3. Prepare crafted ftypBuffer (256 + 32 = 288 bytes)
    final ftypBuffer = Uint8List(288);
    // ICO signature & 288 byte box size (in BE: 0x00000120 = 288)
    ftypBuffer[2] = 1;
    ftypBuffer[3] = 32;

    // Standard secondary ftyp box header at offset 256
    final standardFtypHeader = <int>[
      0x00, 0x00, 0x00, 0x20, // size 32
      0x66, 0x74, 0x79, 0x70, // 'ftyp'
      0x69, 0x73, 0x6F, 0x6D, // 'isom'
      0x00, 0x00, 0x02, 0x00, // minor version 512
      0x69, 0x73, 0x6F, 0x6D, // 'isom'
      0x69, 0x73, 0x6F, 0x32, // 'iso2'
      0x61, 0x76, 0x63, 0x31, // 'avc1'
      0x6D, 0x70, 0x34, 0x31, // 'mp41'
    ];
    ftypBuffer.setRange(256, 288, standardFtypHeader);

    // ICO bit depth = 32
    ftypBuffer[12] = 32;
    // Set PNG size (4-byte LE)
    ftypBuffer.setRange(14, 18, ImageIcoEngine.uint32To4bLE(pngBytes.length));

    // PNG Offset calculation:
    // ftypBuffer is 288 bytes. skip box header is 8 bytes. HTML comes first.
    final pngOffset = 288 + 8 + htmlBytes.length;
    ftypBuffer.setRange(18, 22, ImageIcoEngine.uint32To4bLE(pngOffset));

    // Set ICO image count to 1 and clear initial atom name (offset 4..7 = [1, 0, 0, 0])
    ftypBuffer.setRange(4, 8, [1, 0, 0, 0]);

    // Compatible brands at byte 240
    final brands = ascii.encode('isomiso2avc1mp41');
    ftypBuffer.setRange(240, 240 + brands.length, brands);

    // User extra header data (strictly clamped so it cannot exceed byte 240)
    int atomFreeAddr = 22;
    if (extraHeaderData.isNotEmpty) {
      final extraBytes = utf8.encode(extraHeaderData);
      // Ensure at least 4 bytes remain before byte 240 for '<!--'
      const maxAllowed = 240 - 22 - 4; // 214 bytes maximum
      final safeBytes = extraBytes.length > maxAllowed ? extraBytes.sublist(0, maxAllowed) : extraBytes;
      ftypBuffer.setRange(atomFreeAddr, atomFreeAddr + safeBytes.length, safeBytes);
      atomFreeAddr += safeBytes.length;
    }

    // HTML comment opener (guaranteed within byte 240)
    final commentOpen = ascii.encode('<!--');
    if (atomFreeAddr + commentOpen.length <= 240) {
      ftypBuffer.setRange(atomFreeAddr, atomFreeAddr + commentOpen.length, commentOpen);
      atomFreeAddr += commentOpen.length;
    }

    // Estimate total MP4 size before PDF stream object calculation
    int remainingSize = 0;
    for (final box in originalBoxes) {
      if (box.type != 'ftyp') {
        remainingSize += box.size;
      }
    }
    final totalMp4Size = 288 + skipBuffer.length + remainingSize;

    // PDF Pass 1 (if PDF provided)
    if (pdfBytes != null && pdfBytes.isNotEmpty) {
      ftypBuffer[atomFreeAddr] = 0x0A; // newline
      final pdfHeaderSlice = pdfBytes.sublist(0, pdfBytes.length >= 9 ? 9 : pdfBytes.length);
      ftypBuffer.setRange(atomFreeAddr + 1, atomFreeAddr + 1 + pdfHeaderSlice.length, pdfHeaderSlice);
      atomFreeAddr += 1 + pdfHeaderSlice.length;

      // Dynamically solve object string length convergence
      int offset = 30 + totalMp4Size.toString().length;
      String objString = '';
      do {
        offset--;
        final lengthVal = totalMp4Size - atomFreeAddr - offset;
        objString = '\n1 0 obj\n<</Length $lengthVal>>\nstream\n';
      } while (offset != objString.length && offset > 0);

      final objStringBytes = ascii.encode(objString);
      ftypBuffer.setRange(atomFreeAddr, atomFreeAddr + objStringBytes.length, objStringBytes);
    }

    // 4. Extract remaining boxes from original MP4, adjusting moov chunk offsets
    final delta = (288 - origFtypSize) + skipBuffer.length;
    final remainingBytesBuilder = BytesBuilder(copy: false);

    if (originalBoxes.isEmpty || ftypIndex == -1) {
      // Input is raw audio or stream (e.g. MP3, WAV, AAC) without ISOBMFF box structure
      remainingBytesBuilder.add(originalMp4Bytes);
    } else {
      for (final box in originalBoxes) {
        if (box.type == 'ftyp') continue;
        final boxData = Uint8List.fromList(originalMp4Bytes.sublist(box.offset, box.offset + box.size));
        if (box.type == 'moov') {
          shiftChunkOffsets(boxData, delta);
        }
        remainingBytesBuilder.add(boxData);
      }
    }

    // 5. Combine: ftypBuffer + skipBuffer + remaining MP4 boxes
    final outputBuilder = BytesBuilder(copy: false);
    outputBuilder.add(ftypBuffer);
    outputBuilder.add(skipBuffer);
    outputBuilder.add(remainingBytesBuilder.toBytes());

    final finalMp4Bytes = outputBuilder.toBytes();

    // 6. Fix the bithack: Clear byte 3 to 0x00 so the first atom size becomes 256 bytes,
    // splitting the secondary standard 32-byte ftyp atom off at offset 256!
    finalMp4Bytes[3] = 0x00;

    return finalMp4Bytes;
  }
}
