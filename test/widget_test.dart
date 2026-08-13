import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:polyglot/controllers/polyglot_controller.dart';
import 'package:polyglot/main.dart';
import 'package:polyglot/models/app_file.dart';
import 'package:polyglot/views/dialogs/polyglot_detected_dialog.dart';
import 'package:polyglot/views/inspector/widgets/audio_player_preview.dart';
import 'package:polyglot/views/inspector/widgets/html_document_preview.dart';
import 'package:polyglot/views/inspector/widgets/pdf_document_preview.dart';
import 'package:polyglot/views/inspector/widgets/universal_file_preview.dart';
import 'package:polyglot/theme/app_theme.dart';
import 'package:polyglot/views/inspector/widgets/video_player_preview.dart';
import 'package:polyglot/views/inspector/widgets/zip_archive_preview.dart';
import 'package:polyglot_core/polyglot_core.dart';

void main() {
  testWidgets('PolyglotApp renders cleanly on Desktop', (WidgetTester tester) async {
    Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const PolyglotApp());
    expect(find.text('Polyglot Studio'), findsWidgets);
    expect(find.text('Primary Image'), findsOneWidget);
    expect(find.text('Video / Audio'), findsOneWidget);
    expect(find.text('2. Polyglot Payloads'), findsOneWidget);
  });

  testWidgets('PolyglotApp renders cleanly on Mobile without assertions', (WidgetTester tester) async {
    Get.put(PolyglotController());
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const PolyglotApp());
    expect(find.text('Polyglot Studio'), findsWidgets);
    expect(find.text('Primary Image'), findsOneWidget);
    expect(find.text('Video / Audio'), findsOneWidget);
    expect(find.text('2. Optional Payloads'), findsOneWidget);
  });

  testWidgets('Inspector view renders cleanly on Mobile without overflows', (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 1;
    await tester.pumpWidget(const PolyglotApp());
    await tester.pumpAndSettle();

    expect(find.text('Polyglot Inspector & Viewer'), findsOneWidget);
    expect(find.text('Drop any polyglot or media file here to view & inspect'), findsOneWidget);
  });

  testWidgets('Inspector view displays detected format personalities with icons and live previews',
      (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 1;
    controller.inspectionResult.value = PolyglotInspectionResult(
      fileName: 'polyglot_sample.ico.mp4.pdf.zip',
      fileSize: 102400,
      headerBytes: Uint8List(288),
      extraHeaderString: 'Test Polyglot',
      hasIcoHeader: true,
      hasSecondaryFtyp: true,
      hasHtmlWrapper: true,
      hasPdfStream: true,
      hasZipEocd: true,
      pngOffset: 288,
      pdfOffset: 500,
      zipOffset: 800,
      detectedFormats: ['.ico', '.png', '.mp4', '.pdf', '.zip'],
      zipEntries: const [
        ZipEntryInfo(name: 'embedded_file.txt', size: 1024, compressedSize: 400),
        ZipEntryInfo(name: 'assets/image.png', size: 2048, compressedSize: 1500),
      ],
      pdfVersion: '1.4',
      pdfPageCount: 1,
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pumpAndSettle();

    expect(find.text('Multi-Format Live Viewer (6 Formats Available)'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsWidgets);
    expect(find.byIcon(Icons.videocam_outlined), findsWidgets);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsWidgets);
    expect(find.byIcon(Icons.folder_zip_outlined), findsWidgets);
    expect(find.text('Header Space'), findsOneWidget);

    // Tap on ZIP ChoiceChip
    await tester.tap(find.widgetWithText(ChoiceChip, '.zip'));
    await tester.pumpAndSettle();

    expect(find.byType(ZipArchivePreview), findsOneWidget);
    expect(find.text('Archive Files (2)'), findsOneWidget);
    expect(find.text('embedded_file.txt'), findsWidgets);
    expect(find.text('assets/image.png'), findsWidgets);

    // Tap on Header Space ChoiceChip
    await tester.tap(find.widgetWithText(ChoiceChip, 'Header Space'));
    await tester.pumpAndSettle();

    expect(find.text('Dead Space Header Data (Byte 22 .. 240)'), findsOneWidget);
    expect(find.text('Test Polyglot'), findsOneWidget);
  });

  testWidgets('Inspector view renders all format tabs cleanly on narrow 320px screen', (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 1;
    controller.inspectionResult.value = PolyglotInspectionResult(
      fileName: 'test.mp4',
      fileSize: 102400,
      headerBytes: Uint8List(288),
      extraHeaderString: 'Sample Header Data',
      hasIcoHeader: true,
      hasSecondaryFtyp: true,
      hasHtmlWrapper: true,
      hasPdfStream: true,
      hasZipEocd: true,
      pngOffset: 288,
      pdfOffset: 500,
      zipOffset: 800,
      appendableOffset: 1200,
      appendableSize: 256,
      appendableBytes: Uint8List(256),
      appendablePreviewText: 'RAW_PAYLOAD_TEST',
      detectedFormats: ['.ico', '.png', '.mp4', '.pdf', '.zip', '.html', '.bin'],
      zipEntries: const [ZipEntryInfo(name: 'file.txt', size: 100, compressedSize: 50)],
      extractedHtmlContent: '<html><body>Hello</body></html>',
      pdfVersion: '1.4',
      pdfPageCount: 1,
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pumpAndSettle();

    // Verify .mp4 active
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '.mp4'));
    await tester.tap(find.widgetWithText(ChoiceChip, '.mp4'));
    await tester.pumpAndSettle();
    expect(find.text('Interactive Video Player'), findsOneWidget);

    // Toggle Atom Hex Dump
    await tester.ensureVisible(find.text('View Atom Hex'));
    await tester.tap(find.text('View Atom Hex'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Hide Atom Hex'), findsOneWidget);

    // Verify Header Space
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Header Space'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Header Space'));
    await tester.pumpAndSettle();
    expect(find.text('Dead Space Header Data (Byte 22 .. 240)'), findsOneWidget);

    // Verify Payload tab
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Payload (.bin)'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Payload (.bin)'));
    await tester.pumpAndSettle();
    expect(find.text('Extract to Disk'), findsOneWidget);
  });

  testWidgets('Long filename in appendable binaries renders without overflow', (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 0;
    controller.appendableFiles.add(
      const AppFile(name: 'super_extremely_long_appendable_payload_binary_filename_that_would_otherwise_overflow_the_card.bin'),
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pumpAndSettle();

    expect(find.text('Appendable Binaries'), findsWidgets);
    expect(
      find.text('super_extremely_long_appendable_payload_binary_filename_that_would_otherwise_overflow_the_card.bin'),
      findsOneWidget,
    );
  });

  test('AppFile drag and drop routes files to correct categories', () {
    final controller = PolyglotController();

    controller.assignFilesToStudio([
      const AppFile(name: 'test_image.png'),
      const AppFile(name: 'test_video.mp4'),
      const AppFile(name: 'document.pdf'),
      const AppFile(name: 'page.html'),
      const AppFile(name: 'archive.zip'),
      const AppFile(name: 'payload.bin'),
    ]);

    expect(controller.imageFile.value?.name, 'test_image.png');
    expect(controller.mediaFile.value?.name, 'test_video.mp4');
    expect(controller.isVideo.value, true);
    expect(controller.pdfFile.value?.name, 'document.pdf');
    expect(controller.htmlFile.value?.name, 'page.html');
    expect(controller.zipFiles.length, 1);
    expect(controller.zipFiles.first.name, 'archive.zip');
    expect(controller.appendableFiles.length, 1);
    expect(controller.appendableFiles.first.name, 'payload.bin');
  });

  testWidgets('PolyglotDetectedDialog displays detected formats and navigation actions',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockInspection = PolyglotInspectionResult(
      fileName: 'secret_bundle.ico.mp4',
      fileSize: 40960,
      headerBytes: Uint8List(288),
      extraHeaderString: '',
      hasIcoHeader: true,
      hasSecondaryFtyp: true,
      hasHtmlWrapper: false,
      hasPdfStream: false,
      hasZipEocd: false,
      detectedFormats: ['.ico', '.png', '.mp4'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PolyglotDetectedDialog(
            fileName: 'secret_bundle.ico.mp4',
            fileSize: 40960,
            inspection: mockInspection,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Polyglot Binary Detected'), findsOneWidget);
    expect(find.text('Detected Format Layers'), findsOneWidget);
    expect(find.text('Use in Studio'), findsOneWidget);
    expect(find.text('Inspect Polyglot'), findsOneWidget);
  });

  test('AppScrollBehavior enables mouse click-to-drag scrolling globally', () {
    const scrollBehavior = AppScrollBehavior();
    expect(scrollBehavior.dragDevices.contains(PointerDeviceKind.mouse), true);
    expect(scrollBehavior.dragDevices.contains(PointerDeviceKind.touch), true);
    expect(scrollBehavior.dragDevices.contains(PointerDeviceKind.trackpad), true);
  });

  testWidgets('Tapping image preview opens ImagePreviewDialog with zoom controls, pan, and metadata',
      (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final testImg = img.Image(width: 64, height: 64);
    img.fill(testImg, color: img.ColorRgba8(0, 128, 255, 255));
    final validPngBytes = Uint8List.fromList(img.encodePng(testImg));

    controller.selectedViewMode.value = 1;
    controller.inspectionResult.value = PolyglotInspectionResult(
      fileName: 'app_bundle.ico.mp4',
      fileSize: 51200,
      headerBytes: Uint8List(288),
      extraHeaderString: '',
      hasIcoHeader: true,
      hasSecondaryFtyp: true,
      hasHtmlWrapper: false,
      hasPdfStream: false,
      hasZipEocd: false,
      pngOffset: 288,
      detectedFormats: ['.ico', '.png', '.mp4'],
      extractedImageBytes: validPngBytes,
      imageInfo: const ImageMetadataInfo(
        width: 64,
        height: 64,
        format: 'PNG',
        colorDepth: 32,
        numChannels: 4,
        hasAlpha: true,
        byteOffset: 288,
        byteSize: 51200,
      ),
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pumpAndSettle();

    // Verify Image preview is rendered
    expect(find.text('Decoded Image Stream Viewer'), findsOneWidget);
    expect(find.text('Tap / Click to expand & zoom'), findsOneWidget);
    expect(find.text('Expand & Zoom'), findsOneWidget);
    expect(find.text('Resolution: 64 × 64 px'), findsOneWidget);

    // Tap Expand & Zoom button
    await tester.tap(find.text('Expand & Zoom'));
    await tester.pumpAndSettle();

    // Verify ImagePreviewDialog is open
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('app_bundle.ico.mp4'), findsWidgets);
    expect(find.text('100%'), findsWidgets);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.fit_screen_outlined), findsOneWidget);

    // Tap Zoom In button
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Verify scale increased
    expect(find.text('133%'), findsWidgets);

    // Tap Reset to 1:1
    await tester.tap(find.byIcon(Icons.fit_screen_outlined));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);

    // Tap Close button
    await tester.tap(find.byTooltip('Close (Esc)'));
    await tester.pumpAndSettle();

    // Verify Dialog is closed
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Audio format in inspector displays AudioPlayerPreview with visualizer and playback controls',
      (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 1;
    controller.inspectionResult.value = PolyglotInspectionResult(
      fileName: 'music_track.m4a',
      fileSize: 32000,
      headerBytes: Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70]),
      extraHeaderString: '',
      hasIcoHeader: false,
      hasSecondaryFtyp: false,
      hasHtmlWrapper: false,
      hasPdfStream: false,
      hasZipEocd: false,
      detectedFormats: ['.m4a'],
      rawBytes: Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70]),
      mediaInfo: const MediaMetadataInfo(
        audioCodec: 'AAC Audio (M4A)',
        isVideo: false,
      ),
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Verify Audio Player Preview is rendered
    expect(find.byType(AudioPlayerPreview), findsOneWidget);
    expect(find.text('Interactive Audio Player'), findsOneWidget);
    expect(find.text('.M4A'), findsOneWidget);
    expect(find.text('Export Audio'), findsOneWidget);
    expect(find.text('Codec: AAC Audio (M4A)', findRichText: true), findsOneWidget);
  });

  testWidgets('HTML format in inspector displays HtmlDocumentPreview with DOM overview and tabs', (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 1;
    controller.inspectionResult.value = PolyglotInspectionResult(
      fileName: 'interactive.html',
      fileSize: 4500,
      headerBytes: Uint8List.fromList([0x3C, 0x21, 0x44, 0x4F, 0x43, 0x54, 0x59, 0x50]),
      extraHeaderString: '',
      hasIcoHeader: false,
      hasSecondaryFtyp: false,
      hasHtmlWrapper: true,
      hasPdfStream: false,
      hasZipEocd: false,
      detectedFormats: ['.html'],
      extractedHtmlContent:
          '<!DOCTYPE html><html><head><title>Test App</title><style>body{color:red}</style><script>console.log(1)</script></head><body><h1>Hello</h1></body></html>',
      htmlInfo: const HtmlMetadataInfo(
        title: 'Test App',
        hasCss: true,
        hasJavaScript: true,
        scriptCount: 1,
        styleCount: 1,
        lineCount: 1,
        characterCount: 140,
      ),
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pumpAndSettle();

    // Verify HTML Document Preview is rendered
    expect(find.byType(HtmlDocumentPreview), findsOneWidget);
    expect(find.text('Test App'), findsWidgets);
    expect(find.text('Open in Browser'), findsOneWidget);
    expect(find.text('Code Source & Web'), findsOneWidget);
    expect(find.text('Overview & DOM'), findsOneWidget);
    expect(find.text('JavaScript (1)'), findsOneWidget);
    expect(find.text('CSS & Styles (1)'), findsOneWidget);
    expect(find.text('CSS3 Engine Active'), findsOneWidget);

    // Switch to Overview tab
    await tester.tap(find.text('Overview & DOM'));
    await tester.pumpAndSettle();
    expect(find.text('Document Element Statistics'), findsOneWidget);
  });

  testWidgets('PDF format in inspector displays PdfDocumentPreview with navigation and tabs', (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 1; // Inspector tab

    const samplePdfString =
        '%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page >>\nendobj\n%%EOF';
    final samplePdfBytes = Uint8List.fromList(samplePdfString.codeUnits);

    controller.inspectionResult.value = PolyglotInspectionResult(
      fileName: 'document.pdf',
      fileSize: samplePdfBytes.length,
      headerBytes: samplePdfBytes,
      extraHeaderString: '',
      hasIcoHeader: false,
      hasSecondaryFtyp: false,
      hasHtmlWrapper: false,
      hasPdfStream: true,
      hasZipEocd: false,
      detectedFormats: ['.pdf'],
      extractedPdfBytes: samplePdfBytes,
      pdfVersion: '1.4',
      pdfPageCount: 1,
      pdfInfo: const PdfMetadataInfo(
        version: '1.4',
        pageCount: 1,
        title: 'Secret Document',
        author: 'Polyglot Agent',
        objectCount: 3,
        byteSize: 128,
      ),
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify PDF Document Preview is rendered
    expect(find.byType(PdfDocumentPreview), findsOneWidget);
    expect(find.text('Secret Document'), findsWidgets);
    expect(find.text('Open in Viewer'), findsOneWidget);
    expect(find.text('Document Pages'), findsOneWidget);
    expect(find.text('Overview & Specs'), findsOneWidget);
    expect(find.text('Object Streams (3)'), findsOneWidget);

    // Switch to Overview tab
    await tester.tap(find.text('Overview & Specs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PDF Document Specifications'), findsOneWidget);
    expect(find.text('Polyglot Agent'), findsOneWidget);

    // Switch to Object Streams tab
    await tester.tap(find.text('Object Streams (3)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PDF Object Architecture & XREF Table'), findsOneWidget);
  });

  testWidgets('ZIP format in inspector displays ZipArchivePreview with explorer, search, and audit tabs',
      (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 1; // Inspector tab

    controller.inspectionResult.value = PolyglotInspectionResult(
      fileName: 'bundle.zip',
      fileSize: 2048,
      headerBytes: Uint8List(288),
      extraHeaderString: '',
      hasIcoHeader: false,
      hasSecondaryFtyp: false,
      hasHtmlWrapper: false,
      hasPdfStream: false,
      hasZipEocd: true,
      zipOffset: 512,
      detectedFormats: ['.zip'],
      zipEntries: const [
        ZipEntryInfo(
          name: 'notes.txt',
          size: 1024,
          compressedSize: 450,
          crc32: 0x12345678,
          compressionMethod: 'Deflated',
        ),
        ZipEntryInfo(
          name: 'data.json',
          size: 2048,
          compressedSize: 800,
          crc32: 0x87654321,
          compressionMethod: 'Deflated',
        ),
        ZipEntryInfo(
          name: 'assets/',
          size: 0,
          compressedSize: 0,
          isDirectory: true,
        ),
      ],
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pumpAndSettle();

    // Verify ZipArchivePreview is rendered
    expect(find.byType(ZipArchivePreview), findsOneWidget);
    expect(find.text('bundle.zip'), findsWidgets);
    expect(find.text('Extract All'), findsOneWidget);
    expect(find.text('Archive Files (3)'), findsOneWidget);
    expect(find.text('Overview & Stats'), findsOneWidget);
    expect(find.text('Central Directory Audit'), findsOneWidget);
    expect(find.text('notes.txt'), findsWidgets);

    // Switch to Overview tab
    await tester.tap(find.text('Overview & Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Archive Summary & Storage Metrics'), findsOneWidget);
    expect(find.text('Contained File Types Breakdown'), findsOneWidget);

    // Switch to Central Directory Audit tab
    await tester.tap(find.text('Central Directory Audit'));
    await tester.pumpAndSettle();
    expect(find.text('ZIP Central Directory & Local Headers Audit'), findsOneWidget);
  });

  testWidgets('ZIP entry with PDF invokes PdfDocumentPreview engine inside preview drawer',
      (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 1; // Inspector tab

    const samplePdfString =
        '%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page >>\nendobj\n%%EOF';
    final samplePdfBytes = Uint8List.fromList(samplePdfString.codeUnits);

    controller.inspectionResult.value = PolyglotInspectionResult(
      fileName: 'archive.zip',
      fileSize: 4096,
      headerBytes: Uint8List(288),
      extraHeaderString: '',
      hasIcoHeader: false,
      hasSecondaryFtyp: false,
      hasHtmlWrapper: false,
      hasPdfStream: false,
      hasZipEocd: true,
      detectedFormats: ['.zip'],
      extractedZipBytes: samplePdfBytes,
      zipEntries: const [
        ZipEntryInfo(
          name: 'report.pdf',
          size: 150,
          compressedSize: 100,
          crc32: 0x99887766,
          compressionMethod: 'Deflated',
        ),
      ],
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ZipArchivePreview), findsOneWidget);
    expect(find.text('report.pdf'), findsWidgets);
  });

  testWidgets('ZIP entry with HTML renders in-app with CSS styles', (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 1; // Inspector tab

    const sampleHtmlString = '<html><head><style>body{background:#112233;color:#ffffff;}</style></head><body><h1>Hello ZIP HTML</h1></body></html>';
    final sampleHtmlBytes = Uint8List.fromList(sampleHtmlString.codeUnits);

    controller.inspectionResult.value = PolyglotInspectionResult(
      fileName: 'web_bundle.zip',
      fileSize: 4096,
      headerBytes: Uint8List(288),
      extraHeaderString: '',
      hasIcoHeader: false,
      hasSecondaryFtyp: false,
      hasHtmlWrapper: false,
      hasPdfStream: false,
      hasZipEocd: true,
      detectedFormats: ['.zip'],
      extractedZipBytes: sampleHtmlBytes,
      zipEntries: const [
        ZipEntryInfo(
          name: 'index.html',
          size: 150,
          compressedSize: 100,
          crc32: 0x12345678,
          compressionMethod: 'Deflated',
        ),
      ],
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ZipArchivePreview), findsOneWidget);
    expect(find.text('index.html'), findsWidgets);
  });

  testWidgets('UniversalFilePreview renders modularly for standalone text and HTML payloads', (WidgetTester tester) async {
    final textBytes = Uint8List.fromList('Hello Modular Polyglot'.codeUnits);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UniversalFilePreview(
            bytes: textBytes,
            fileName: 'notes.txt',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello Modular Polyglot'), findsOneWidget);
    expect(find.byType(UniversalFilePreview), findsOneWidget);
  });

  testWidgets('UniversalFilePreview.show dialog opens responsive modal preview', (WidgetTester tester) async {
    final textBytes = Uint8List.fromList('Modal Content Inside Preview'.codeUnits);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => UniversalFilePreview.show(
                context,
                bytes: textBytes,
                fileName: 'preview.txt',
              ),
              child: const Text('Launch Preview'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch Preview'));
    await tester.pumpAndSettle();

    expect(find.text('preview.txt'), findsOneWidget);
    expect(find.text('Modal Content Inside Preview'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('Dynamic version badge renders in AppBar as a static badge', (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.appVersion.value = '1.0.0';
    controller.appBuildNumber.value = '1';

    await tester.pumpWidget(const PolyglotApp());
    await tester.pumpAndSettle();

    expect(find.text('v1.0.0'), findsOneWidget);

    // Tapping version does not open dialog
    await tester.tap(find.text('v1.0.0'));
    await tester.pumpAndSettle();

    expect(find.text('Cross-Platform Media Polyglot Suite'), findsNothing);
  });

  testWidgets('GithubLinkButton renders in AppBar and opens AboutAppDialog on tap', (WidgetTester tester) async {
    Get.put(PolyglotController());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const PolyglotApp());
    await tester.pumpAndSettle();

    // Verify compact GitHub link button in AppBar
    expect(find.text('H4zh4n'), findsOneWidget);

    // Tapping GitHub button in AppBar opens AboutAppDialog
    await tester.tap(find.text('H4zh4n'));
    await tester.pumpAndSettle();

    // Inside About dialog, full GithubLinkButton is visible
    expect(find.text('Created by H4zh4n'), findsOneWidget);
    expect(find.text('github.com/H4zh4n'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('Mobile bottom navigation bar switches seamlessly between Studio and Inspector', (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 0;
    await tester.pumpWidget(const PolyglotApp());
    await tester.pumpAndSettle();

    // Studio is active initially
    expect(find.text('1. Required Base Media'), findsOneWidget);

    // Tap bottom navigation Inspector item
    await tester.tap(find.text('Inspector'));
    await tester.pumpAndSettle();

    expect(controller.selectedViewMode.value, 1);
    expect(find.text('Polyglot Inspector & Viewer'), findsOneWidget);

    // Tap bottom navigation Studio item
    await tester.tap(find.text('Studio'));
    await tester.pumpAndSettle();

    expect(controller.selectedViewMode.value, 0);
    expect(find.text('1. Required Base Media'), findsOneWidget);
  });

  testWidgets('PDF preview supports fullscreen modal dialog expansion on mobile', (WidgetTester tester) async {
    final controller = Get.put(PolyglotController());
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    controller.selectedViewMode.value = 1; // Inspector tab

    const samplePdfString =
        '%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page >>\nendobj\n%%EOF';
    final samplePdfBytes = Uint8List.fromList(samplePdfString.codeUnits);

    controller.inspectionResult.value = PolyglotInspectionResult(
      fileName: 'mobile_doc.pdf',
      fileSize: samplePdfBytes.length,
      headerBytes: samplePdfBytes,
      extraHeaderString: '',
      hasIcoHeader: false,
      hasSecondaryFtyp: false,
      hasHtmlWrapper: false,
      hasPdfStream: true,
      hasZipEocd: false,
      detectedFormats: ['.pdf'],
      extractedPdfBytes: samplePdfBytes,
      pdfVersion: '1.4',
      pdfPageCount: 1,
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PdfDocumentPreview), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen_rounded), findsWidgets);

    // Tap fullscreen button to open PdfFullscreenPreviewDialog
    await tester.tap(find.byTooltip('Fullscreen / Expand PDF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PdfFullscreenPreviewDialog), findsOneWidget);
    expect(find.text('mobile_doc.pdf'), findsWidgets);

    // Close fullscreen dialog
    await tester.tap(find.byTooltip('Close Fullscreen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PdfFullscreenPreviewDialog), findsNothing);
  });

  testWidgets('PDF preview supports InteractiveViewer and double-tap zoom', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final controller = Get.put(PolyglotController());
    controller.selectedViewMode.value = 1;

    final samplePdfBytes = Uint8List.fromList(
      '%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R >>\nendobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n164\n%%EOF\n'.codeUnits,
    );

    controller.inspectionResult.value = PolyglotInspectionResult(
      fileName: 'interactive_doc.pdf',
      fileSize: samplePdfBytes.length,
      headerBytes: samplePdfBytes,
      extraHeaderString: '',
      hasIcoHeader: false,
      hasSecondaryFtyp: false,
      hasHtmlWrapper: false,
      hasPdfStream: true,
      hasZipEocd: false,
      detectedFormats: ['.pdf'],
      extractedPdfBytes: samplePdfBytes,
      pdfVersion: '1.4',
      pdfPageCount: 1,
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PdfDocumentPreview), findsOneWidget);
    expect(find.text('PDF Document Stream'), findsWidgets);
    expect(find.byTooltip('Fullscreen / Expand PDF'), findsWidgets);
  });

  testWidgets('VideoPlayerPreview renders cleanly on narrow mobile screen without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final sampleMp4Bytes = Uint8List.fromList([
      0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D,
      0x00, 0x00, 0x02, 0x00, 0x69, 0x73, 0x6F, 0x6D, 0x6D, 0x70, 0x34, 0x32,
      0x00, 0x00, 0x00, 0x08, 0x66, 0x72, 0x65, 0x65,
      0x00, 0x00, 0x00, 0x10, 0x6D, 0x64, 0x61, 0x74,
      0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: VideoPlayerPreview(
              videoBytes: sampleMp4Bytes,
              fileName: 'portrait_sample.mp4',
              format: '.mp4',
              mediaInfo: const MediaMetadataInfo(
                videoCodec: 'H.264 / AVC1',
                audioCodec: 'AAC Stereo',
                atomBoxes: ['ftyp', 'free', 'mdat'],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(VideoPlayerPreview), findsOneWidget);
    expect(find.text('Interactive Video Player'), findsOneWidget);
    expect(find.text('.MP4'), findsOneWidget);
  });

  testWidgets('ZipArchivePreview with PDF and MP4 entries renders cleanly on mobile screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final zipData = Uint8List(100);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZipArchivePreview(
              zipBytes: zipData,
              fileName: 'archive.zip',
              entries: const [
                ZipEntryInfo(name: 'video_clip.mp4', size: 24, compressedSize: 24, compressionMethod: 'Deflate'),
                ZipEntryInfo(name: 'document.pdf', size: 9, compressedSize: 9, compressionMethod: 'Deflate'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ZipArchivePreview), findsOneWidget);
    expect(find.text('video_clip.mp4'), findsWidgets);
    expect(find.text('document.pdf'), findsWidgets);
  });

  testWidgets('UniversalFilePreview renders image immediately in port with interactive viewer and enlarge badge',
      (WidgetTester tester) async {
    final image = img.Image(width: 50, height: 50);
    img.fill(image, color: img.ColorRgba8(255, 0, 0, 255));
    final pngBytes = Uint8List.fromList(img.encodePng(image));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: UniversalFilePreview(
              bytes: pngBytes,
              fileName: 'photo.png',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(UniversalFilePreview), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Click to Enlarge'), findsOneWidget);
  });
}


