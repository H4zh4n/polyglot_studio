import 'dart:io' show File, Platform, Process;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:polyglot_core/polyglot_core.dart';
import '../models/app_file.dart';
import '../utils/number_utils.dart';

/// GetX Controller for managing in-memory polyglot generation and inspection across Web and native platforms.
class PolyglotController extends GetxController {
  // Input Reactive States
  final Rx<AppFile?> imageFile = Rx<AppFile?>(null);
  final Rx<AppFile?> mediaFile = Rx<AppFile?>(null);
  final RxBool isVideo = true.obs;

  final Rx<AppFile?> pdfFile = Rx<AppFile?>(null);
  final Rx<AppFile?> htmlFile = Rx<AppFile?>(null);
  final RxString htmlDirectText = ''.obs;

  final RxList<AppFile> zipFiles = <AppFile>[].obs;
  final RxList<AppFile> appendableFiles = <AppFile>[].obs;
  final RxString extraHeaderData = ''.obs;

  // Processing & Memory Reactive States
  final RxBool isGenerating = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxString statusMessage = ''.obs;
  final Rx<PolyglotResult?> polyglotResult = Rx<PolyglotResult?>(null);
  final RxString lastSavedFilePath = ''.obs;
  final RxString generationTimestamp = ''.obs;

  // Inspector Reactive States
  final Rx<PolyglotInspectionResult?> inspectionResult = Rx<PolyglotInspectionResult?>(null);
  final RxBool isInspecting = false.obs;
  final RxInt selectedViewMode = 0.obs; // 0 = Generator Studio, 1 = Inspector & Payloads

  // Validation
  bool get canGenerate => imageFile.value != null && mediaFile.value != null && !isGenerating.value;

  static String _currentTimestamp() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '$y$m$d' '_' '$h$min$s';
  }

  /// Generates the timestamped multi-extension filename, e.g. "polyglot_20260813_195952.ico.mp4.html.pdf.zip"
  String get combinedFileName {
    final result = polyglotResult.value;
    final ts = generationTimestamp.value.isNotEmpty ? generationTimestamp.value : _currentTimestamp();

    if (result == null) return 'polyglot_$ts.ico.mp4';

    final exts = <String>[];
    for (final ext in result.supportedExtensions) {
      final clean = ext.replaceAll('.', '').toLowerCase();
      if (!exts.contains(clean)) {
        exts.add(clean);
      }
    }
    return 'polyglot_$ts.${exts.join('.')}';
  }

  // Pickers
  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'ico'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      imageFile.value = AppFile.fromPlatformFile(result.files.first);
    }
  }

  Future<void> pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'm4v', 'm4a', 'mov', 'mp3', 'aac', 'wav', 'mkv', 'avi'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final pf = result.files.first;
      final file = AppFile.fromPlatformFile(pf);
      mediaFile.value = file;
      isVideo.value = !['.mp3', '.m4a', '.aac', '.wav'].contains(file.extension);
    }
  }

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      pdfFile.value = AppFile.fromPlatformFile(result.files.first);
    }
  }

  Future<void> pickHtml() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      htmlFile.value = AppFile.fromPlatformFile(result.files.first);
    }
  }

  Future<void> pickZipFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['zip', 'jar', 'apk', 'docx', 'xlsx', 'pptx'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      for (final pf in result.files) {
        zipFiles.add(AppFile.fromPlatformFile(pf));
      }
    }
  }

  Future<void> pickAppendables() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      for (final pf in result.files) {
        appendableFiles.add(AppFile.fromPlatformFile(pf));
      }
    }
  }

  // Handle Drag-and-Drop
  void handleDroppedFiles(List<AppFile> files) {
    for (final file in files) {
      final ext = file.extension;
      if (['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.ico'].contains(ext)) {
        imageFile.value = file;
      } else if (['.mp4', '.m4v', '.mov', '.mkv', '.avi'].contains(ext)) {
        mediaFile.value = file;
        isVideo.value = true;
      } else if (['.mp3', '.m4a', '.aac', '.wav'].contains(ext)) {
        mediaFile.value = file;
        isVideo.value = false;
      } else if (ext == '.pdf') {
        pdfFile.value = file;
      } else if (['.html', '.htm'].contains(ext)) {
        htmlFile.value = file;
      } else if (['.zip', '.jar', '.apk', '.docx', '.xlsx', '.pptx'].contains(ext)) {
        zipFiles.add(file);
      } else {
        appendableFiles.add(file);
      }
    }
  }

  // Generate Polyglot In Memory
  Future<void> generatePolyglotInMemory() async {
    if (!canGenerate) return;

    isGenerating.value = true;
    progress.value = 0.1;
    statusMessage.value = 'Reading input assets into memory...';
    polyglotResult.value = null;
    lastSavedFilePath.value = '';
    generationTimestamp.value = _currentTimestamp();

    try {
      final imageBytes = await imageFile.value!.readAsBytes();
      final mediaBytes = await mediaFile.value!.readAsBytes();

      if (imageBytes.isEmpty) {
        throw Exception('Could not read bytes from image file: ${imageFile.value!.name}');
      }
      if (mediaBytes.isEmpty) {
        throw Exception('Could not read bytes from media file: ${mediaFile.value!.name}');
      }

      progress.value = 0.3;
      statusMessage.value = 'Processing HTML & PDF data in memory...';

      String? htmlContent;
      if (htmlFile.value != null) {
        htmlContent = await htmlFile.value!.readAsString();
      } else if (htmlDirectText.value.isNotEmpty) {
        htmlContent = htmlDirectText.value;
      }

      Uint8List? pdfBytes;
      if (pdfFile.value != null) {
        pdfBytes = await pdfFile.value!.readAsBytes();
      }

      progress.value = 0.5;
      statusMessage.value = 'Merging ZIP archives in memory...';

      final zipByteList = <Uint8List>[];
      for (final z in zipFiles) {
        final b = await z.readAsBytes();
        if (b.isNotEmpty) {
          zipByteList.add(b);
        }
      }

      final appendableByteList = <Uint8List>[];
      for (final a in appendableFiles) {
        final b = await a.readAsBytes();
        if (b.isNotEmpty) {
          appendableByteList.add(b);
        }
      }

      progress.value = 0.7;
      statusMessage.value = 'Synthesizing polyglot binary in RAM...';

      final result = await PolyglotGenerator.generate(
        PolyglotInputs(
          imageBytes: imageBytes,
          imageName: imageFile.value!.name,
          mediaBytes: mediaBytes,
          mediaName: mediaFile.value!.name,
          isVideo: isVideo.value,
          htmlContent: htmlContent,
          pdfBytes: pdfBytes,
          zipArchives: zipByteList,
          extraHeaderData: extraHeaderData.value,
          appendables: appendableByteList,
        ),
      );

      progress.value = 1.0;
      statusMessage.value = 'Polyglot binary ready in memory!';
      polyglotResult.value = result;

      // Auto-inspect the newly generated result
      inspectionResult.value = PolyglotInspector.inspect(
        bytes: result.data,
        fileName: combinedFileName,
      );

      Get.snackbar(
        'Polyglot Ready',
        'Assembled in memory (${NumberUtils.formatSizeKb(result.totalBytes)})',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E222A),
        colorText: const Color(0xFFF9FAFB),
        borderColor: const Color(0x33FFFFFF),
        borderWidth: 1,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      statusMessage.value = 'Error: $e';
      Get.snackbar(
        'Generation Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E222A),
        colorText: const Color(0xFFF87171),
        borderColor: const Color(0x33FFFFFF),
        borderWidth: 1,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isGenerating.value = false;
    }
  }

  // Save to Disk with Timestamped Multi-Extension
  Future<void> saveToDisk() async {
    final result = polyglotResult.value;
    if (result == null) return;

    final defaultName = combinedFileName;

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Polyglot File to Disk',
      fileName: defaultName,
      type: FileType.any,
      bytes: result.data,
    );

    if (kIsWeb) {
      Get.snackbar(
        'File Downloaded',
        'Downloaded $defaultName',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E222A),
        colorText: const Color(0xFFF9FAFB),
        borderColor: const Color(0x33FFFFFF),
        borderWidth: 1,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    if (savePath != null) {
      final file = File(savePath);
      await file.writeAsBytes(result.data);
      lastSavedFilePath.value = savePath;

      Get.snackbar(
        'File Saved',
        'Saved to $savePath',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E222A),
        colorText: const Color(0xFFF9FAFB),
        borderColor: const Color(0x33FFFFFF),
        borderWidth: 1,
        duration: const Duration(seconds: 4),
      );
    }
  }

  // Inspect any existing file
  Future<void> pickAndInspectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      await inspectFile(AppFile.fromPlatformFile(result.files.first));
    }
  }

  Future<void> inspectFile(AppFile file) async {
    try {
      isInspecting.value = true;
      final bytes = await file.readAsBytes();
      final name = file.name;
      inspectionResult.value = PolyglotInspector.inspect(bytes: bytes, fileName: name);
    } catch (e) {
      Get.snackbar(
        'Inspection Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E222A),
        colorText: const Color(0xFFF87171),
      );
    } finally {
      isInspecting.value = false;
    }
  }

  // Extract detected image stream to a file
  Future<void> extractImageFile() async {
    final res = inspectionResult.value;
    if (res == null || res.extractedImageBytes == null || res.extractedImageBytes!.isEmpty) return;

    final ext = res.imageInfo.format?.toLowerCase().contains('ico') == true ? 'ico' : 'png';
    final baseName = p.basenameWithoutExtension(res.fileName);
    final defaultName = '${baseName}_extracted.$ext';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Extracted Image to Disk',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: [ext, 'png', 'ico', 'jpg', 'webp'],
      bytes: res.extractedImageBytes!,
    );

    if (kIsWeb) {
      Get.snackbar(
        'Image Downloaded',
        'Downloaded $defaultName (${NumberUtils.formatBytesExact(res.extractedImageBytes!.length)})',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E222A),
        colorText: const Color(0xFFF9FAFB),
        borderColor: const Color(0x33FFFFFF),
        borderWidth: 1,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    if (savePath != null) {
      final file = File(savePath);
      await file.writeAsBytes(res.extractedImageBytes!);
      Get.snackbar(
        'Image Extracted',
        'Saved image (${NumberUtils.formatBytesExact(res.extractedImageBytes!.length)}) to $savePath',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E222A),
        colorText: const Color(0xFFF9FAFB),
        borderColor: const Color(0x33FFFFFF),
        borderWidth: 1,
        duration: const Duration(seconds: 4),
      );
    }
  }

  // Extract detected media stream (MP4/MP3) to a file
  Future<void> extractMediaFile({String? preferredExtension}) async {
    final res = inspectionResult.value;
    if (res == null || res.rawBytes == null || res.rawBytes!.isEmpty) return;

    final isAudio = !res.mediaInfo.isVideo;
    final defaultExt = preferredExtension ?? (isAudio ? 'mp3' : 'mp4');
    final baseName = p.basenameWithoutExtension(res.fileName);
    final defaultName = '${baseName}_media.$defaultExt';
    final bytesToSave = (isAudio ? res.extractedAudioBytes : res.extractedMediaBytes) ?? res.rawBytes!;

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Extracted Media to Disk',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: [defaultExt, 'mp4', 'mp3', 'm4a', 'wav', 'mov'],
      bytes: bytesToSave,
    );

    if (kIsWeb) {
      Get.snackbar(
        'Media Downloaded',
        'Downloaded $defaultName (${NumberUtils.formatBytesExact(bytesToSave.length)})',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E222A),
        colorText: const Color(0xFFF9FAFB),
        borderColor: const Color(0x33FFFFFF),
        borderWidth: 1,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    if (savePath != null) {
      final file = File(savePath);
      await file.writeAsBytes(bytesToSave);
      Get.snackbar(
        'Media Extracted',
        'Saved media (${NumberUtils.formatBytesExact(bytesToSave.length)}) to $savePath',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E222A),
        colorText: const Color(0xFFF9FAFB),
        borderColor: const Color(0x33FFFFFF),
        borderWidth: 1,
        duration: const Duration(seconds: 4),
      );
    }
  }

  // Extract detected appendable payload to a file
  Future<void> extractAppendablePayload() async {
    final res = inspectionResult.value;
    if (res == null || res.appendableBytes == null) return;

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Extracted Payload to Disk',
      fileName: 'extracted_payload.bin',
      type: FileType.any,
      bytes: res.appendableBytes!,
    );

    if (kIsWeb) {
      Get.snackbar(
        'Payload Downloaded',
        'Downloaded extracted_payload.bin (${NumberUtils.formatBytesExact(res.appendableBytes!.length)})',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E222A),
        colorText: const Color(0xFFF9FAFB),
        borderColor: const Color(0x33FFFFFF),
        borderWidth: 1,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    if (savePath != null) {
      final file = File(savePath);
      await file.writeAsBytes(res.appendableBytes!);
      Get.snackbar(
        'Payload Extracted',
        'Saved payload (${NumberUtils.formatBytesExact(res.appendableBytes!.length)}) to $savePath',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E222A),
        colorText: const Color(0xFFF9FAFB),
        borderColor: const Color(0x33FFFFFF),
        borderWidth: 1,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void clearInspection() {
    inspectionResult.value = null;
  }

  // Open file in containing folder (Native only)
  Future<void> openContainingFolder() async {
    if (kIsWeb) return;
    final filePath = lastSavedFilePath.value;
    if (filePath.isEmpty || !await File(filePath).exists()) return;

    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [p.dirname(filePath)]);
      }
    } catch (_) {}
  }

  void reset() {
    imageFile.value = null;
    mediaFile.value = null;
    pdfFile.value = null;
    htmlFile.value = null;
    htmlDirectText.value = '';
    zipFiles.clear();
    appendableFiles.clear();
    extraHeaderData.value = '';
    polyglotResult.value = null;
    lastSavedFilePath.value = '';
    inspectionResult.value = null;
    generationTimestamp.value = '';
    progress.value = 0.0;
    statusMessage.value = '';
  }
}
