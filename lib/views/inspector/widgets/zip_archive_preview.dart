import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, Platform, Process, ProcessStartMode;
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show EagerGestureRecognizer, GestureBinding, PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import 'package:polyglot_core/polyglot_core.dart';
import 'audio_player_preview.dart';
import 'html_document_preview.dart';
import 'image_preview_dialog.dart';
import 'video_player_preview.dart';
import '../../../controllers/polyglot_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/notify.dart';
import '../../../utils/number_utils.dart';

enum ZipViewTab {
  files,
  overview,
  audit,
}

/// Comprehensive, pro-grade interactive ZIP Archive Explorer, In-App Decompression Viewer, and Central Directory Inspector.
class ZipArchivePreview extends StatefulWidget {
  final Uint8List zipBytes;
  final Uint8List? rawBytes;
  final String fileName;
  final int? zipOffset;
  final List<ZipEntryInfo> entries;

  const ZipArchivePreview({
    super.key,
    required this.zipBytes,
    this.rawBytes,
    required this.fileName,
    this.zipOffset,
    this.entries = const [],
  });

  @override
  State<ZipArchivePreview> createState() => _ZipArchivePreviewState();
}

class _ZipArchivePreviewState extends State<ZipArchivePreview> {
  ZipViewTab _selectedTab = ZipViewTab.files;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ZipEntryInfo? _selectedEntry;

  Archive? _decodedArchive;
  final Map<String, Uint8List> _decompressedCache = {};
  bool _isDecompressing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    if (widget.entries.isNotEmpty) {
      _selectedEntry = widget.entries.firstWhere(
        (e) => !e.isDirectory,
        orElse: () => widget.entries.first,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ZipArchivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zipBytes != widget.zipBytes || oldWidget.rawBytes != widget.rawBytes) {
      _decodedArchive = null;
      _decompressedCache.clear();
      if (widget.entries.isNotEmpty) {
        _selectedEntry = widget.entries.firstWhere(
          (e) => !e.isDirectory,
          orElse: () => widget.entries.first,
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Archive? _getArchive() {
    if (_decodedArchive != null) return _decodedArchive;
    if (widget.zipBytes.isNotEmpty) {
      try {
        _decodedArchive = ZipDecoder().decodeBytes(widget.zipBytes, verify: false);
        if (_decodedArchive != null && _decodedArchive!.isNotEmpty) {
          return _decodedArchive;
        }
      } catch (_) {}
    }
    if (widget.rawBytes != null && widget.rawBytes!.isNotEmpty) {
      try {
        _decodedArchive = ZipDecoder().decodeBytes(widget.rawBytes!, verify: false);
        if (_decodedArchive != null && _decodedArchive!.isNotEmpty) {
          return _decodedArchive;
        }
      } catch (_) {}
    }
    return null;
  }

  Uint8List? _getDecompressedBytes(String entryName) {
    if (_decompressedCache.containsKey(entryName)) {
      return _decompressedCache[entryName];
    }
    final archive = _getArchive();
    if (archive == null) return null;

    final file = archive.findFile(entryName);
    if (file != null && file.isFile) {
      final bytes = file.content;
      _decompressedCache[entryName] = bytes;
      return bytes;
    }
    return null;
  }

  Future<void> _extractSingleEntry(ZipEntryInfo entry) async {
    final bytes = _getDecompressedBytes(entry.name);
    if (bytes == null) {
      Notify.error('Extraction Failed', description: 'Could not decompress ${entry.name}');
      return;
    }

    final cleanFileName = p.basename(entry.name);
    final ext = p.extension(cleanFileName).replaceAll('.', '').toLowerCase();

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Extracted File to Disk',
      fileName: cleanFileName,
      type: ext.isNotEmpty ? FileType.custom : FileType.any,
      allowedExtensions: ext.isNotEmpty ? [ext] : null,
      bytes: bytes,
    );

    if (kIsWeb) {
      Notify.success('File Downloaded', description: 'Downloaded $cleanFileName (${NumberUtils.formatSizeKb(bytes.length)})');
      return;
    }

    if (savePath != null) {
      final file = File(savePath);
      await file.writeAsBytes(bytes);
      Notify.success('File Extracted', description: 'Saved $cleanFileName to $savePath');
    }
  }

  Future<void> _extractAllFiles() async {
    final archive = _getArchive();
    if (archive == null || archive.isEmpty) {
      Notify.error('Extraction Failed', description: 'Could not decode ZIP archive structure');
      return;
    }

    if (kIsWeb) {
      Notify.info('Web Environment', description: 'Select individual files to decompress and download on Web');
      return;
    }

    final targetDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Output Directory for Extracted Files',
    );

    if (targetDir == null) return;

    setState(() => _isDecompressing = true);

    try {
      int extractedCount = 0;
      for (final file in archive.files) {
        final outPath = p.join(targetDir, file.name);
        if (!file.isFile || file.name.endsWith('/')) {
          Directory(outPath).createSync(recursive: true);
        } else {
          File(outPath).createSync(recursive: true);
          final content = file.content;
          File(outPath).writeAsBytesSync(content);
          extractedCount++;
        }
      }

      Notify.success(
        'Archive Extracted',
        description: 'Successfully extracted $extractedCount files to $targetDir',
      );
    } catch (e) {
      Notify.error('Extraction Error', description: '$e');
    } finally {
      if (mounted) setState(() => _isDecompressing = false);
    }
  }

  void _copyFileListToClipboard() {
    final buffer = StringBuffer();
    buffer.writeln('=== ZIP Archive Contents: ${widget.fileName} ===');
    buffer.writeln('Total Entries: ${widget.entries.length}');
    buffer.writeln('Archive Size: ${NumberUtils.formatSizeKb(widget.zipBytes.length)}');
    buffer.writeln('----------------------------------------------------');
    for (final e in widget.entries) {
      final type = e.isDirectory ? '[DIR] ' : '[FILE]';
      buffer.writeln('$type ${e.name} (${NumberUtils.formatSizeKb(e.size)}) [CRC32: ${e.crc32 != null ? '0x${e.crc32!.toRadixString(16).toUpperCase()}' : 'N/A'}]');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    Notify.success('Copied File List', description: 'Archive entries copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PolyglotController>() ? Get.find<PolyglotController>() : null;
    final entries = widget.entries;
    final totalUncompressed = entries.fold<int>(0, (sum, e) => sum + e.size);
    final totalCompressed = entries.fold<int>(0, (sum, e) => sum + e.compressedSize);
    final savingsPercent = totalUncompressed > 0
        ? (((totalUncompressed - totalCompressed) / totalUncompressed) * 100).clamp(0.0, 99.9).toStringAsFixed(1)
        : '0.0';

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
          // 1. Top Header Row: Archive Title, Format Badge, Badges, and Action Buttons
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
                  const Icon(Icons.folder_zip_outlined, size: 16, color: AppTheme.accent),
                  Text(
                    widget.fileName,
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
                      '${entries.length} ${entries.length == 1 ? 'Item' : 'Items'}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                  _buildTechBadge(NumberUtils.formatSizeKb(widget.zipBytes.length), const Color(0xFF38BDF8), Icons.data_usage_rounded),
                  _buildTechBadge('$savingsPercent% Saved', const Color(0xFF34D399), Icons.compress_rounded),
                  if (widget.zipOffset != null && widget.zipOffset! > 0)
                    _buildTechBadge('Byte ${NumberUtils.formatInt(widget.zipOffset!)}', const Color(0xFFFBBF24), Icons.place_outlined),
                ],
              ),

              // Action Buttons: Extract All, Copy List, Export ZIP
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
                    onPressed: _isDecompressing ? null : _extractAllFiles,
                    icon: _isDecompressing
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary))
                        : const Icon(Icons.folder_open_outlined, size: 13, color: AppTheme.textSecondary),
                    label: const Text(
                      'Extract All',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondary),
                    tooltip: 'Copy File List',
                    onPressed: _copyFileListToClipboard,
                  ),
                  if (controller != null) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.download_outlined, size: 14, color: AppTheme.textSecondary),
                      tooltip: 'Export ZIP Archive',
                      onPressed: () => controller.extractZipFile(),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Navigation Tabs (Archive Files / Overview / Central Directory Audit)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(child: _buildNavTab(ZipViewTab.files, 'Archive Files (${entries.length})', Icons.folder_open_rounded)),
                Expanded(child: _buildNavTab(ZipViewTab.overview, 'Overview & Stats', Icons.dashboard_outlined)),
                Expanded(child: _buildNavTab(ZipViewTab.audit, 'Central Directory Audit', Icons.account_tree_outlined)),
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
              _buildInfoBadge('Archive Size', NumberUtils.formatSizeKb(widget.zipBytes.length)),
              _buildInfoBadge('Uncompressed', NumberUtils.formatSizeKb(totalUncompressed)),
              _buildInfoBadge('Files', '${entries.where((e) => !e.isDirectory).length} files'),
              _buildInfoBadge('Directories', '${entries.where((e) => e.isDirectory).length} folders'),
              if (widget.zipOffset != null)
                _buildInfoBadge('Offset', 'Byte ${NumberUtils.formatInt(widget.zipOffset!)}'),
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

  Widget _buildNavTab(ZipViewTab tab, String label, IconData icon) {
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
      case ZipViewTab.files:
        return _buildFilesTab();
      case ZipViewTab.overview:
        return _buildOverviewTab();
      case ZipViewTab.audit:
        return _buildAuditTab();
    }
  }

  /// Tab 1: Interactive File Explorer with Search & In-App Decompression Preview
  Widget _buildFilesTab() {
    final filteredEntries = widget.entries.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.name.toLowerCase().contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        // Search Bar & Filter Summary
        Row(
          children: [
            Expanded(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search files inside archive...',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 14, color: AppTheme.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 13, color: AppTheme.textMuted),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '${filteredEntries.length} found',
                style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),

        const SizedBox(height: 10),

        // Responsive Master-Detail Split or Stack
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 620;

            if (isCompact) {
              return Column(
                children: [
                  _buildFileListContainer(filteredEntries, maxHeight: 220),
                  if (_selectedEntry != null) ...[
                    const SizedBox(height: 10),
                    _buildSelectedEntryPreview(_selectedEntry!),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left File List
                Expanded(
                  flex: 5,
                  child: _buildFileListContainer(filteredEntries, maxHeight: 520),
                ),
                const SizedBox(width: 10),
                // Right Live Preview Drawer
                Expanded(
                  flex: 6,
                  child: _selectedEntry != null
                      ? _buildSelectedEntryPreview(_selectedEntry!)
                      : Container(
                          height: 520,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C0E12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: const Text('Select a file to inspect and preview', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFileListContainer(List<ZipEntryInfo> list, {required double maxHeight}) {
    if (list.isEmpty) {
      return Container(
        height: maxHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: const Text('No matching files found in archive', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1B1E24)),
        itemBuilder: (context, i) {
          final entry = list[i];
          final isSelected = _selectedEntry?.name == entry.name;

          return InkWell(
            onTap: () => setState(() => _selectedEntry = entry),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: isSelected ? AppTheme.accent.withAlpha(25) : Colors.transparent,
              child: Row(
                children: [
                  Icon(
                    _getFileIcon(entry),
                    size: 14,
                    color: isSelected ? AppTheme.accent : (entry.isDirectory ? const Color(0xFF38BDF8) : AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.name,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontWeight: isSelected || entry.isDirectory ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    NumberUtils.formatSizeKb(entry.size),
                    style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Right Preview Panel: Details, Decompressed Text/Image Previews, and Single File Export
  Widget _buildSelectedEntryPreview(ZipEntryInfo entry) {
    final bytes = entry.isDirectory ? null : _getDecompressedBytes(entry.name);
    final ext = p.extension(entry.name).toLowerCase();
    final isImageFile = ['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.ico', '.gif'].contains(ext);

    return Container(
      constraints: const BoxConstraints(minHeight: 380, maxHeight: 520),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1216),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Name + Action Buttons
          Row(
            children: [
              Icon(_getFileIcon(entry), size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.name,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!entry.isDirectory) ...[
                if (isImageFile && bytes != null) ...[
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceElevated,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => ImagePreviewDialog.show(
                      context,
                      imageBytes: bytes,
                      fileName: entry.name,
                      onExport: () => _extractSingleEntry(entry),
                    ),
                    icon: const Icon(Icons.fullscreen_rounded, size: 13, color: AppTheme.accent),
                    label: const Text('Enlarge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceElevated,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: AppTheme.borderSubtle),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _extractSingleEntry(entry),
                  icon: const Icon(Icons.download_rounded, size: 12, color: AppTheme.textSecondary),
                  label: const Text('Extract', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),

          const SizedBox(height: 6),

          // Metadata Details Pill Grid
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildSmallBadge('Size', NumberUtils.formatSizeKb(entry.size)),
              _buildSmallBadge('Compressed', NumberUtils.formatSizeKb(entry.compressedSize)),
              _buildSmallBadge('Method', entry.compressionMethod),
              if (entry.crc32 != null)
                _buildSmallBadge('CRC32', '0x${entry.crc32!.toRadixString(16).toUpperCase()}'),
            ],
          ),

          const SizedBox(height: 8),

          // Live In-App Content Decompression Area
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF090B0E),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppTheme.borderSubtle.withAlpha(40)),
              ),
              clipBehavior: Clip.antiAlias,
              child: entry.isDirectory
                  ? const Center(
                      child: Text('Directory / Folder Node', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                    )
                  : bytes == null
                      ? const Center(
                          child: Text('Could not decompress payload stream', style: TextStyle(fontSize: 10.5, color: AppTheme.danger)),
                        )
                      : _buildEntryEnginePreview(entry, bytes, ext),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryEnginePreview(ZipEntryInfo entry, Uint8List bytes, String ext) {
    if (ext == '.pdf') {
      return _ZipEmbeddedPdfPreview(
        key: ValueKey('zip_pdf_${entry.name}'),
        pdfBytes: bytes,
        fileName: entry.name,
        entry: entry,
        onExtract: () => _extractSingleEntry(entry),
      );
    }

    if (['.mp3', '.m4a', '.wav', '.aac', '.flac', '.ogg'].contains(ext)) {
      return AudioPlayerPreview(
        key: ValueKey('zip_audio_${entry.name}'),
        audioBytes: bytes,
        fileName: entry.name,
        format: ext,
      );
    }

    if (['.mp4', '.mkv', '.avi', '.mov', '.webm'].contains(ext)) {
      return VideoPlayerPreview(
        key: ValueKey('zip_video_${entry.name}'),
        videoBytes: bytes,
        fileName: entry.name,
        format: ext,
      );
    }

    if (['.html', '.htm'].contains(ext)) {
      return _ZipEmbeddedHtmlPreview(
        key: ValueKey('zip_html_${entry.name}'),
        htmlBytes: bytes,
        fileName: entry.name,
        entry: entry,
      );
    }

    if (['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.ico', '.gif'].contains(ext)) {
      return _buildImagePreview(bytes, entry);
    }

    if (['.txt', '.json', '.md', '.dart', '.py', '.js', '.css', '.xml', '.yaml', '.yml', '.csv', '.log', '.sh', '.bat', '.sql', '.toml', '.ini', '.properties'].contains(ext)) {
      return _buildTextPreview(bytes);
    }

    return _buildBinaryHexPreview(bytes);
  }

  Widget _buildImagePreview(Uint8List bytes, ZipEntryInfo entry) {
    return Stack(
      children: [
        Positioned.fill(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => ImagePreviewDialog.show(
                context,
                imageBytes: bytes,
                fileName: entry.name,
                onExport: () => _extractSingleEntry(entry),
              ),
              child: Center(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('Invalid Image Data', style: TextStyle(fontSize: 10, color: AppTheme.danger)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ImagePreviewDialog.show(
                context,
                imageBytes: bytes,
                fileName: entry.name,
                onExport: () => _extractSingleEntry(entry),
              ),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(200),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.borderSubtle.withAlpha(140)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded, size: 11, color: AppTheme.textSecondary),
                    SizedBox(width: 4),
                    Text(
                      'Click to Enlarge',
                      style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextPreview(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = String.fromCharCodes(bytes.where((b) => b >= 32 && b <= 126));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: SelectionArea(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontFamily: 'monospace',
            color: Color(0xFFCBD5E1),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildBinaryHexPreview(Uint8List bytes) {
    final previewLength = bytes.length > 256 ? 256 : bytes.length;
    final buffer = StringBuffer();
    for (int i = 0; i < previewLength; i += 16) {
      final chunkEnd = i + 16 < previewLength ? i + 16 : previewLength;
      final hex = bytes.sublist(i, chunkEnd).map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      final ascii = bytes.sublist(i, chunkEnd).map((b) => (b >= 32 && b <= 126) ? String.fromCharCode(b) : '.').join();
      buffer.writeln('${i.toRadixString(16).padLeft(6, '0').toUpperCase()}  ${hex.padRight(48)}  |$ascii|');
    }
    if (bytes.length > 256) {
      buffer.writeln('\n... [${bytes.length - 256} more bytes in decompressed payload]');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: SelectionArea(
        child: Text(
          buffer.toString(),
          style: const TextStyle(
            fontSize: 9.5,
            fontFamily: 'monospace',
            color: Color(0xFF94A3B8),
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(ZipEntryInfo entry) {
    if (entry.isDirectory) return Icons.folder_outlined;
    final ext = p.extension(entry.name).toLowerCase();
    if (['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.ico', '.gif'].contains(ext)) {
      return Icons.image_outlined;
    } else if (['.mp4', '.mkv', '.avi', '.mov', '.webm'].contains(ext)) {
      return Icons.video_file_outlined;
    } else if (['.mp3', '.m4a', '.wav', '.aac', '.flac', '.ogg'].contains(ext)) {
      return Icons.audio_file_outlined;
    } else if (ext == '.pdf') {
      return Icons.picture_as_pdf_outlined;
    } else if (['.html', '.htm', '.css', '.js', '.dart', '.py', '.json', '.xml', '.yaml'].contains(ext)) {
      return Icons.code_rounded;
    } else if (['.zip', '.jar', '.apk', '.docx', '.xlsx', '.pptx'].contains(ext)) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  /// Tab 2: Overview & Archive Statistics
  Widget _buildOverviewTab() {
    final entries = widget.entries;
    final fileCount = entries.where((e) => !e.isDirectory).length;
    final dirCount = entries.where((e) => e.isDirectory).length;
    final totalUncompressed = entries.fold<int>(0, (sum, e) => sum + e.size);
    final totalCompressed = entries.fold<int>(0, (sum, e) => sum + e.compressedSize);
    final spaceSaved = totalUncompressed > totalCompressed ? totalUncompressed - totalCompressed : 0;
    final ratio = totalUncompressed > 0 ? ((spaceSaved / totalUncompressed) * 100).toStringAsFixed(1) : '0.0';

    // Group by file extension
    final extMap = <String, int>{};
    for (final e in entries) {
      if (!e.isDirectory) {
        final ext = p.extension(e.name).toLowerCase();
        final label = ext.isNotEmpty ? ext.substring(1).toUpperCase() : 'OTHER';
        extMap[label] = (extMap[label] ?? 0) + 1;
      }
    }

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
          const Text('Archive Summary & Storage Metrics', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatCard('Total Files', '$fileCount', Icons.insert_drive_file_outlined, const Color(0xFF38BDF8)),
              _buildStatCard('Folders', '$dirCount', Icons.folder_outlined, AppTheme.accent),
              _buildStatCard('Uncompressed', NumberUtils.formatSizeKb(totalUncompressed), Icons.unarchive_outlined, const Color(0xFFA78BFA)),
              _buildStatCard('Compressed', NumberUtils.formatSizeKb(totalCompressed), Icons.archive_outlined, const Color(0xFF34D399)),
              _buildStatCard('Space Saved', '$ratio%', Icons.compress_rounded, const Color(0xFFFBBF24)),
              if (widget.zipOffset != null)
                _buildStatCard('Offset', 'Byte ${widget.zipOffset!}', Icons.place_outlined, AppTheme.primary),
            ],
          ),

          const SizedBox(height: 14),

          // File Format Breakdown
          const Text('Contained File Types Breakdown', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: extMap.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value} ${entry.value == 1 ? 'file' : 'files'}',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String count, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(
                count,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: color),
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

  /// Tab 3: Central Directory Technical Audit Table
  Widget _buildAuditTab() {
    final entries = widget.entries;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1216),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 14, color: Color(0xFFFBBF24)),
              SizedBox(width: 6),
              Text(
                'ZIP Central Directory & Local Headers Audit',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
              itemBuilder: (context, i) {
                final e = entries[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        e.isDirectory ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                        size: 13,
                        color: e.isDirectory ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.name,
                              style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${e.compressionMethod} • CRC: ${e.crc32 != null ? '0x${e.crc32!.toRadixString(16).toUpperCase()}' : 'N/A'}',
                              style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            NumberUtils.formatSizeKb(e.size),
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          Text(
                            'Comp: ${NumberUtils.formatSizeKb(e.compressedSize)}',
                            style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
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

/// Embedded, responsive in-drawer PDF previewer with zoom, page navigation and system launcher.
class _ZipEmbeddedPdfPreview extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;
  final ZipEntryInfo entry;
  final VoidCallback onExtract;

  const _ZipEmbeddedPdfPreview({
    super.key,
    required this.pdfBytes,
    required this.fileName,
    required this.entry,
    required this.onExtract,
  });

  @override
  State<_ZipEmbeddedPdfPreview> createState() => _ZipEmbeddedPdfPreviewState();
}

class _ZipEmbeddedPdfPreviewState extends State<_ZipEmbeddedPdfPreview> {
  PdfController? _pdfController;
  final TransformationController _transformController = TransformationController();
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = true;
  String? _error;
  double _scale = 1.0;
  bool _isDragging = false;
  Offset? _lastPanPos;

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final isCtrlOrMeta = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
      if (isCtrlOrMeta) {
        GestureBinding.instance.pointerSignalResolver.register(event, (resolvedEvent) {
          if (resolvedEvent is PointerScrollEvent) {
            final scrollDelta = resolvedEvent.scrollDelta.dy;
            if (scrollDelta == 0) return;

            final zoomFactor = scrollDelta < 0 ? 1.15 : 0.85;
            final newScale = (_scale * zoomFactor).clamp(0.8, 4.5);
            if ((newScale - _scale).abs() < 0.001) return;

            final effectiveFactor = newScale / _scale;
            final focalPoint = resolvedEvent.localPosition;
            final currentMatrix = _transformController.value;
            final currentTrans = currentMatrix.getTranslation();

            final double tx = focalPoint.dx - effectiveFactor * (focalPoint.dx - currentTrans.x);
            final double ty = focalPoint.dy - effectiveFactor * (focalPoint.dy - currentTrans.y);

            _scale = newScale;
            if (newScale <= 1.02 && newScale >= 0.98 && tx.abs() < 2 && ty.abs() < 2) {
              _scale = 1.0;
              _transformController.value = Matrix4.identity();
            } else {
              final Matrix4 newMatrix = Matrix4.identity()
                ..setEntry(0, 0, newScale)
                ..setEntry(1, 1, newScale)
                ..setEntry(2, 2, 1.0)
                ..setEntry(0, 3, tx)
                ..setEntry(1, 3, ty);
              _transformController.value = newMatrix;
            }
            setState(() {});
          }
        });
      }
    }
  }

  void _toggleDoubleTapZoom(TapDownDetails details) {
    if (_scale > 1.25) {
      _scale = 1.0;
      _transformController.value = Matrix4.identity();
    } else {
      final position = details.localPosition;
      const double targetScale = 2.0;
      final effectiveFactor = targetScale / _scale;
      final currentTrans = _transformController.value.getTranslation();
      final double tx = position.dx - effectiveFactor * (position.dx - currentTrans.x);
      final double ty = position.dy - effectiveFactor * (position.dy - currentTrans.y);

      _scale = targetScale;
      final Matrix4 matrix = Matrix4.identity()
        ..setEntry(0, 0, targetScale)
        ..setEntry(1, 1, targetScale)
        ..setEntry(2, 2, 1.0)
        ..setEntry(0, 3, tx)
        ..setEntry(1, 3, ty);
      _transformController.value = matrix;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _transformController.addListener(() {
      final s = _transformController.value.getMaxScaleOnAxis();
      if ((s - _scale).abs() > 0.02) {
        setState(() => _scale = s);
      }
    });
    _initPdf();
  }

  @override
  void didUpdateWidget(covariant _ZipEmbeddedPdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfBytes != widget.pdfBytes) {
      _initPdf();
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Uint8List _getNormalizedBytes() {
    final bytes = widget.pdfBytes;
    int startIdx = -1;
    for (int i = 0; i <= bytes.length - 5; i++) {
      if (bytes[i] == 0x25 && bytes[i + 1] == 0x50 && bytes[i + 2] == 0x44 && bytes[i + 3] == 0x46 && bytes[i + 4] == 0x2D) {
        startIdx = i;
        break;
      }
    }
    final toNormalize = startIdx > 0 ? Uint8List.fromList(bytes.sublist(startIdx)) : bytes;
    return PolyglotInspector.normalizePdfStream(toNormalize, startIdx > 0 ? startIdx : 0);
  }

  Future<void> _initPdf() async {
    _pdfController?.dispose();
    _pdfController = null;
    _transformController.value = Matrix4.identity();
    setState(() {
      _isLoading = true;
      _error = null;
      _scale = 1.0;
    });

    try {
      if (widget.pdfBytes.isEmpty) throw Exception('PDF byte stream is empty');
      final normalized = _getNormalizedBytes();
      final doc = await PdfDocument.openData(normalized);
      _totalPages = doc.pagesCount > 0 ? doc.pagesCount : 1;
      _currentPage = 1;
      _pdfController = PdfController(
        document: PdfDocument.openData(normalized),
        initialPage: 1,
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _openInSystemViewer() async {
    if (kIsWeb) {
      Notify.info('Web Preview', description: 'Extract the file to open locally');
      return;
    }
    try {
      final normalized = _getNormalizedBytes();
      final tempDir = Directory.systemTemp;
      final cleanName = widget.fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final tempFile = File(p.join(tempDir.path, 'polyglot_zip_preview_${DateTime.now().millisecondsSinceEpoch}_$cleanName.pdf'));
      await tempFile.writeAsBytes(normalized, flush: true);
      if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', tempFile.path], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', [tempFile.path], mode: ProcessStartMode.detached);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [tempFile.path], mode: ProcessStartMode.detached);
      }
      Notify.success('Launched in System Viewer', description: 'Opened ${widget.fileName} in default viewer');
    } catch (e) {
      Notify.error('Error', description: 'Could not open viewer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
        ),
      );
    }

    if (_error != null || _pdfController == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 24, color: AppTheme.textMuted),
              const SizedBox(height: 6),
              Text('PDF Preview Error: $_error', style: const TextStyle(fontSize: 10.5, color: AppTheme.danger), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceElevated,
                  foregroundColor: AppTheme.textPrimary,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _openInSystemViewer,
                icon: const Icon(Icons.open_in_new_rounded, size: 12, color: AppTheme.accent),
                label: const Text('Open Externally', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Interactive Page View Canvas with Mouse Wheel Zoom and Frictionless Drag (Isolated from drawer scroll)
        Expanded(
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
                  final currentMatrix = _transformController.value;
                  final trans = currentMatrix.getTranslation();
                  final matrix = Matrix4.identity()
                    ..setEntry(0, 0, _scale)
                    ..setEntry(1, 1, _scale)
                    ..setEntry(0, 3, trans.x + delta.dx)
                    ..setEntry(1, 3, trans.y + delta.dy);
                  _transformController.value = matrix;
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
                      transform: _transformController.value,
                      child: PdfView(
                        controller: _pdfController!,
                        onPageChanged: (page) => setState(() => _currentPage = page),
                        builders: PdfViewBuilders<DefaultBuilderOptions>(
                          options: const DefaultBuilderOptions(),
                          documentLoaderBuilder: (_) => const Center(
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
                          ),
                          pageLoaderBuilder: (_) => const Center(
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
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

        // Compact Bottom Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0E12),
            border: Border(top: BorderSide(color: AppTheme.borderSubtle.withAlpha(50))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Page Navigation
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_left_rounded, size: 16, color: AppTheme.textPrimary),
                    onPressed: _currentPage > 1 ? () => _pdfController?.previousPage(curve: Curves.easeOut, duration: const Duration(milliseconds: 200)) : null,
                  ),
                  Text(
                    'Page $_currentPage / $_totalPages',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textPrimary),
                    onPressed: _currentPage < _totalPages ? () => _pdfController?.nextPage(curve: Curves.easeOut, duration: const Duration(milliseconds: 200)) : null,
                  ),
                ],
              ),

              // Scale indicator & External launch
              Row(
                children: [
                  if (_scale > 1.05) ...[
                    InkWell(
                      onTap: () => _transformController.value = Matrix4.identity(),
                      child: Text(
                        '${(_scale * 100).toInt()}% [Reset]',
                        style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppTheme.accent),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  InkWell(
                    onTap: _openInSystemViewer,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 10, color: AppTheme.textSecondary),
                          SizedBox(width: 4),
                          Text('Open Viewer', style: TextStyle(fontSize: 9.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Embedded, responsive in-drawer HTML viewer with Live App rendering, code inspection, and browser launch.
class _ZipEmbeddedHtmlPreview extends StatefulWidget {
  final Uint8List htmlBytes;
  final String fileName;
  final ZipEntryInfo entry;

  const _ZipEmbeddedHtmlPreview({
    super.key,
    required this.htmlBytes,
    required this.fileName,
    required this.entry,
  });

  @override
  State<_ZipEmbeddedHtmlPreview> createState() => _ZipEmbeddedHtmlPreviewState();
}

class _ZipEmbeddedHtmlPreviewState extends State<_ZipEmbeddedHtmlPreview> {
  bool _renderInApp = true;
  String _htmlText = '';
  late CssStyleResolver _cssResolver;

  @override
  void initState() {
    super.initState();
    _decodeHtml();
  }

  @override
  void didUpdateWidget(covariant _ZipEmbeddedHtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlBytes != widget.htmlBytes) {
      _decodeHtml();
    }
  }

  void _decodeHtml() {
    try {
      _htmlText = utf8.decode(widget.htmlBytes, allowMalformed: true);
    } catch (_) {
      _htmlText = String.fromCharCodes(widget.htmlBytes.where((b) => b >= 32 && b <= 126));
    }
    _cssResolver = CssStyleResolver.fromHtml(_htmlText);
  }

  Future<void> _openInBrowser() async {
    if (kIsWeb) {
      Notify.info('Web Preview', description: 'Extract the file to open in browser');
      return;
    }
    try {
      final tempDir = Directory.systemTemp;
      final cleanName = widget.fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final tempFile = File(p.join(tempDir.path, 'polyglot_zip_preview_${DateTime.now().millisecondsSinceEpoch}_$cleanName.html'));
      await tempFile.writeAsString(_htmlText, flush: true);
      if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', tempFile.path], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', [tempFile.path], mode: ProcessStartMode.detached);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [tempFile.path], mode: ProcessStartMode.detached);
      }
      Notify.success('Launched in Browser', description: 'Opened ${widget.fileName} in default browser');
    } catch (e) {
      Notify.error('Error', description: 'Could not open browser: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyRules = _cssResolver.tagRules['body'] ?? _cssResolver.tagRules['html'] ?? {};
    final bodyBgColor = _cssResolver.parseColor(bodyRules['background-color'] ?? bodyRules['background']);
    final bodyTextColor = _cssResolver.parseColor(bodyRules['color']);
    final bodyFontFamilyRaw = bodyRules['font-family']?.replaceAll(RegExp(r"""['"]"""), '').split(',').first.trim();
    final isBodyCentered = bodyRules['text-align'] == 'center';

    return Column(
      children: [
        // Mode switch toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0E12),
            border: Border(bottom: BorderSide(color: AppTheme.borderSubtle.withAlpha(50))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildToggleBtn('Render In App', _renderInApp, () => setState(() => _renderInApp = true)),
                  const SizedBox(width: 4),
                  _buildToggleBtn('Code Source', !_renderInApp, () => setState(() => _renderInApp = false)),
                ],
              ),
              Row(
                children: [
                  if (_renderInApp && bodyBgColor != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: bodyBgColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: bodyBgColor.withAlpha(90)),
                      ),
                      child: const Text('CSS Styled', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _htmlText));
                      Notify.success('Copied HTML', description: 'HTML content copied to clipboard');
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 10, color: AppTheme.textSecondary),
                          SizedBox(width: 4),
                          Text('Copy', style: TextStyle(fontSize: 9.5, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _openInBrowser,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_browser_rounded, size: 10, color: AppTheme.accent),
                          SizedBox(width: 4),
                          Text('Browser', style: TextStyle(fontSize: 9.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Body Content with CSS3 Styling Engine
        Expanded(
          child: _renderInApp
              ? Container(
                  color: bodyBgColor ?? const Color(0xFF0D0F12),
                  alignment: isBodyCentered ? Alignment.topCenter : Alignment.topLeft,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectionArea(
                      child: HtmlWidget(
                        _htmlText,
                        textStyle: TextStyle(
                          fontSize: 11.5,
                          color: bodyTextColor ?? AppTheme.textPrimary,
                          height: 1.45,
                          fontFamily: (bodyFontFamilyRaw != null && bodyFontFamilyRaw.isNotEmpty) ? bodyFontFamilyRaw : 'Segoe UI',
                        ),
                        customStylesBuilder: (element) {
                          final tagName = element.localName ?? '';
                          final classAttr = element.attributes['class'] ?? '';
                          final classes = classAttr.split(RegExp(r'\s+')).where((c) => c.isNotEmpty).toList();
                          final idAttr = element.attributes['id'];

                          // 1. Resolve CSS declarations from embedded <style> tags and stylesheets
                          final resolved = _cssResolver.resolveStyles(tagName, classes, idAttr) ?? <String, String>{};

                          // 2. Default element aesthetics for unstyled components
                          if (tagName == 'a' && !resolved.containsKey('color')) {
                            resolved['color'] = '#38BDF8';
                            resolved['text-decoration'] = 'underline';
                          }
                          if ((tagName == 'h1' || tagName == 'h2' || tagName == 'h3') && !resolved.containsKey('color')) {
                            if (bodyTextColor == null) {
                              resolved['color'] = '#F9FAFB';
                            }
                            resolved['font-weight'] = 'bold';
                          }
                          if (tagName == 'code' && !resolved.containsKey('background-color')) {
                            resolved['background-color'] = '#1E222A';
                            resolved['color'] = '#34D399';
                            resolved['font-family'] = 'monospace';
                            resolved['padding'] = '2px 5px';
                            resolved['border-radius'] = '3px';
                          }
                          if (tagName == 'pre' && !resolved.containsKey('background-color')) {
                            resolved['background-color'] = '#15181E';
                            resolved['color'] = '#E5E7EB';
                            resolved['font-family'] = 'monospace';
                            resolved['padding'] = '8px';
                            resolved['border-radius'] = '6px';
                          }

                          return resolved.isEmpty ? null : resolved;
                        },
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: SelectionArea(
                    child: Text(
                      _htmlText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Color(0xFFCBD5E1),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildToggleBtn(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? AppTheme.accent.withAlpha(80) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.accent : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}


