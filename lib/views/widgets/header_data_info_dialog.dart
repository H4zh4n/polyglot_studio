import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Clean dialog explaining Header Extra Data capabilities, strict boundary limits, and inspection commands.
class HeaderDataInfoDialog extends StatelessWidget {
  const HeaderDataInfoDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const HeaderDataInfoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: const Icon(Icons.info_outline, size: 16, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Header Extra Data (Dead Space)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            letterSpacing: AppTheme.trackingTight,
                          ),
                        ),
                        Text(
                          'Byte offset 22 through 240 in the initial atom (Max 200 Bytes)',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: AppTheme.borderSubtle, height: 1),
              const SizedBox(height: 16),

              // Size Constraint Notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: AppTheme.accent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Capped strictly at 200 bytes to preserve compatible MP4 brand tables at byte 240 and the secondary ftyp box at byte 256.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Use Cases Section
              const Text(
                'What Can It Be Used For?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              _buildBullet('Custom Magic Bytes:', 'Register custom signatures for proprietary tools or game engines.'),
              _buildBullet('Watermarks & Metadata:', 'Embed tamper-evident author tags, version numbers, or commit hashes.'),
              _buildBullet('Shell Shebangs:', 'Add `#!/bin/sh` to make the polyglot executable in Linux/macOS terminals.'),
              _buildBullet('Security Research & CTFs:', 'Conceal hidden flags or routing instructions safely without corrupting players.'),

              const SizedBox(height: 16),

              // How to View Section
              const Text(
                'How to View It in the Saved File:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              _buildCodeSnippet('Polyglot Studio (Inspector)', 'Inspector tab → Select "Header Space" format chip'),
              const SizedBox(height: 6),
              _buildCodeSnippet('Windows PowerShell', 'Get-Content .\\polyglot.ico.mp4 -Encoding Byte -TotalCount 128 | Format-Hex'),
              const SizedBox(height: 6),
              _buildCodeSnippet('macOS / Linux / Bash', 'xxd -s 22 -l 64 polyglot.ico.mp4'),
              const SizedBox(height: 6),
              _buildCodeSnippet('Hex Editor (HxD, VS Code)', 'Inspect byte offset 0x16 (decimal 22) in ASCII preview'),

              const SizedBox(height: 20),

              // Close Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    backgroundColor: AppTheme.surfaceElevated,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.35),
                children: [
                  TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeSnippet(String label, String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          ),
          Expanded(
            child: SelectableText(
              code,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
