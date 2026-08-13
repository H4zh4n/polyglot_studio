import 'dart:io' show Directory, File, Platform, Process;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:polyglot_core/polyglot_core.dart';
import '../../../controllers/polyglot_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/notify.dart';
import '../../../utils/number_utils.dart';

enum HtmlViewMode {
  sandbox,
  source,
  scripts,
  styles,
}

/// A comprehensive, pro-grade interactive HTML, CSS & JavaScript Document Viewer and Inspector.
class HtmlDocumentPreview extends StatefulWidget {
  final String htmlContent;
  final String fileName;
  final HtmlMetadataInfo htmlInfo;

  const HtmlDocumentPreview({
    super.key,
    required this.htmlContent,
    required this.fileName,
    this.htmlInfo = const HtmlMetadataInfo(),
  });

  @override
  State<HtmlDocumentPreview> createState() => _HtmlDocumentPreviewState();
}

class _HtmlDocumentPreviewState extends State<HtmlDocumentPreview> {
  HtmlViewMode _selectedTab = HtmlViewMode.sandbox;
  String _searchQuery = '';
  bool _wrapLines = true;
  final TextEditingController _searchController = TextEditingController();

  static const int _pageSize = 250;
  static const int _maxLineLengthForHighlight = 400;

  List<String> _cachedLines = [];
  int _visibleLineCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _splitLines();
  }

  @override
  void didUpdateWidget(covariant HtmlDocumentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent) {
      _splitLines();
    }
  }

  void _splitLines() {
    _cachedLines = widget.htmlContent.split('\n');
    _visibleLineCount = _cachedLines.length > _pageSize ? _pageSize : _cachedLines.length;
  }

  void _loadMoreLines() {
    setState(() {
      _visibleLineCount = (_visibleLineCount + _pageSize).clamp(0, _cachedLines.length);
    });
  }

  void _showAllLines() {
    setState(() {
      _visibleLineCount = _cachedLines.length;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openInSystemBrowser() async {
    try {
      if (kIsWeb) {
        Notify.info(
          'Browser Preview',
          description: 'Use Copy HTML to paste into your browser',
        );
        return;
      }

      final tempDir = Directory.systemTemp;
      final cleanName = widget.fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final tempFile = File(p.join(tempDir.path, 'polyglot_preview_${DateTime.now().millisecondsSinceEpoch}_$cleanName.html'));
      await tempFile.writeAsString(widget.htmlContent, flush: true);

      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', tempFile.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [tempFile.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [tempFile.path]);
      }

      Notify.success(
        'Launched in Browser',
        description: 'Opened webpage in default system browser',
      );
    } catch (e) {
      Notify.error(
        'Error',
        description: 'Could not open browser: $e',
      );
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.htmlContent));
    Notify.success(
      'Copied to Clipboard',
      description: 'HTML source copied (${widget.htmlContent.length} characters)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PolyglotController>() ? Get.find<PolyglotController>() : null;
    final info = widget.htmlInfo;

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
          // 1. Top Header Row with Format Badge, Badges, and Action Buttons
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
                  const Icon(Icons.code_rounded, size: 16, color: AppTheme.accent),
                  Text(
                    info.title != null && info.title!.isNotEmpty ? info.title! : 'HTML Webpage Document',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: const Text(
                      '.HTML',
                      style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.accent),
                    ),
                  ),

                  // Technology Tags
                  if (info.hasCss)
                    _buildTechBadge('CSS3', const Color(0xFF38BDF8), Icons.palette_outlined),
                  if (info.hasJavaScript)
                    _buildTechBadge('JS (${info.scriptCount})', const Color(0xFFFBBF24), Icons.javascript_rounded),
                  if (info.canvasCount > 0 || info.svgCount > 0)
                    _buildTechBadge('Graphics', AppTheme.primary, Icons.draw_outlined),
                  if (info.scriptSources.isNotEmpty || info.stylesheetHrefs.isNotEmpty)
                    _buildTechBadge('CDNs', const Color(0xFFA78BFA), Icons.cloud_outlined),
                ],
              ),

              // Action Buttons: Open in Browser, Copy, Export
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary.withAlpha(25),
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      side: BorderSide(color: AppTheme.primary.withAlpha(80)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _openInSystemBrowser,
                    icon: const Icon(Icons.open_in_browser_rounded, size: 13),
                    label: const Text('Open in Browser', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondary),
                    tooltip: 'Copy Source Code',
                    onPressed: _copyToClipboard,
                  ),
                  if (controller != null) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.download_outlined, size: 14, color: AppTheme.textSecondary),
                      tooltip: 'Export Clean HTML Document',
                      onPressed: () => controller.extractHtmlFile(),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Navigation Tabs (Sandbox / Source / Scripts / Styles)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(child: _buildNavTab(HtmlViewMode.sandbox, 'Overview & DOM', Icons.dashboard_outlined)),
                Expanded(child: _buildNavTab(HtmlViewMode.source, 'Code Source', Icons.terminal_rounded)),
                Expanded(child: _buildNavTab(HtmlViewMode.scripts, 'JavaScript (${info.scriptCount})', Icons.code_rounded)),
                Expanded(child: _buildNavTab(HtmlViewMode.styles, 'CSS & Styles (${info.styleCount})', Icons.style_outlined)),
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
              _buildInfoBadge('Size', NumberUtils.formatSizeKb(widget.htmlContent.length)),
              _buildInfoBadge('Lines', NumberUtils.formatInt(_cachedLines.length)),
              _buildInfoBadge('Chars', NumberUtils.formatInt(widget.htmlContent.length)),
              if (info.scriptCount > 0)
                _buildInfoBadge('Scripts', '${info.scriptCount} tags'),
              if (info.styleCount > 0)
                _buildInfoBadge('Styles', '${info.styleCount} blocks'),
              if (info.imageTagCount > 0)
                _buildInfoBadge('Images', '${info.imageTagCount} tags'),
              if (info.anchorCount > 0)
                _buildInfoBadge('Links', '${info.anchorCount} tags'),
              if (info.formCount > 0)
                _buildInfoBadge('Forms', '${info.formCount} forms'),
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
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80)),
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

  Widget _buildNavTab(HtmlViewMode mode, String label, IconData icon) {
    final isSelected = _selectedTab == mode;
    return InkWell(
      onTap: () => setState(() => _selectedTab = mode),
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
              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
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
      case HtmlViewMode.sandbox:
        return _buildSandboxTab();
      case HtmlViewMode.source:
        return _buildSourceTab();
      case HtmlViewMode.scripts:
        return _buildScriptsTab();
      case HtmlViewMode.styles:
        return _buildStylesTab();
    }
  }

  /// Tab 1: Overview & DOM Structure
  Widget _buildSandboxTab() {
    final info = widget.htmlInfo;

    final bodyText = info.cleanBodyHtml;
    final isBodyLong = bodyText != null && bodyText.length > 2500;
    final displayBody = isBodyLong ? '${bodyText.substring(0, 2500)}\n\n... [${bodyText.length - 2500} characters truncated in overview. Use \'Code Source\' or \'Open in Browser\' to view full content]' : bodyText;

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
          // Live Launch Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withAlpha(25),
                  const Color(0xFF38BDF8).withAlpha(15),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.primary.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, size: 20, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full Modern JavaScript & CSS Runtime Sandbox',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Launch this webpage in the default browser to run dynamic WebGL, Canvas, JavaScript ES2024, CSS Grid, and interactive animations.',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withAlpha(200)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: const Color(0xFF0D0F12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: _openInSystemBrowser,
                  child: const Text('Launch Live', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // DOM Element Breakdown Cards
          const Text(
            'Document Element Statistics',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDomStatCard('Scripts', '${info.scriptCount}', Icons.javascript_rounded, const Color(0xFFFBBF24)),
              _buildDomStatCard('Styles', '${info.styleCount}', Icons.palette_rounded, const Color(0xFF38BDF8)),
              _buildDomStatCard('External CDNs', '${info.scriptSources.length + info.stylesheetHrefs.length}', Icons.cloud_done_rounded, const Color(0xFFA78BFA)),
              _buildDomStatCard('Images', '${info.imageTagCount}', Icons.image_outlined, AppTheme.primary),
              _buildDomStatCard('Links', '${info.anchorCount}', Icons.link_rounded, const Color(0xFF34D399)),
              _buildDomStatCard('Forms', '${info.formCount}', Icons.dynamic_form_outlined, const Color(0xFFF472B6)),
              _buildDomStatCard('Canvas/SVG', '${info.canvasCount + info.svgCount}', Icons.draw_outlined, const Color(0xFF6EE7B7)),
            ],
          ),

          if (displayBody != null && displayBody.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Extracted Body Content',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
                if (isBodyLong)
                  Text(
                    'Preview (${NumberUtils.formatInt(displayBody.length)} chars)',
                    style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: SingleChildScrollView(
                child: SelectionArea(
                  child: Text(
                    displayBody,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textSecondary, height: 1.4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDomStatCard(String label, String count, IconData icon, Color color) {
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: color),
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

  /// Tab 2: High-Performance Virtualized Code Source with SelectionArea, Pagination & Safe Regex
  Widget _buildSourceTab() {
    final totalLines = _cachedLines.length;
    final displayLinesCount = _visibleLineCount.clamp(0, totalLines);
    final hasMoreLines = displayLinesCount < totalLines;

    int searchMatchCount = 0;
    if (_searchQuery.isNotEmpty) {
      for (final l in _cachedLines) {
        if (l.toLowerCase().contains(_searchQuery.toLowerCase())) {
          searchMatchCount++;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Source Toolbar: Search, Matches, Wrap & Copy
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search in source...',
                      hintStyle: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 13, color: AppTheme.textMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 12, color: AppTheme.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: searchMatchCount > 0 ? AppTheme.primary.withAlpha(25) : AppTheme.danger.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: searchMatchCount > 0 ? AppTheme.primary.withAlpha(80) : AppTheme.danger.withAlpha(80),
                    ),
                  ),
                  child: Text(
                    '$searchMatchCount match${searchMatchCount == 1 ? '' : 'es'}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: searchMatchCount > 0 ? AppTheme.primary : AppTheme.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _wrapLines ? 'Disable Line Wrap' : 'Enable Line Wrap',
                icon: Icon(
                  _wrapLines ? Icons.wrap_text_rounded : Icons.format_align_left_rounded,
                  size: 15,
                  color: _wrapLines ? AppTheme.primary : AppTheme.textMuted,
                ),
                onPressed: () => setState(() => _wrapLines = !_wrapLines),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy Source Code',
                icon: const Icon(Icons.copy, size: 14, color: AppTheme.textSecondary),
                onPressed: _copyToClipboard,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Code Container with SelectionArea and Virtualized List
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xFF090B0E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle.withAlpha(50)),
            ),
            child: SelectionArea(
              child: ListView.builder(
                itemCount: displayLinesCount + (hasMoreLines ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == displayLinesCount) {
                    // Paging / Load More Footer
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      color: AppTheme.surfaceElevated.withAlpha(80),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing 1–$displayLinesCount of ${NumberUtils.formatInt(totalLines)} lines',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                          ),
                          Row(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _loadMoreLines,
                                child: Text('Load next $_pageSize lines', style: const TextStyle(fontSize: 10, color: AppTheme.primary)),
                              ),
                              const SizedBox(width: 6),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _showAllLines,
                                child: const Text('Show all lines', style: TextStyle(fontSize: 10, color: Color(0xFF38BDF8))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  final lineNum = index + 1;
                  final rawLineText = _cachedLines[index];
                  final isMatch = _searchQuery.isNotEmpty && rawLineText.toLowerCase().contains(_searchQuery.toLowerCase());

                  return Container(
                    color: isMatch ? AppTheme.primary.withAlpha(40) : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 38,
                          child: Text(
                            '$lineNum',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF4B5563)),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            _highlightHtmlLine(rawLineText, _searchQuery),
                            style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', height: 1.35),
                            maxLines: _wrapLines ? null : 1,
                            overflow: _wrapLines ? TextOverflow.clip : TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _highlightHtmlLine(String rawText, String search) {
    if (rawText.trim().startsWith('<!--') || rawText.trim().endsWith('-->')) {
      return TextSpan(text: rawText, style: const TextStyle(color: Color(0xFF6B7280)));
    }

    // Safety guard: Truncate very long minified single lines to avoid freezing regex and text painter
    final isTruncated = rawText.length > _maxLineLengthForHighlight;
    final text = isTruncated ? rawText.substring(0, _maxLineLengthForHighlight) : rawText;

    final spans = <TextSpan>[];
    final tagRegex = RegExp(r"""(<\/?[a-zA-Z0-9\-]+)|([a-zA-Z\-]+(?=\=))|("[^"]*"|'[^']*')|(\/?>)""");

    int lastMatchEnd = 0;
    for (final match in tagRegex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: const TextStyle(color: Color(0xFFD1D5DB)),
        ));
      }

      final matchedText = match.group(0)!;
      if (match.group(1) != null) {
        // Tag name
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold)));
      } else if (match.group(2) != null) {
        // Attribute
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFF38BDF8))));
      } else if (match.group(3) != null) {
        // Attribute value
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFF34D399))));
      } else if (match.group(4) != null) {
        // Closing tag bracket
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFF2DD4BF))));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: const TextStyle(color: Color(0xFFD1D5DB)),
      ));
    }

    if (isTruncated) {
      spans.add(TextSpan(
        text: ' ... [truncated +${rawText.length - _maxLineLengthForHighlight} chars for performance]',
        style: const TextStyle(color: Color(0xFF6B7280), fontStyle: FontStyle.italic, fontSize: 9.5),
      ));
    }

    return TextSpan(children: spans);
  }

  /// Tab 3: Scripts & JavaScript Security Inspector
  Widget _buildScriptsTab() {
    final info = widget.htmlInfo;

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
          Row(
            children: [
              const Icon(Icons.security_rounded, size: 14, color: Color(0xFFFBBF24)),
              const SizedBox(width: 6),
              const Text(
                'JavaScript Engine & Script Audit',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const Spacer(),
              Text(
                '${info.scriptCount} script tags found',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (info.scriptSources.isNotEmpty) ...[
            const Text(
              'External CDN / Script Libraries',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            ...info.scriptSources.map((src) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 12, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          src,
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFFFBBF24)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],

          if (info.scriptCount == 0 && !info.hasJavaScript) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 14, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('No executable scripts detected in document.', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x1AFBBF24),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x44FBBF24)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFFFBBF24)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Document contains interactive JavaScript. Scripts execute inside the browser environment.',
                      style: TextStyle(fontSize: 10, color: Color(0xFFFDE68A)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tab 4: CSS Styles & Stylesheets Inspector
  Widget _buildStylesTab() {
    final info = widget.htmlInfo;

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
          Row(
            children: [
              const Icon(Icons.style_rounded, size: 14, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              const Text(
                'CSS3 Stylesheets & Inline Rules',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const Spacer(),
              Text(
                '${info.styleCount} style blocks, ${info.stylesheetHrefs.length} linked sheets',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (info.stylesheetHrefs.isNotEmpty) ...[
            const Text(
              'Linked External Stylesheets',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            ...info.stylesheetHrefs.map((href) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.palette_outlined, size: 12, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          href,
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF38BDF8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                _buildStyleFeaturePill('Inline Styles', info.hasInlineStyles),
                const SizedBox(width: 8),
                _buildStyleFeaturePill('Embedded <style>', info.styleCount > 0),
                const SizedBox(width: 8),
                _buildStyleFeaturePill('CSS Grid / Flex', widget.htmlContent.contains('grid') || widget.htmlContent.contains('flex')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleFeaturePill(String label, bool isPresent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isPresent ? const Color(0x2238BDF8) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isPresent ? const Color(0x6638BDF8) : AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPresent ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 11,
            color: isPresent ? const Color(0xFF38BDF8) : AppTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isPresent ? FontWeight.bold : FontWeight.normal,
              color: isPresent ? const Color(0xFF38BDF8) : AppTheme.textMuted,
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
