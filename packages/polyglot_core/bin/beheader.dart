// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:polyglot_core/polyglot_core.dart';

void printUsage(ArgParser parser) {
  print('''
Usage: beheader <output> <image> <video|audio> [-options] [appendable...]

Cross-platform Polyglot Generator for media files (Desktop, Mobile & CLI).

Arguments:
    output               Path of resulting polyglot file
    image                Path of input image file (PNG/JPG/WEBP/etc.)
    video|audio          Path of input video or audio file (MP4/M4A/etc.)
    appendable           Path(s) of files to append without parsing

Options:
${parser.usage}
''');
}

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('html', abbr: 'h', help: 'Path to HTML document')
    ..addOption('pdf', abbr: 'p', help: 'Path to PDF document')
    ..addMultiOption('zip', abbr: 'z', help: 'Path to ZIP-like archive (repeatable)')
    ..addOption('extra', abbr: 'e', help: 'Path to short (<200b) file to include near the header')
    ..addFlag('help', negatable: false, help: 'Print this help message and exit');

  ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    print('Error: $e\n');
    printUsage(parser);
    exit(1);
  }

  if (results['help'] == true || results.rest.length < 3) {
    printUsage(parser);
    exit(results['help'] == true ? 0 : 1);
  }

  final outputPath = results.rest[0];
  final imagePath = results.rest[1];
  final videoPath = results.rest[2];
  final appendablePaths = results.rest.skip(3).toList();

  final imageFile = File(imagePath);
  if (!await imageFile.exists()) {
    print('Error: Image file not found at "$imagePath"');
    exit(1);
  }

  final videoFile = File(videoPath);
  if (!await videoFile.exists()) {
    print('Error: Video/Audio file not found at "$videoPath"');
    exit(1);
  }

  print('Reading input files...');
  final imageBytes = await imageFile.readAsBytes();
  final videoBytes = await videoFile.readAsBytes();

  String? htmlContent;
  if (results['html'] != null) {
    final htmlFile = File(results['html']);
    if (await htmlFile.exists()) {
      htmlContent = await htmlFile.readAsString();
    } else {
      print('Warning: HTML file not found at "${results['html']}". Skipping.');
    }
  }

  Uint8List? pdfBytes;
  if (results['pdf'] != null) {
    final pdfFile = File(results['pdf']);
    if (await pdfFile.exists()) {
      pdfBytes = await pdfFile.readAsBytes();
    } else {
      print('Warning: PDF file not found at "${results['pdf']}". Skipping.');
    }
  }

  final zipArchives = <Uint8List>[];
  final zipPaths = results['zip'] as List<String>;
  for (final zipPath in zipPaths) {
    final zipFile = File(zipPath);
    if (await zipFile.exists()) {
      zipArchives.add(await zipFile.readAsBytes());
    } else {
      print('Warning: ZIP file not found at "$zipPath". Skipping.');
    }
  }

  String extraData = '';
  if (results['extra'] != null) {
    final extraFile = File(results['extra']);
    if (await extraFile.exists()) {
      extraData = await extraFile.readAsString();
    }
  }

  final appendables = <Uint8List>[];
  for (final appendPath in appendablePaths) {
    final appendFile = File(appendPath);
    if (await appendFile.exists()) {
      appendables.add(await appendFile.readAsBytes());
    }
  }

  print('Generating polyglot binary...');
  final stopwatch = Stopwatch()..start();

  try {
    final result = await PolyglotGenerator.generate(
      PolyglotInputs(
        imageBytes: imageBytes,
        imageName: imagePath,
        mediaBytes: videoBytes,
        mediaName: videoPath,
        htmlContent: htmlContent,
        pdfBytes: pdfBytes,
        zipArchives: zipArchives,
        extraHeaderData: extraData,
        appendables: appendables,
      ),
    );

    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(result.data);
    stopwatch.stop();

    print('Successfully generated polyglot file!');
    print('  Output: $outputPath');
    print('  Total size: ${(result.totalBytes / 1024).toStringAsFixed(2)} KB');
    print('  PNG offset: byte ${result.pngOffset} (${(result.pngSize / 1024).toStringAsFixed(2)} KB)');
    print('  MP4 size: ${(result.mp4Size / 1024).toStringAsFixed(2)} KB');
    if (result.pdfOffset != null) {
      print('  PDF offset: byte ${result.pdfOffset}');
    }
    if (result.zipOffset != null) {
      print('  ZIP offset: byte ${result.zipOffset}');
    }
    print('  Supported file extensions: ${result.supportedExtensions.join(', ')}');
    print('  Time taken: ${stopwatch.elapsedMilliseconds} ms');
  } catch (e, stack) {
    print('Error generating polyglot: $e');
    print(stack);
    exit(1);
  }
}
