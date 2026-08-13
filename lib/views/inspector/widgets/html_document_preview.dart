import 'dart:io' show Directory, File, Platform, Process;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:polyglot_core/polyglot_core.dart';
import '../../../controllers/polyglot_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/notify.dart';
import '../../../utils/number_utils.dart';

enum HtmlViewMode {
  overview,
  source,
  scripts,
  styles,
}

/// Advanced CSS Stylesheet Parser, Color Resolver and Selector Matcher for Flutter HTML Rendering.
class CssStyleResolver {
  final Map<String, Map<String, String>> tagRules = {};
  final Map<String, Map<String, String>> classRules = {};
  final Map<String, Map<String, String>> idRules = {};

  static const Map<String, Color> namedColors = {
    'transparent': Color(0x00000000),
    'white': Color(0xFFFFFFFF),
    'black': Color(0xFF000000),
    'red': Color(0xFFFF0000),
    'green': Color(0xFF008000),
    'blue': Color(0xFF0000FF),
    'yellow': Color(0xFFFFFF00),
    'purple': Color(0xFF800080),
    'gray': Color(0xFF808080),
    'grey': Color(0xFF808080),
    'silver': Color(0xFFC0C0C0),
    'maroon': Color(0xFF800000),
    'olive': Color(0xFF808000),
    'lime': Color(0xFF00FF00),
    'aqua': Color(0xFF00FFFF),
    'teal': Color(0xFF008080),
    'navy': Color(0xFF000080),
    'fuchsia': Color(0xFFFF00FF),
    'orange': Color(0xFFFFA500),
  };

  CssStyleResolver.fromHtml(String html) {
    _parseStyles(html);
  }

  void _parseStyles(String html) {
    final styleRegex = RegExp(r'<style[^>]*>(.*?)</style>', caseSensitive: false, dotAll: true);
    for (final match in styleRegex.allMatches(html)) {
      final cssContent = match.group(1) ?? '';
      _parseCssText(cssContent);
    }
  }

  void _parseCssText(String css) {
    // Remove comments
    final cleanCss = css.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

    // Match selector { declarations }
    final ruleRegex = RegExp(r'([^{]+)\{([^}]+)\}', dotAll: true);
    for (final match in ruleRegex.allMatches(cleanCss)) {
      final selectorGroup = match.group(1)?.trim() ?? '';
      final declarationsText = match.group(2)?.trim() ?? '';

      // Skip polyglot font-size 0 reset trick
      if (selectorGroup.contains('body') && declarationsText.contains('font-size:0')) {
        continue;
      }

      final declarations = _parseDeclarations(declarationsText);
      final selectors = selectorGroup.split(',');

      for (var selector in selectors) {
        selector = selector.trim().toLowerCase();
        if (selector.isEmpty) continue;

        // Clean up pseudo-classes (:hover, :focus, etc) for static Flutter canvas rendering
        if (selector.contains(':')) {
          selector = selector.split(':')[0].trim();
        }

        if (selector.startsWith('.')) {
          final className = selector.substring(1).trim();
          classRules.putIfAbsent(className, () => {}).addAll(declarations);
        } else if (selector.startsWith('#')) {
          final idName = selector.substring(1).trim();
          idRules.putIfAbsent(idName, () => {}).addAll(declarations);
        } else {
          tagRules.putIfAbsent(selector, () => {}).addAll(declarations);
        }
      }
    }
  }

  Map<String, String> _parseDeclarations(String declText) {
    final result = <String, String>{};
    final pairs = declText.split(';');
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length >= 2) {
        final prop = parts[0].trim().toLowerCase();
        var val = parts.sublist(1).join(':').trim();
        if (prop.isNotEmpty && val.isNotEmpty) {
          // Normalize unitless numeric dimensions to px (e.g. font-size: 12 -> 12px)
          if (RegExp(r'^\d+(\.\d+)?$').hasMatch(val) &&
              (prop.contains('font-size') ||
                  prop.contains('padding') ||
                  prop.contains('margin') ||
                  prop.contains('radius') ||
                  prop.contains('width') ||
                  prop.contains('height'))) {
            val = '${val}px';
          }
          result[prop] = val;

          // Duplicate 'background' color declarations to 'background-color' for Flutter widget engine
          if (prop == 'background' &&
              (val.startsWith('#') || val.startsWith('rgb') || val.startsWith('hsl') || namedColors.containsKey(val.toLowerCase()))) {
            result['background-color'] = val;
          }
        }
      }
    }
    return result;
  }

  Map<String, String>? resolveStyles(String tagName, List<String> classes, String? id) {
    final styles = <String, String>{};

    // 1. Tag rules (e.g. h1, p, table, etc.)
    final tagStyle = tagRules[tagName.toLowerCase()];
    if (tagStyle != null) styles.addAll(tagStyle);

    // 2. Class rules (e.g. .btn, .cipher, .text, etc.)
    for (final cls in classes) {
      final classStyle = classRules[cls.toLowerCase()];
      if (classStyle != null) styles.addAll(classStyle);
    }

    // 3. ID rules (e.g. #header)
    if (id != null) {
      final idStyle = idRules[id.toLowerCase()];
      if (idStyle != null) styles.addAll(idStyle);
    }

    return styles.isEmpty ? null : styles;
  }

  Color? parseColor(String? colorStr) {
    if (colorStr == null) return null;
    var str = colorStr.trim().toLowerCase();

    // Check named colors
    if (namedColors.containsKey(str)) {
      return namedColors[str];
    }

    // Hex colors
    if (str.startsWith('#')) {
      str = str.substring(1);
      if (str.length == 3) {
        str = '${str[0]}${str[0]}${str[1]}${str[1]}${str[2]}${str[2]}';
      }
      if (str.length == 6) {
        final val = int.tryParse('FF$str', radix: 16);
        if (val != null) return Color(val);
      } else if (str.length == 8) {
        final val = int.tryParse(str, radix: 16);
        if (val != null) return Color(val);
      }
    }

    // RGB / RGBA
    if (str.startsWith('rgb')) {
      final match = RegExp(r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d\.]+))?\s*\)').firstMatch(str);
      if (match != null) {
        final r = int.parse(match.group(1)!);
        final g = int.parse(match.group(2)!);
        final b = int.parse(match.group(3)!);
        final a = match.group(4) != null ? double.parse(match.group(4)!) : 1.0;
        return Color.fromRGBO(r, g, b, a);
      }
    }

    return null;
  }
}

/// A comprehensive, pro-grade interactive HTML, CSS & JavaScript Document Inspector and In-App Renderer.
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
  HtmlViewMode _selectedTab = HtmlViewMode.overview;
  String _searchQuery = '';
  bool _wrapLines = true;
  bool _renderInApp = false;
  final TextEditingController _searchController = TextEditingController();

  static const int _pageSize = 250;
  static const int _maxLineLengthForHighlight = 400;

  List<String> _cachedLines = [];
  int _visibleLineCount = _pageSize;
  late CssStyleResolver _cssResolver;

  @override
  void initState() {
    super.initState();
    _splitLines();
    _cssResolver = CssStyleResolver.fromHtml(widget.htmlContent);
  }

  @override
  void didUpdateWidget(covariant HtmlDocumentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent) {
      _splitLines();
      _cssResolver = CssStyleResolver.fromHtml(widget.htmlContent);
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

          // 2. Navigation Tabs (Overview & DOM / Code Source / Scripts / Styles)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(child: _buildNavTab(HtmlViewMode.overview, 'Overview & DOM', Icons.dashboard_outlined)),
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
      case HtmlViewMode.overview:
        return _buildOverviewTab();
      case HtmlViewMode.source:
        return _buildSourceTab();
      case HtmlViewMode.scripts:
        return _buildScriptsTab();
      case HtmlViewMode.styles:
        return _buildStylesTab();
    }
  }

  /// Tab 1: Overview & DOM Structure
  Widget _buildOverviewTab() {
    final info = widget.htmlInfo;

    final bodyText = info.cleanBodyHtml;
    final isBodyLong = bodyText != null && bodyText.length > 2500;
    final displayBody = isBodyLong
        ? '${bodyText.substring(0, 2500)}\n\n... [${bodyText.length - 2500} characters truncated in preview. Use \'Code Source\' or \'Open in Browser\' to view full content]'
        : bodyText;

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
                  'Extracted Clean Body Content',
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
              constraints: const BoxConstraints(maxHeight: 200),
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

  /// Tab 2: Code Source with High-Fidelity In-App CSS/HTML Render Toggle
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

    // Clean HTML content for in-app rendering
    String renderContent = (widget.htmlInfo.cleanBodyHtml != null && widget.htmlInfo.cleanBodyHtml!.isNotEmpty)
        ? widget.htmlInfo.cleanBodyHtml!
        : widget.htmlContent;

    // Filter out binary polyglot comment artifacts if present
    if (renderContent.contains('-->') && renderContent.contains('<!--')) {
      final start = renderContent.indexOf('-->');
      final end = renderContent.lastIndexOf('<!--');
      if (start != -1 && end > start) {
        renderContent = renderContent.substring(start + 3, end).trim();
      }
    }

    // Extract body & html styles for dynamic canvas container
    final bodyRules = _cssResolver.tagRules['body'] ?? _cssResolver.tagRules['html'] ?? {};
    final bodyBgColor = _cssResolver.parseColor(bodyRules['background-color'] ?? bodyRules['background']);
    final bodyTextColor = _cssResolver.parseColor(bodyRules['color']);
    final bodyFontFamilyRaw = bodyRules['font-family']?.replaceAll(RegExp(r"""['"]"""), '').split(',').first.trim();
    final isBodyCentered = bodyRules['text-align'] == 'center';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Responsive Toolbar: Render In-App Toggle, Search, Matches, Wrap & Copy
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              // In-App Render / Source Toggle Button
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _renderInApp = false),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_renderInApp ? AppTheme.primary.withAlpha(30) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.code_rounded, size: 12, color: !_renderInApp ? AppTheme.primary : AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              'Source',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: !_renderInApp ? FontWeight.bold : FontWeight.normal,
                                color: !_renderInApp ? AppTheme.textPrimary : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _renderInApp = true),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _renderInApp ? AppTheme.accent.withAlpha(30) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_rounded, size: 12, color: _renderInApp ? AppTheme.accent : AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              'Render in App',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: _renderInApp ? FontWeight.bold : FontWeight.normal,
                                color: _renderInApp ? AppTheme.accent : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!_renderInApp) ...[
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 28,
                      child: Container(
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
                            hintText: 'Search...',
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
                    if (_searchQuery.isNotEmpty)
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
              ] else ...[
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (bodyBgColor ?? AppTheme.accent).withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: (bodyBgColor ?? AppTheme.accent).withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.palette_outlined, size: 11, color: bodyBgColor ?? AppTheme.accent),
                          const SizedBox(width: 4),
                          Text(
                            bodyBgColor != null ? 'CSS Background Applied' : 'CSS3 Engine Active',
                            style: TextStyle(fontSize: 9.5, color: bodyBgColor ?? AppTheme.accent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Copy Source Code',
                      icon: const Icon(Icons.copy, size: 14, color: AppTheme.textSecondary),
                      onPressed: _copyToClipboard,
                    ),
                  ],
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // Container: Switch between In-App Rendered View or Syntax-Highlighted Source Code
          Container(
            height: 400,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _renderInApp ? (bodyBgColor ?? const Color(0xFF0D0F12)) : const Color(0xFF090B0E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle.withAlpha(50)),
            ),
            child: _renderInApp
                ? Container(
                    padding: const EdgeInsets.all(16),
                    alignment: isBodyCentered ? Alignment.topCenter : Alignment.topLeft,
                    child: SingleChildScrollView(
                      child: SelectionArea(
                        child: HtmlWidget(
                          renderContent,
                          textStyle: TextStyle(
                            fontSize: 12.5,
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
                : SelectionArea(
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
