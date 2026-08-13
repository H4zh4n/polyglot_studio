import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player_win/video_player_win.dart';

import 'controllers/polyglot_controller.dart';
import 'theme/app_theme.dart';
import 'views/home_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isWindows) {
    WindowsVideoPlayer.registerWith();
  }
  Get.put(PolyglotController());
  runApp(const PolyglotApp());
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
      theme: AppTheme.darkTheme,
      scrollBehavior: const AppScrollBehavior(),
      home: const HomeView(),
    );
  }
}
