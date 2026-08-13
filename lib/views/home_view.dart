import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/polyglot_controller.dart';
import '../models/app_file.dart';
import '../theme/app_theme.dart';
import 'desktop/desktop_home_view.dart';
import 'inspector/polyglot_inspector_view.dart';
import 'mobile/mobile_home_view.dart';

/// Master responsive view that switches dynamically between Generator Studio and Header/Payload Inspector.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PolyglotController>();

    return Obx(() {
      final mode = controller.selectedViewMode.value;

      return Scaffold(
        appBar: AppBar(
          leadingWidth: 44,
          leading: Padding(
            padding: const EdgeInsets.only(left: 10.0),
            child: Center(
              child: Image.asset(
                'assets/logo/logo_small.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
              ),
            ),
          ),
          title: const Text(
            'Beheader Polyglot',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: AppTheme.trackingTight),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // Mode Switcher Pills (Studio / Inspector)
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
        body: DropTarget(
          onDragDone: (detail) {
            final appFiles = detail.files.map((f) => AppFile.fromXFile(f)).toList();
            if (controller.selectedViewMode.value == 1 && appFiles.isNotEmpty) {
              controller.inspectFile(appFiles.first);
            } else {
              controller.handleDroppedFiles(appFiles);
            }
          },
          child: IndexedStack(
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
}
