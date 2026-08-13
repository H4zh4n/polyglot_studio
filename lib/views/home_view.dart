import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/polyglot_controller.dart';
import '../models/app_file.dart';
import '../theme/app_theme.dart';
import 'desktop/desktop_home_view.dart';
import 'dialogs/about_app_dialog.dart';
import 'inspector/polyglot_inspector_view.dart';
import 'mobile/mobile_home_view.dart';
import 'widgets/github_link_button.dart';

/// Master responsive view that switches dynamically between Generator Studio and Header/Payload Inspector.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _isDraggingHover = false;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PolyglotController>();

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 650;

    return Obx(() {
      final mode = controller.selectedViewMode.value;
      final isAnalyzing = controller.isAnalyzingDroppedFile.value;
      final version = controller.appVersion.value;

      return Scaffold(
        appBar: AppBar(
          leadingWidth: 38,
          titleSpacing: 4,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Center(
              child: Image.asset(
                'assets/logo/logo_small.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(
                child: Text(
                  'Polyglot Studio',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: AppTheme.trackingTight),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (version.isNotEmpty) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'App Info & Build Details',
                  child: InkWell(
                    onTap: () => AboutAppDialog.show(
                      context,
                      version: controller.appVersion.value,
                      buildNumber: controller.appBuildNumber.value,
                      appName: controller.appName.value,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Text(
                        'v$version',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            // Mode Switcher Pills (Studio / Inspector) on Desktop only
            if (isWide) ...[
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavPill(
                      label: 'Studio',
                      icon: Icons.bolt,
                      isSelected: mode == 0,
                      onTap: () => controller.selectedViewMode.value = 0,
                    ),
                    const SizedBox(width: 2),
                    _buildNavPill(
                      label: 'Inspector',
                      icon: Icons.search,
                      isSelected: mode == 1,
                      onTap: () => controller.selectedViewMode.value = 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],

            // GitHub Profile Link with Avatar
            GithubLinkButton(
              isCompact: isWide,
              isIconOnly: !isWide,
              onTap: () => AboutAppDialog.show(
                context,
                version: controller.appVersion.value,
                buildNumber: controller.appBuildNumber.value,
                appName: controller.appName.value,
              ),
            ),
            const SizedBox(width: 4),

            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 16),
              tooltip: 'Reset All',
              onPressed: () => controller.reset(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: isWide
            ? null
            : Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMobileBottomNavItem(
                              label: 'Studio',
                              icon: Icons.bolt,
                              isSelected: mode == 0,
                              onTap: () => controller.selectedViewMode.value = 0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildMobileBottomNavItem(
                              label: 'Inspector',
                              icon: Icons.search,
                              isSelected: mode == 1,
                              onTap: () => controller.selectedViewMode.value = 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        body: DropTarget(
          onDragEntered: (_) => setState(() => _isDraggingHover = true),
          onDragExited: (_) => setState(() => _isDraggingHover = false),
          onDragDone: (detail) {
            setState(() => _isDraggingHover = false);
            final appFiles = detail.files.map((f) => AppFile.fromXFile(f)).toList();
            if (controller.selectedViewMode.value == 1 && appFiles.isNotEmpty) {
              controller.inspectFile(appFiles.first);
            } else {
              controller.handleDroppedFiles(appFiles);
            }
          },
          child: Stack(
            children: [
              IndexedStack(
                index: mode,
                children: [
                  // Mode 0: Generator Studio (Responsive Desktop / Mobile)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 900) {
                        return const DesktopHomeView();
                      } else {
                        return const MobileHomeView();
                      }
                    },
                  ),

                  // Mode 1: Dedicated Header & Payload Inspector
                  const PolyglotInspectorView(),
                ],
              ),

              // 1. Drag Hover Visual Indication
              if (_isDraggingHover)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accent.withAlpha(180), width: 2),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1216).withAlpha(230),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderSubtle),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 12),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.file_download_outlined, size: 20, color: AppTheme.accent),
                            SizedBox(width: 10),
                            Text(
                              'Drop files to inspect polyglot binary signatures or assign to Studio',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 2. Active File Parsing & Polyglot Detection Feedback Toast
              if (isAnalyzing)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 440),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1216).withAlpha(245),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accent.withAlpha(120), width: 1.2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: AppTheme.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Inspecting "${controller.analyzingFileName.value}"...',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  controller.analyzingStatus.value.isNotEmpty
                                      ? controller.analyzingStatus.value
                                      : 'Analyzing binary headers and scanning for polyglot layers...',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildNavPill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? Border.all(color: AppTheme.borderSubtle) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBottomNavItem({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: AppTheme.borderSubtle) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
