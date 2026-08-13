import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:polyglot/controllers/polyglot_controller.dart';
import 'package:polyglot/main.dart';
import 'package:polyglot/models/app_file.dart';
import 'package:polyglot/views/inspector/widgets/audio_player_preview.dart';
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
    expect(find.text('Beheader Polyglot'), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);
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

    expect(find.text('Archive Explorer (2 entries)'), findsOneWidget);
    expect(find.text('embedded_file.txt'), findsOneWidget);
    expect(find.text('assets/image.png'), findsOneWidget);

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

    controller.handleDroppedFiles([
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
      fileName: 'music_track.mp3',
      fileSize: 32000,
      headerBytes: Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00, 0x00]),
      extraHeaderString: '',
      hasIcoHeader: false,
      hasSecondaryFtyp: false,
      hasHtmlWrapper: false,
      hasPdfStream: false,
      hasZipEocd: false,
      detectedFormats: ['.mp3'],
      rawBytes: Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00]),
      mediaInfo: const MediaMetadataInfo(
        audioCodec: 'MP3 MPEG-1/2 Audio',
        isVideo: false,
      ),
    );

    await tester.pumpWidget(const PolyglotApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Verify Audio Player Preview is rendered
    expect(find.byType(AudioPlayerPreview), findsOneWidget);
    expect(find.text('Interactive Audio Player'), findsOneWidget);
    expect(find.text('.MP3'), findsOneWidget);
    expect(find.text('Export Audio'), findsOneWidget);
    expect(find.text('Codec: MP3 MPEG-1/2 Audio', findRichText: true), findsOneWidget);
  });
}
