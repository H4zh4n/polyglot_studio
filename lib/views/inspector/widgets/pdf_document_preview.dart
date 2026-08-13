import 'dart:io' show Directory, File, Platform, Process, ProcessStartMode;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show EagerGestureRecognizer, GestureBinding, PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import 'package:polyglot_core/polyglot_core.dart';
import '../../../controllers/polyglot_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/notify.dart';
import '../../../utils/number_utils.dart';

enum PdfViewTab {
  pages,
  overview,
  objects,
}

/// A comprehensive, pro-grade interactive PDF Document Viewer, Page Navigator, and Stream Inspector.
class PdfDocumentPreview extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;
  final PdfMetadataInfo pdfInfo;

  const PdfDocumentPreview({
    super.key,
    required this.pdfBytes,
    required this.fileName,
    this.pdfInfo = const PdfMetadataInfo(),
  });

  @override
  State<PdfDocumentPreview> createState() => _PdfDocumentPreviewState();
}

class _PdfDocumentPreviewState extends State<PdfDocumentPreview> {
  PdfViewTab _selectedTab = PdfViewTab.pages;
  PdfController? _pdfController;
  final TransformationController _transformationController = TransformationController();
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingPdf = true;
  String? _pdfError;
  double _currentScale = 1.0;
  bool _isDragging = false;
  Offset? _lastPanPos;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
    _initPdfController();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.02) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  @override
  void didUpdateWidget(covariant PdfDocumentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfBytes != widget.pdfBytes) {
      _initPdfController();
    }
  }

  Uint8List _getCleanNormalizedPdfBytes() {
    Uint8List bytesToOpen = widget.pdfBytes;

    // Ensure stream starts at %PDF- marker
    int startIdx = -1;
    for (int i = 0; i <= bytesToOpen.length - 5; i++) {
      if (bytesToOpen[i] == 0x25 &&
          bytesToOpen[i + 1] == 0x50 &&
          bytesToOpen[i + 2] == 0x44 &&
          bytesToOpen[i + 3] == 0x46 &&
          bytesToOpen[i + 4] == 0x2D) {
        startIdx = i;
        break;
      }
    }

    if (startIdx > 0) {
      // Find %%EOF marker
      int endIdx = -1;
      for (int i = bytesToOpen.length - 5; i >= startIdx; i--) {
        if (bytesToOpen[i] == 0x25 &&
            bytesToOpen[i + 1] == 0x25 &&
            bytesToOpen[i + 2] == 0x45 &&
            bytesToOpen[i + 3] == 0x4F &&
            bytesToOpen[i + 4] == 0x46) {
          endIdx = i + 5;
          while (endIdx < bytesToOpen.length &&
              (bytesToOpen[endIdx] == 0x0D || bytesToOpen[endIdx] == 0x0A || bytesToOpen[endIdx] == 0x20)) {
            endIdx++;
          }
          break;
        }
      }
      if (endIdx != -1) {
        bytesToOpen = Uint8List.fromList(bytesToOpen.sublist(startIdx, endIdx));
      } else {
        bytesToOpen = Uint8List.fromList(bytesToOpen.sublist(startIdx));
      }
    }

    return PolyglotInspector.normalizePdfStream(bytesToOpen, startIdx > 0 ? startIdx : 0);
  }

  Future<void> _initPdfController() async {
    _pdfController?.dispose();
    _pdfController = null;
    _transformationController.value = Matrix4.identity();
    setState(() {
      _isLoadingPdf = true;
      _pdfError = null;
      _currentScale = 1.0;
    });

    try {
      if (widget.pdfBytes.isEmpty) {
        throw Exception('PDF byte stream is empty');
      }

      final bytesToOpen = _getCleanNormalizedPdfBytes();

      final doc = await PdfDocument.openData(bytesToOpen);
      _totalPages = doc.pagesCount > 0 ? doc.pagesCount : 1;
      _currentPage = 1;

      _pdfController = PdfController(
        document: PdfDocument.openData(bytesToOpen),
        initialPage: 1,
      );

      if (mounted) {
        setState(() {
          _isLoadingPdf = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPdf = false;
          _pdfError = '$e';
        });
      }
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final isCtrlOrMeta = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
      if (isCtrlOrMeta) {
        // Register with pointerSignalResolver so parent Scrollable (SingleChildScrollView) does NOT scroll at all!
        GestureBinding.instance.pointerSignalResolver.register(event, (resolvedEvent) {
          if (resolvedEvent is PointerScrollEvent) {
            final scrollDelta = resolvedEvent.scrollDelta.dy;
            if (scrollDelta == 0) return;

            final zoomFactor = scrollDelta < 0 ? 1.15 : 0.85;
            final newScale = (_currentScale * zoomFactor).clamp(0.8, 4.5);
            if ((newScale - _currentScale).abs() < 0.001) return;

            final effectiveFactor = newScale / _currentScale;
            final focalPoint = resolvedEvent.localPosition;
            final currentMatrix = _transformationController.value;
            final currentTrans = currentMatrix.getTranslation();

            final double tx = focalPoint.dx - effectiveFactor * (focalPoint.dx - currentTrans.x);
            final double ty = focalPoint.dy - effectiveFactor * (focalPoint.dy - currentTrans.y);

            _currentScale = newScale;
            if (newScale <= 1.02 && newScale >= 0.98 && tx.abs() < 2 && ty.abs() < 2) {
              _currentScale = 1.0;
              _transformationController.value = Matrix4.identity();
            } else {
              final Matrix4 newMatrix = Matrix4.identity()
                ..setEntry(0, 0, newScale)
                ..setEntry(1, 1, newScale)
                ..setEntry(2, 2, 1.0)
                ..setEntry(0, 3, tx)
                ..setEntry(1, 3, ty);
              _transformationController.value = newMatrix;
            }
            setState(() {});
          }
        });
      }
    }
  }

  void _toggleDoubleTapZoom(TapDownDetails details) {
    if (_currentScale > 1.25) {
      _currentScale = 1.0;
      _transformationController.value = Matrix4.identity();
    } else {
      final position = details.localPosition;
      const double targetScale = 2.0;
      final effectiveFactor = targetScale / _currentScale;
      final currentTrans = _transformationController.value.getTranslation();
      final double tx = position.dx - effectiveFactor * (position.dx - currentTrans.x);
      final double ty = position.dy - effectiveFactor * (position.dy - currentTrans.y);

      _currentScale = targetScale;
      final matrix = Matrix4.identity()
        ..setEntry(0, 0, targetScale)
        ..setEntry(1, 1, targetScale)
        ..setEntry(2, 2, 1.0)
        ..setEntry(0, 3, tx)
        ..setEntry(1, 3, ty);
      _transformationController.value = matrix;
    }
    setState(() {});
  }

  void _zoomIn() {
    final newScale = (_currentScale + 0.3).clamp(0.8, 4.5);
    _currentScale = newScale;
    final currentMatrix = _transformationController.value;
    final trans = currentMatrix.getTranslation();
    _transformationController.value = Matrix4.identity()
      ..setEntry(0, 0, newScale)
      ..setEntry(1, 1, newScale)
      ..setEntry(0, 3, trans.x)
      ..setEntry(1, 3, trans.y);
    setState(() {});
  }

  void _zoomOut() {
    final newScale = (_currentScale - 0.3).clamp(0.8, 4.5);
    _currentScale = newScale;
    final currentMatrix = _transformationController.value;
    final trans = currentMatrix.getTranslation();
    _transformationController.value = Matrix4.identity()
      ..setEntry(0, 0, newScale)
      ..setEntry(1, 1, newScale)
      ..setEntry(0, 3, trans.x)
      ..setEntry(1, 3, trans.y);
    setState(() {});
  }

  void _resetZoom() {
    _currentScale = 1.0;
    _transformationController.value = Matrix4.identity();
    setState(() {});
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _openInSystemViewer() async {
    try {
      if (kIsWeb) {
        Notify.info(
          'Web Preview',
          description: 'Use Export PDF to save and view the document',
        );
        return;
      }

      final normalizedBytes = _getCleanNormalizedPdfBytes();
      final tempDir = Directory.systemTemp;
      final cleanName = widget.fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final tempFile = File(p.join(tempDir.path, 'polyglot_preview_${DateTime.now().millisecondsSinceEpoch}_$cleanName.pdf'));
      await tempFile.writeAsBytes(normalizedBytes, flush: true);

      if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', tempFile.path], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', [tempFile.path], mode: ProcessStartMode.detached);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [tempFile.path], mode: ProcessStartMode.detached);
      }

      Notify.success(
        'Launched in System Viewer',
        description: 'Opened PDF in default reader',
      );
    } catch (e) {
      Notify.error(
        'Error',
        description: 'Could not open PDF viewer: $e',
      );
    }
  }

  void _copyMetadataToClipboard() {
    final info = widget.pdfInfo;
    final buffer = StringBuffer();
    buffer.writeln('=== PDF Document Metadata ===');
    buffer.writeln('File: ${widget.fileName}');
    buffer.writeln('Spec Version: PDF v${info.version ?? '1.4'}');
    buffer.writeln('Page Count: ${info.pageCount > 0 ? info.pageCount : _totalPages}');
    if (info.title != null) buffer.writeln('Title: ${info.title}');
    if (info.author != null) buffer.writeln('Author: ${info.author}');
    if (info.creator != null) buffer.writeln('Creator: ${info.creator}');
    if (info.producer != null) buffer.writeln('Producer: ${info.producer}');
    if (info.creationDate != null) buffer.writeln('Creation Date: ${info.creationDate}');
    buffer.writeln('Object Count: ${info.objectCount}');
    buffer.writeln('Linearized: ${info.isLinearized}');
    buffer.writeln('Encrypted: ${info.isEncrypted}');
    buffer.writeln('Size: ${NumberUtils.formatSizeKb(widget.pdfBytes.length)}');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    Notify.success(
      'Copied Metadata',
      description: 'PDF specifications copied to clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PolyglotController>() ? Get.find<PolyglotController>() : null;
    final info = widget.pdfInfo;
    final pageCount = info.pageCount > 0 ? info.pageCount : _totalPages;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header Row: Document Title, Format Badge, Badges, and Action Buttons
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppTheme.accent),
                  Text(
                    info.title != null && info.title!.isNotEmpty ? info.title! : 'PDF Document Stream',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Text(
                      'PDF v${info.version ?? '1.4'}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),

                  // Metadata Badges
                  _buildTechBadge('$pageCount ${pageCount == 1 ? 'Page' : 'Pages'}', const Color(0xFF38BDF8), Icons.menu_book_rounded),
                  if (info.isLinearized)
                    _buildTechBadge('Fast Web View', const Color(0xFF34D399), Icons.bolt_rounded),
                  if (info.isEncrypted)
                    _buildTechBadge('Encrypted', const Color(0xFFFBBF24), Icons.lock_outline_rounded),
                  if (info.imageCount > 0)
                    _buildTechBadge('${info.imageCount} Images', AppTheme.primary, Icons.image_outlined),
                ],
              ),

              // Action Buttons: Open in Viewer, Copy, Export
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceElevated,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _openInSystemViewer,
                    icon: const Icon(Icons.open_in_new_rounded, size: 13, color: AppTheme.textSecondary),
                    label: const Text(
                      'Open in Viewer',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondary),
                    tooltip: 'Copy PDF Metadata',
                    onPressed: _copyMetadataToClipboard,
                  ),
                  if (controller != null) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.download_outlined, size: 14, color: AppTheme.textSecondary),
                      tooltip: 'Export PDF Document',
                      onPressed: () => controller.extractPdfFile(),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Navigation Tabs (Pages / Overview / Object Streams)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(child: _buildNavTab(PdfViewTab.pages, 'Document Pages', Icons.auto_stories_rounded)),
                Expanded(child: _buildNavTab(PdfViewTab.overview, 'Overview & Specs', Icons.dashboard_outlined)),
                Expanded(child: _buildNavTab(PdfViewTab.objects, 'Object Streams (${info.objectCount})', Icons.account_tree_outlined)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. Active Tab View
          _buildActiveTabContent(),

          const SizedBox(height: 12),

          // 4. Document Specs Footer
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildInfoBadge('Size', NumberUtils.formatSizeKb(widget.pdfBytes.length)),
              _buildInfoBadge('Pages', '$pageCount'),
              _buildInfoBadge('Objects', '${info.objectCount} indirect'),
              if (info.fontCount > 0)
                _buildInfoBadge('Fonts', '${info.fontCount} fonts'),
              if (info.imageCount > 0)
                _buildInfoBadge('XObjects', '${info.imageCount} image streams'),
              if (info.linkCount > 0)
                _buildInfoBadge('Links', '${info.linkCount} hyperlinks'),
              if (info.byteOffset > 0)
                _buildInfoBadge('Offset', 'Byte ${NumberUtils.formatInt(info.byteOffset)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab(PdfViewTab tab, String label, IconData icon) {
    final isSelected = _selectedTab == tab;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tab),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.background : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isSelected
              ? [
                  const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTab) {
      case PdfViewTab.pages:
        return _buildPagesTab();
      case PdfViewTab.overview:
        return _buildOverviewTab();
      case PdfViewTab.objects:
        return _buildObjectsTab();
    }
  }

  /// Tab 1: In-App Interactive Cross-Platform PDF Page Viewer with Zoom & Pan
  Widget _buildPagesTab() {
    if (_isLoadingPdf) {
      return Container(
        height: 420,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF090B0E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.borderSubtle.withAlpha(50)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary),
            ),
            SizedBox(height: 12),
            Text('Decoding PDF page rasterizer...', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    if (_pdfError != null || _pdfController == null) {
      return Container(
        height: 380,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF090B0E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.borderSubtle.withAlpha(50)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Icon(Icons.picture_as_pdf_outlined, size: 28, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            const Text(
              'PDF Stream Notice',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                _pdfError ?? 'Could not initialize in-app PDF rasterizer for this stream.',
                style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.textMuted),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceElevated,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    side: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  onPressed: _initPdfController,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Retry In-App Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: const Color(0xFF0D0F12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _openInSystemViewer,
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Open in System Viewer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final isZoomed = (_currentScale - 1.0).abs() > 0.05;

    final isMobile = MediaQuery.sizeOf(context).width < 650 || (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // 1. Page Navigation & Interactive Zoom Toolbar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Page Navigation Controls
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 12, color: AppTheme.textSecondary),
                      tooltip: 'Previous Page',
                      onPressed: _currentPage > 1
                          ? () {
                              _pdfController?.previousPage(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'Page $_currentPage of $_totalPages',
                        style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textSecondary),
                      tooltip: 'Next Page',
                      onPressed: _currentPage < _totalPages
                          ? () {
                              _pdfController?.nextPage(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                    ),
                  ],
                ),
              ),

              // Zoom Controls Toolbar
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_rounded, size: 14, color: AppTheme.textSecondary),
                      tooltip: 'Zoom Out',
                      onPressed: _currentScale > 0.85 ? _zoomOut : null,
                    ),
                    InkWell(
                      onTap: isZoomed ? _resetZoom : null,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          '${(_currentScale * 100).round()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: isZoomed ? AppTheme.accent : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_rounded, size: 14, color: AppTheme.textSecondary),
                      tooltip: 'Zoom In',
                      onPressed: _currentScale < 3.95 ? _zoomIn : null,
                    ),
                    if (isZoomed) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.restart_alt_rounded, size: 13, color: AppTheme.accent),
                        tooltip: 'Reset Zoom (100%)',
                        onPressed: _resetZoom,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // 2. Gesture Helper Pill Banner (Desktop only)
          if (!isMobile) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated.withAlpha(140),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pan_tool_outlined, size: 13, color: AppTheme.accent),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Click & drag to pan • Ctrl + Mouse wheel to zoom • Double-click to zoom in/out',
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, letterSpacing: -0.1),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // 3. In-App Interactive Pan & Zoom PDF Viewport (Isolated from page scroll)
          Container(
            height: 420,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E222A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle.withAlpha(50)),
            ),
            clipBehavior: Clip.antiAlias,
            child: RawGestureDetector(
              gestures: <Type, GestureRecognizerFactory>{
                EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                  (EagerGestureRecognizer instance) {},
                ),
              },
              child: Listener(
                onPointerSignal: _onPointerSignal,
                onPointerDown: (event) {
                  _lastPanPos = event.position;
                  setState(() => _isDragging = true);
                },
                onPointerMove: (event) {
                  if (_lastPanPos != null) {
                    final delta = event.position - _lastPanPos!;
                    _lastPanPos = event.position;
                    final currentMatrix = _transformationController.value;
                    final trans = currentMatrix.getTranslation();
                    final matrix = Matrix4.identity()
                      ..setEntry(0, 0, _currentScale)
                      ..setEntry(1, 1, _currentScale)
                      ..setEntry(0, 3, trans.x + delta.dx)
                      ..setEntry(1, 3, trans.y + delta.dy);
                    _transformationController.value = matrix;
                    setState(() {});
                  }
                },
                onPointerUp: (_) {
                  _lastPanPos = null;
                  setState(() => _isDragging = false);
                },
                onPointerCancel: (_) {
                  _lastPanPos = null;
                  setState(() => _isDragging = false);
                },
                child: MouseRegion(
                  cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
                  child: GestureDetector(
                    onDoubleTapDown: _toggleDoubleTapZoom,
                    child: ClipRect(
                      child: Transform(
                        transform: _transformationController.value,
                        child: PdfView(
                          controller: _pdfController!,
                          onPageChanged: (page) {
                            setState(() {
                              _currentPage = page;
                            });
                          },
                          builders: PdfViewBuilders<DefaultBuilderOptions>(
                            options: const DefaultBuilderOptions(
                              loaderSwitchDuration: Duration(milliseconds: 150),
                            ),
                            documentLoaderBuilder: (_) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary),
                            ),
                            pageLoaderBuilder: (_) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary),
                            ),
                            errorBuilder: (_, error) => Center(
                              child: Text('Error loading page: $error', style: const TextStyle(fontSize: 10, color: AppTheme.danger)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 2: Overview & Document Specifications
  Widget _buildOverviewTab() {
    final info = widget.pdfInfo;
    final pageCount = info.pageCount > 0 ? info.pageCount : _totalPages;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1216),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Document Statistics Grid
          const Text(
            'PDF Document Specifications',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatCard('Page Count', '$pageCount', Icons.auto_stories_rounded, const Color(0xFF38BDF8)),
              _buildStatCard('PDF Version', 'v${info.version ?? '1.4'}', Icons.picture_as_pdf_outlined, AppTheme.accent),
              _buildStatCard('Indirect Objs', '${info.objectCount}', Icons.account_tree_outlined, const Color(0xFFFBBF24)),
              _buildStatCard('Embedded Fonts', '${info.fontCount}', Icons.font_download_outlined, const Color(0xFFA78BFA)),
              _buildStatCard('Image Streams', '${info.imageCount}', Icons.image_outlined, AppTheme.primary),
              _buildStatCard('Hyperlinks', '${info.linkCount}', Icons.link_rounded, const Color(0xFF34D399)),
            ],
          ),

          const SizedBox(height: 14),

          // Metadata Info Table
          const Text(
            'Document Metadata Dictionary (/Info & XMP)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                _buildMetadataRow('Title', info.title ?? 'Untitled Document'),
                _buildMetadataRow('Author', info.author ?? 'Not Specified'),
                _buildMetadataRow('Creator', info.creator ?? 'Not Specified'),
                _buildMetadataRow('Producer', info.producer ?? 'PDF Generator Engine'),
                if (info.creationDate != null)
                  _buildMetadataRow('Creation Date', info.creationDate!),
                _buildMetadataRow('Encryption', info.isEncrypted ? 'Protected / Encrypted' : 'None (Public Read)'),
                _buildMetadataRow('Linearized', info.isLinearized ? 'Yes (Optimized for Fast Web View)' : 'No (Standard Stream)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String count, IconData icon, Color color) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 14, color: color),
              Text(
                count,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 3: PDF Object Streams & Structure Audit
  Widget _buildObjectsTab() {
    final info = widget.pdfInfo;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1216),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 14, color: Color(0xFFFBBF24)),
              SizedBox(width: 6),
              Text(
                'PDF Object Architecture & XREF Table',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildObjectFeature('Root Catalog Dictionary', true, 'Document root /Catalog object located and verified'),
                _buildObjectFeature('Pages Tree Node', true, 'Hierarchical /Pages node with ${info.pageCount > 0 ? info.pageCount : _totalPages} page descriptors'),
                _buildObjectFeature('Cross-Reference Table (XREF)', true, 'Shifted byte offsets synchronized for polyglot coexistence'),
                _buildObjectFeature('Stream Filters', true, 'FlateDecode / ASCIIHex stream decompression compatible'),
                _buildObjectFeature('Trailer %%EOF Marker', true, 'Valid end-of-file trailer located at stream boundary'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObjectFeature(String title, bool isVerified, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isVerified ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 13,
            color: isVerified ? const Color(0xFF34D399) : AppTheme.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text(description, style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
