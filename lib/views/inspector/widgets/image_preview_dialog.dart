import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:polyglot_core/polyglot_core.dart';
import '../../../controllers/polyglot_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/notify.dart';
import '../../../utils/number_utils.dart';

/// Fullscreen interactive image viewer with pan, zoom, transparency checkerboard, and metadata.
class ImagePreviewDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;
  final ImageMetadataInfo imageInfo;
  final VoidCallback? onExport;

  const ImagePreviewDialog({
    super.key,
    required this.imageBytes,
    required this.fileName,
    this.imageInfo = const ImageMetadataInfo(),
    this.onExport,
  });

  static Future<void> show(
    BuildContext context, {
    required Uint8List imageBytes,
    required String fileName,
    ImageMetadataInfo imageInfo = const ImageMetadataInfo(),
    VoidCallback? onExport,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xCC080A0E),
      builder: (context) => ImagePreviewDialog(
        imageBytes: imageBytes,
        fileName: fileName,
        imageInfo: imageInfo,
        onExport: onExport,
      ),
    );
  }

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  double _currentScale = 1.0;
  bool _showDetails = true;

  static const double _minScale = 0.1;
  static const double _maxScale = 16.0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _zoomBy(double factor) {
    final newScale = (_currentScale * factor).clamp(_minScale, _maxScale);
    final matrix = Matrix4.diagonal3Values(newScale, newScale, 1.0);
    _transformationController.value = matrix;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _zoom100Percent() {
    _transformationController.value = Matrix4.identity();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    if (_currentScale > 1.2) {
      // Reset to 1.0
      _resetZoom();
    } else {
      // Zoom into tapped point
      final position = details.localPosition;
      const targetScale = 2.5;
      final x = -position.dx * (targetScale - 1);
      final y = -position.dy * (targetScale - 1);
      final matrix = Matrix4.translationValues(x, y, 0.0)..scaleByDouble(targetScale, targetScale, 1.0, 1.0);
      _transformationController.value = matrix;
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final double dy = event.scrollDelta.dy;
      if (dy == 0) return;
      final factor = dy < 0 ? 1.15 : 0.85;
      _zoomBy(factor);
    }
  }

  void _copyImageInfoToClipboard(BuildContext context) {
    final info = widget.imageInfo;
    final buffer = StringBuffer();
    buffer.writeln('File: ${widget.fileName}');
    if (info.format != null) buffer.writeln('Format: ${info.format}');
    if (info.width != null && info.height != null) buffer.writeln('Dimensions: ${info.width} x ${info.height} px');
    if (info.aspectRatioString.isNotEmpty) buffer.writeln('Aspect Ratio: ${info.aspectRatioString}');
    if (info.colorDepth != null) buffer.writeln('Color Depth: ${info.colorDepth}bpp');
    buffer.writeln('Raw Size: ${NumberUtils.formatBytesExact(widget.imageBytes.length)}');
    if (info.byteOffset != null) buffer.writeln('Stream Offset: Byte ${NumberUtils.formatInt(info.byteOffset!)}');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    Notify.success(
      'Metadata Copied',
      description: 'Image properties copied to clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.imageInfo;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.equal || event.logicalKey == LogicalKeyboardKey.numpadAdd) {
            _zoomBy(1.25);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.minus || event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
            _zoomBy(0.8);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit0 || event.logicalKey == LogicalKeyboardKey.numpad0) {
            _resetZoom();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        insetPadding: isMobile ? const EdgeInsets.all(8) : const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 900),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1216),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 36,
                spreadRadius: 4,
                offset: Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Bar
              _buildTopBar(context, isMobile),

              // 2. Main Interactive Image Canvas
              Expanded(
                child: Stack(
                  children: [
                    // Interactive Canvas with Checkerboard Background
                    Positioned.fill(
                      child: Listener(
                        onPointerSignal: _handlePointerSignal,
                        child: GestureDetector(
                          onDoubleTapDown: _handleDoubleTapDown,
                          onDoubleTap: () {},
                          child: ClipRect(
                            child: CustomPaint(
                              painter: const _CheckerboardPainter(),
                              child: InteractiveViewer(
                                transformationController: _transformationController,
                                minScale: _minScale,
                                maxScale: _maxScale,
                                boundaryMargin: const EdgeInsets.all(double.infinity),
                                child: Center(
                                  child: Image.memory(
                                    widget.imageBytes,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceElevated,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.broken_image_outlined, size: 36, color: Color(0xFFF87171)),
                                          SizedBox(height: 10),
                                          Text('Failed to render decoded image stream', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                        ],
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

                    // Floating Zoom Controls (Bottom Right)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: _buildZoomToolbar(),
                    ),

                    // Quick Toggle for Specs Drawer (Bottom Left)
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: _buildDetailsTogglePill(),
                    ),
                  ],
                ),
              ),

              // 3. Bottom Metadata Specs Panel (Collapsible)
              if (_showDetails) _buildMetadataPanel(info, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isMobile) {
    final info = widget.imageInfo;
    final controller = Get.isRegistered<PolyglotController>() ? Get.find<PolyglotController>() : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: const Icon(Icons.image_outlined, size: 16, color: AppTheme.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.fileName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontFamily: 'monospace',
                          letterSpacing: AppTheme.trackingTight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Text(
                        info.format ?? 'PNG',
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.accent),
                      ),
                    ),
                  ],
                ),
                if (!isMobile && info.width != null && info.height != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${info.width} × ${info.height} px • ${NumberUtils.formatBytesExact(widget.imageBytes.length)}${info.colorDepth != null ? ' • ${info.colorDepth}bpp' : ''}',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontFamily: 'monospace'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Actions
          if (widget.onExport != null || controller != null) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: const Color(0xFF0D0F12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                if (widget.onExport != null) {
                  widget.onExport!();
                } else if (controller != null) {
                  controller.extractImageFile();
                }
              },
              icon: const Icon(Icons.download_outlined, size: 14),
              label: Text(isMobile ? 'Save' : 'Export Image', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
          ],

          IconButton(
            tooltip: 'Copy Info',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_outlined, size: 15, color: AppTheme.textSecondary),
            onPressed: () => _copyImageInfoToClipboard(context),
          ),
          const SizedBox(width: 2),

          IconButton(
            tooltip: 'Close (Esc)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18, color: AppTheme.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomToolbar() {
    final scalePercent = (_currentScale * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xEE161A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom Out (-)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 15, color: AppTheme.textPrimary),
            onPressed: () => _zoomBy(0.75),
          ),
          InkWell(
            onTap: _zoom100Percent,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                '$scalePercent%',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Zoom In (+)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 15, color: AppTheme.textPrimary),
            onPressed: () => _zoomBy(1.33),
          ),
          Container(
            height: 14,
            width: 1,
            color: AppTheme.borderSubtle,
            margin: const EdgeInsets.symmetric(horizontal: 2),
          ),
          IconButton(
            tooltip: 'Fit to View (1:1)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.fit_screen_outlined, size: 15, color: AppTheme.textSecondary),
            onPressed: _resetZoom,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTogglePill() {
    return InkWell(
      onTap: () => setState(() => _showDetails = !_showDetails),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xEE161A22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showDetails ? Icons.info : Icons.info_outline,
              size: 13,
              color: _showDetails ? AppTheme.accent : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _showDetails ? 'Hide Specs' : 'Image Specs',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataPanel(ImageMetadataInfo info, bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.borderSubtle),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (info.width != null && info.height != null)
            _buildSpecBadge(
              label: 'Resolution',
              value: '${info.width} × ${info.height} px',
              icon: Icons.aspect_ratio,
            ),
          if (info.aspectRatioString.isNotEmpty)
            _buildSpecBadge(
              label: 'Aspect Ratio',
              value: info.aspectRatioString,
              icon: Icons.crop_free,
            ),
          if (info.colorDepth != null)
            _buildSpecBadge(
              label: 'Color Depth',
              value: '${info.colorDepth}bpp${info.hasAlpha ? ' (Alpha)' : ''}',
              icon: Icons.palette_outlined,
            ),
          _buildSpecBadge(
            label: 'Stream Size',
            value: NumberUtils.formatBytesExact(widget.imageBytes.length),
            icon: Icons.data_usage_outlined,
          ),
          if (info.byteOffset != null)
            _buildSpecBadge(
              label: 'Container Offset',
              value: 'Byte ${NumberUtils.formatInt(info.byteOffset!)}',
              icon: Icons.location_searching_outlined,
            ),
          _buildSpecBadge(
            label: 'Zoom Factor',
            value: '${(_currentScale * 100).round()}%',
            icon: Icons.zoom_in,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecBadge({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that renders a dark checkerboard grid for inspecting transparency.
class _CheckerboardPainter extends CustomPainter {
  static const double squareSize = 16.0;
  static const Color color1 = Color(0xFF14171D);
  static const Color color2 = Color(0xFF0D0F13);

  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    final cols = (size.width / squareSize).ceil();
    final rows = (size.height / squareSize).ceil();

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final paint = (r + c) % 2 == 0 ? paint1 : paint2;
        final rect = Rect.fromLTWH(
          c * squareSize,
          r * squareSize,
          math.min(squareSize, size.width - c * squareSize),
          math.min(squareSize, size.height - r * squareSize),
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) => false;
}
