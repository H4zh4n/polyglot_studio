import 'dart:io' show Platform;
import 'dart:ui';

import 'package:device_preview_screenshot/device_preview_screenshot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player_win/video_player_win.dart';

import 'controllers/polyglot_controller.dart';
import 'theme/app_theme.dart';
import 'utils/app_device_preview_devices.dart';
import 'utils/screenshot_utils.dart';
import 'views/home_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isWindows) {
    WindowsVideoPlayer.registerWith();
  }
  Get.put(PolyglotController());
  runApp(
    DevicePreview(
      enabled: kDebugMode,
      devices: AppDevicePreviewDevices.all,
      tools: [
        ...DevicePreview.defaultTools,
        DevicePreviewScreenshot(onScreenshot: ScreenshotUtils.handleScreenshot),
      ],
      builder: (context) => const PolyglotApp(),
    ),
  );
}

/// Global scroll behavior enabling mouse click-and-drag scrolling across all list views and scrollables.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
}

class PolyglotApp extends StatelessWidget {
  const PolyglotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Polyglot Studio',
      debugShowCheckedModeBanner: false,
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: AppTheme.darkTheme,
      scrollBehavior: const AppScrollBehavior(),
      home: const HomeView(),
    );
  }
}

