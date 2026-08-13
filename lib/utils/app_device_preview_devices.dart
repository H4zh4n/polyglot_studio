import 'package:device_preview/device_preview.dart';

/// Configured device presets for DevicePreview.
class AppDevicePreviewDevices {
  AppDevicePreviewDevices._();

  /// All supported device preview configurations.
  static List<DeviceInfo> get all => Devices.all;
}
