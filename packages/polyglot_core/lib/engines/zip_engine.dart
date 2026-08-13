import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Handles ZIP archive merging, in-memory packing, and Central Directory offset shifting.
/// Replaces `zip`, `unzip`, and `zip -A` CLI utilities completely.
class ZipEngine {
  /// Merges multiple ZIP archives into a single unified ZIP archive.
  /// Files from later archives overwrite earlier files on conflict.
  static Uint8List mergeZipArchives(List<Uint8List> zipByteArrays) {
    if (zipByteArrays.isEmpty) {
      return Uint8List(0);
    }

    final mergedArchive = Archive();
    final seenPaths = <String>{};

    // Iterate backwards so latest archive entries take precedence
    for (int i = zipByteArrays.length - 1; i >= 0; i--) {
      final zipBytes = zipByteArrays[i];
      if (zipBytes.isEmpty) continue;

      try {
        final decoded = ZipDecoder().decodeBytes(zipBytes, verify: false);
        for (final file in decoded.files) {
          if (!seenPaths.contains(file.name)) {
            seenPaths.add(file.name);
            mergedArchive.addFile(file);
          }
        }
      } catch (_) {
        // Continue if one archive is corrupted or partial
      }
    }

    final encoder = ZipEncoder();
    final encoded = encoder.encode(mergedArchive, level: 9);
    return Uint8List.fromList(encoded);
  }

  /// Adjusts the Central Directory record and local file header offsets by [prefixSize].
  /// Mimics `zip -A` behavior natively in memory.
  static Uint8List adjustZipOffsets(Uint8List zipBytes, int prefixSize) {
    if (prefixSize == 0 || zipBytes.length < 22) {
      return zipBytes;
    }

    final adjustedBytes = Uint8List.fromList(zipBytes);
    final byteData = ByteData.sublistView(adjustedBytes);

    // 1. Locate End of Central Directory (EOCD) signature: 0x06054b50
    int eocdOffset = -1;
    for (int i = adjustedBytes.length - 22; i >= 0; i--) {
      if (byteData.getUint32(i, Endian.little) == 0x06054b50) {
        eocdOffset = i;
        break;
      }
    }

    if (eocdOffset == -1) {
      return adjustedBytes;
    }

    final cdOffset = byteData.getUint32(eocdOffset + 16, Endian.little);
    final cdSize = byteData.getUint32(eocdOffset + 12, Endian.little);

    // Update Central Directory start offset in EOCD
    byteData.setUint32(eocdOffset + 16, cdOffset + prefixSize, Endian.little);

    // 2. Iterate through all Central Directory headers (signature 0x02014b50)
    int currCd = cdOffset;
    final cdEnd = cdOffset + cdSize;

    while (currCd + 46 <= cdEnd && currCd + 46 <= adjustedBytes.length) {
      if (byteData.getUint32(currCd, Endian.little) != 0x02014b50) {
        break;
      }

      // Offset 42: Relative offset of local header (uint32 LE)
      final localHeaderOffset = byteData.getUint32(currCd + 42, Endian.little);
      byteData.setUint32(currCd + 42, localHeaderOffset + prefixSize, Endian.little);

      final fileNameLen = byteData.getUint16(currCd + 28, Endian.little);
      final extraFieldLen = byteData.getUint16(currCd + 30, Endian.little);
      final commentLen = byteData.getUint16(currCd + 32, Endian.little);

      currCd += 46 + fileNameLen + extraFieldLen + commentLen;
    }

    return adjustedBytes;
  }
}
