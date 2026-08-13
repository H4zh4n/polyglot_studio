import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

/// Interactive button displaying GitHub profile avatar and link to https://github.com/H4zh4n
class GithubLinkButton extends StatelessWidget {
  static const String githubUrl = 'https://github.com/H4zh4n';
  static const String avatarUrl = 'https://github.com/H4zh4n.png';
  static const String username = 'H4zh4n';

  final bool isCompact;
  final bool isIconOnly;
  final VoidCallback? onTap;

  const GithubLinkButton({
    super.key,
    this.isCompact = false,
    this.isIconOnly = false,
    this.onTap,
  });

  static Future<void> launch() async {
    final uri = Uri.parse(githubUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handleTap = onTap ?? launch;

    if (isIconOnly) {
      return Tooltip(
        message: 'App Info & Author (@$username)',
        child: InkWell(
          onTap: handleTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
            child: _buildAvatar(size: 18),
          ),
        ),
      );
    }

    if (isCompact) {
      return Tooltip(
        message: 'App Info & Author (@$username)',
        child: InkWell(
          onTap: handleTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(size: 18),
                const SizedBox(width: 6),
                const Text(
                  username,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.open_in_new,
                  size: 11,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: launch,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Row(
          children: [
            _buildAvatar(size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Created by $username',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'github.com/$username',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new,
              size: 14,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.surface,
            child: Icon(Icons.person, size: size * 0.65, color: AppTheme.textMuted),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: AppTheme.surface,
              child: Center(
                child: SizedBox(
                  width: size * 0.5,
                  height: size * 0.5,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
