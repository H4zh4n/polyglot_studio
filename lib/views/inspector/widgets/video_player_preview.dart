import 'dart:io' show Directory, File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:polyglot_core/polyglot_core.dart';
import 'package:video_player/video_player.dart';
import '../../../controllers/polyglot_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/number_utils.dart';

/// Interactive Video Player and Atom Inspector for MP4, MOV, MKV, and AVI containers.
class VideoPlayerPreview extends StatefulWidget {
  final Uint8List videoBytes;
  final String fileName;
  final String format;
  final MediaMetadataInfo mediaInfo;
  final List<int> headerBytes;
  final VoidCallback? onExport;
  final bool isEmbedded;

  const VideoPlayerPreview({
    super.key,
    required this.videoBytes,
    required this.fileName,
    this.format = '.mp4',
    this.mediaInfo = const MediaMetadataInfo(),
    this.headerBytes = const [],
    this.onExport,
    this.isEmbedded = false,
  });

  @override
  State<VideoPlayerPreview> createState() => _VideoPlayerPreviewState();
}

class _VideoPlayerPreviewState extends State<VideoPlayerPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isHovering = false;
  bool _showHexDump = false;
  String? _errorMessage;
  String? _tempFilePath;
  double _playbackRate = 1.0;
  double _volume = 1.0;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.videoBytes.isEmpty) {
        throw Exception('Video stream byte buffer is empty');
      }

      if (kIsWeb) {
        final uri = Uri.dataFromBytes(widget.videoBytes, mimeType: 'video/mp4');
        _controller = VideoPlayerController.networkUrl(uri);
      } else {
        final tempDir = Directory.systemTemp;
        final ext = widget.format.replaceAll('.', '').toLowerCase();
        final cleanExt = ext.isNotEmpty ? ext : 'mp4';
        final tempFile = File(p.join(tempDir.path, 'polyglot_video_preview_${DateTime.now().millisecondsSinceEpoch}.$cleanExt'));
        await tempFile.writeAsBytes(widget.videoBytes);
        _tempFilePath = tempFile.path;

        _controller = VideoPlayerController.file(tempFile);
      }

      await _controller!.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Video decoder initialization timed out'),
      );
      _controller!.addListener(_onVideoControllerUpdate);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onVideoControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoControllerUpdate);
    _controller?.dispose();

    if (_tempFilePath != null && !kIsWeb) {
      try {
        final f = File(_tempFilePath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _seekTo(double valueSeconds) {
    if (_controller == null || !_isInitialized) return;
    final target = Duration(milliseconds: (valueSeconds * 1000).round());
    _controller!.seekTo(target);
  }

  void _toggleMute() {
    if (_controller == null) return;
    if (_isMuted) {
      _controller!.setVolume(_volume);
      setState(() => _isMuted = false);
    } else {
      _controller!.setVolume(0.0);
      setState(() => _isMuted = true);
    }
  }

  void _setVolume(double newVol) {
    if (_controller == null) return;
    setState(() {
      _volume = newVol;
      _isMuted = newVol == 0.0;
    });
    _controller!.setVolume(newVol);
  }

  void _setPlaybackRate(double rate) {
    if (_controller == null) return;
    setState(() => _playbackRate = rate);
    _controller!.setPlaybackSpeed(rate);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PolyglotController>() ? Get.find<PolyglotController>() : null;
    final info = widget.mediaInfo;
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 650;

    final content = Container(
      decoration: BoxDecoration(
        color: widget.isEmbedded ? Colors.transparent : AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: widget.isEmbedded ? null : Border.all(color: AppTheme.borderSubtle),
      ),
      padding: EdgeInsets.all(widget.isEmbedded ? 4 : (isMobile ? 8 : 14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  const Icon(Icons.videocam, size: 15, color: AppTheme.accent),
                  const Text(
                    'Interactive Video Player',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Text(
                      widget.format.toUpperCase(),
                      style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.accent),
                    ),
                  ),
                ],
              ),

              // Export Video Button
              if (widget.onExport != null || controller != null) ...[
                if (isMobile || widget.isEmbedded)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.download_outlined, size: 15, color: AppTheme.textSecondary),
                    tooltip: 'Export Video',
                    onPressed: () {
                      if (widget.onExport != null) {
                        widget.onExport!();
                      } else {
                        controller?.extractMediaFile(preferredExtension: widget.format.replaceAll('.', ''));
                      }
                    },
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceElevated,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      if (widget.onExport != null) {
                        widget.onExport!();
                      } else {
                        controller?.extractMediaFile(preferredExtension: widget.format.replaceAll('.', ''));
                      }
                    },
                    icon: const Icon(Icons.download_outlined, size: 13),
                    label: const Text('Export Video', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // 2. Video Player Viewport with Overlay Controls
          Builder(
            builder: (context) {
              final isPortrait = _isInitialized && _controller != null && _controller!.value.aspectRatio > 0 && _controller!.value.aspectRatio < 1.0;

              return Center(
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovering = true),
                  onExit: (_) => setState(() => _isHovering = false),
                  child: Container(
                    constraints: BoxConstraints(maxHeight: isPortrait ? 400 : 280, maxWidth: isPortrait ? 320 : 500),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0C10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildVideoCanvas(),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // 3. Technical Video Specs Bar
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildInfoBadge('Video Codec', info.videoCodec ?? 'H.264 / AVC1'),
              _buildInfoBadge('Audio Codec', info.audioCodec ?? 'AAC Stereo'),
              _buildInfoBadge('Size', NumberUtils.formatSizeKb(widget.videoBytes.length)),
              if (_controller != null && _isInitialized)
                _buildInfoBadge('Duration', _formatDuration(_controller!.value.duration)),
              if (_controller != null && _isInitialized && _controller!.value.size.width > 0)
                _buildInfoBadge('Resolution', '${_controller!.value.size.width.toInt()} × ${_controller!.value.size.height.toInt()}'),
              if (info.atomBoxes.isNotEmpty)
                _buildInfoBadge('Top Atoms', info.atomBoxes.take(4).join(' → ')),
            ],
          ),

          if (widget.headerBytes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => setState(() => _showHexDump = !_showHexDump),
                  icon: const Icon(Icons.code, size: 13, color: AppTheme.textSecondary),
                  label: Text(
                    _showHexDump ? 'Hide Atom Hex' : 'View Atom Hex',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            if (_showHexDump) ...[
              const SizedBox(height: 8),
              _buildHexDumpWidget(widget.headerBytes),
            ],
          ],
        ],
      ),
    );

    if (widget.isEmbedded) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: content,
      );
    }
    return content;
  }

  Widget _buildVideoCanvas() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_filter_outlined, size: 32, color: AppTheme.accent),
              SizedBox(height: 10),
              Text('Loading Video Stream...', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _controller == null || !_isInitialized) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_outlined, size: 36, color: AppTheme.accent),
            const SizedBox(height: 10),
            const Text(
              'ISOBMFF Video Stream Ready',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Dual-Brand atom container parsed at byte 256.',
              style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final val = _controller!.value;
    final totalSec = val.duration.inMilliseconds > 0 ? val.duration.inMilliseconds / 1000.0 : 1.0;
    final currentSec = (val.position.inMilliseconds / 1000.0).clamp(0.0, totalSec);

    return AspectRatio(
      aspectRatio: val.aspectRatio > 0 ? val.aspectRatio : 16 / 9,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Native Video Surface
          VideoPlayer(_controller!),

          // Click anywhere to toggle play/pause
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayPause,
              child: AnimatedOpacity(
                opacity: (!val.isPlaying || _isHovering) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x990D0F12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x44FFFFFF)),
                    ),
                    child: Icon(
                      val.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Controls Bar (Visible on Hover or when Paused)
          AnimatedOpacity(
            opacity: (!val.isPlaying || _isHovering) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xEE090B0E)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scrubber Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: AppTheme.primary,
                      inactiveTrackColor: const Color(0x44FFFFFF),
                      thumbColor: AppTheme.primary,
                    ),
                    child: Slider(
                      value: currentSec,
                      min: 0.0,
                      max: totalSec,
                      onChanged: _seekTo,
                    ),
                  ),

                  // Bottom Controls Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final isCompact = availableWidth < 300;
                      final isUltraCompact = availableWidth < 220;

                      return Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              val.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              isUltraCompact
                                  ? _formatDuration(val.position)
                                  : '${_formatDuration(val.position)} / ${_formatDuration(val.duration)}',
                              style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),

                          // Volume & Mute
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: _isMuted ? 'Unmute' : 'Mute',
                            icon: Icon(
                              _isMuted || _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              size: 15,
                              color: Colors.white70,
                            ),
                            onPressed: _toggleMute,
                          ),
                          if (!isCompact) ...[
                            SizedBox(
                              width: 44,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3.5),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 7),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: const Color(0x44FFFFFF),
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: _isMuted ? 0.0 : _volume,
                                  min: 0.0,
                                  max: 1.0,
                                  onChanged: _setVolume,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],

                          // Speed Selector
                          PopupMenuButton<double>(
                            tooltip: 'Playback Speed',
                            initialValue: _playbackRate,
                            onSelected: _setPlaybackRate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0x33FFFFFF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_playbackRate}x',
                                style: const TextStyle(fontSize: 9.0, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            itemBuilder: (context) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((rate) {
                              return PopupMenuItem<double>(
                                value: rate,
                                child: Text('${rate}x', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
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

  Widget _buildHexDumpWidget(List<int> bytes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          _formatHexDump(bytes),
          style: const TextStyle(
            fontSize: 9.5,
            fontFamily: 'monospace',
            color: AppTheme.textPrimary,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  String _formatHexDump(List<int> bytes) {
    final buffer = StringBuffer();
    final maxLen = bytes.length >= 256 ? 256 : bytes.length;

    for (int i = 0; i < maxLen; i += 16) {
      buffer.write(i.toRadixString(16).padLeft(4, '0'));
      buffer.write(': ');

      final chunk = bytes.sublist(i, (i + 16 <= maxLen) ? i + 16 : maxLen);
      for (int j = 0; j < 16; j++) {
        if (j < chunk.length) {
          buffer.write(chunk[j].toRadixString(16).padLeft(2, '0'));
          buffer.write(' ');
        } else {
          buffer.write('   ');
        }
        if (j == 7) buffer.write(' ');
      }

      buffer.write(' |');
      for (final b in chunk) {
        if (b >= 32 && b <= 126) {
          buffer.write(String.fromCharCode(b));
        } else {
          buffer.write('.');
        }
      }
      buffer.write('|\n');
    }

    return buffer.toString().trimRight();
  }
}
