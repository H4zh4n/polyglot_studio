import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../widgets/github_link_button.dart';

/// Understated modal dialog displaying dynamic application version and package metadata.
class AboutAppDialog extends StatelessWidget {
  final String version;
  final String buildNumber;
  final String appName;

  const AboutAppDialog({
    super.key,
    required this.version,
    required this.buildNumber,
    required this.appName,
  });

  static Future<void> show(
    BuildContext context, {
    required String version,
    required String buildNumber,
    required String appName,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xCC080A0E),
      builder: (context) => AboutAppDialog(
        version: version,
        buildNumber: buildNumber,
        appName: appName,
      ),
    );
  }

  String get _platformName {
    if (kIsWeb) return 'Web (Wasm / CanvasKit)';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final fullVersion = buildNumber.isNotEmpty && buildNumber != '0' ? '$version (Build $buildNumber)' : version;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderStrong),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(200),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with logo and name
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Image.asset('assets/logo/logo_small.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appName.isNotEmpty ? appName : 'Polyglot Studio',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            letterSpacing: AppTheme.trackingTight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Cross-Platform Media Polyglot Suite',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Metadata card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('App Version', 'v$fullVersion'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: AppTheme.borderSubtle),
                    ),
                    _buildInfoRow('Platform', _platformName),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: AppTheme.borderSubtle),
                    ),
                    _buildInfoRow('Architecture', 'In-Memory RAM Pipeline'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Generates and inspects multi-format polyglot files combining valid ICO, MP4/M4A, HTML, PDF, and ZIP container payloads into a single file.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
              ),

              const SizedBox(height: 16),

              // Creator Profile & GitHub link
              const GithubLinkButton(),

              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    backgroundColor: AppTheme.surfaceElevated,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
