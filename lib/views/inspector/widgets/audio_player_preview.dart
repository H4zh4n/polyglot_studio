import 'dart:io' show Directory, File;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:polyglot_core/polyglot_core.dart';
import 'package:video_player/video_player.dart';
import '../../../controllers/polyglot_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/number_utils.dart';

/// Highly polished, interactive Audio Player and Visualizer for MP3, AAC, WAV, and M4A.
class AudioPlayerPreview extends StatefulWidget {
  final Uint8List audioBytes;
  final String fileName;
  final String format;
  final MediaMetadataInfo mediaInfo;

  const AudioPlayerPreview({
    super.key,
    required this.audioBytes,
    required this.fileName,
    this.format = '.mp3',
    this.mediaInfo = const MediaMetadataInfo(),
  });

  @override
  State<AudioPlayerPreview> createState() => _AudioPlayerPreviewState();
}

class _AudioPlayerPreviewState extends State<AudioPlayerPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _waveAnimController;
  VideoPlayerController? _player;

  bool _isInitialized = false;
  bool _isLoading = true;
  double _volume = 1.0;
  bool _isMuted = false;
  double _playbackRate = 1.0;
  bool _isLooping = false;
  String? _errorMessage;
  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _initAudio();
  }

  Future<void> _initAudio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.audioBytes.isEmpty) {
        throw Exception('Audio stream byte buffer is empty');
      }

      if (kIsWeb) {
        final ext = widget.format.replaceAll('.', '').toLowerCase();
        final mime = (ext == 'wav') ? 'audio/wav' : (ext == 'm4a' ? 'audio/mp4' : 'audio/mpeg');
        final uri = Uri.dataFromBytes(widget.audioBytes, mimeType: mime);
        _player = VideoPlayerController.networkUrl(uri);
      } else {
        // Native desktop/mobile: write temporary cached file for reliable streaming
        final tempDir = Directory.systemTemp;
        final ext = widget.format.replaceAll('.', '').toLowerCase();
        final cleanExt = ext.isNotEmpty ? ext : 'mp3';
        final tempFile = File(p.join(tempDir.path, 'polyglot_audio_preview_${DateTime.now().millisecondsSinceEpoch}.$cleanExt'));
        await tempFile.writeAsBytes(widget.audioBytes, flush: true);
        _tempFilePath = tempFile.path;

        _player = VideoPlayerController.file(tempFile);
      }

      await _player!.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Audio decoder initialization timed out'),
      );

      _player!.addListener(_onPlayerUpdate);

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

  void _onPlayerUpdate() {
    if (!mounted || _player == null) return;
    final isPlaying = _player!.value.isPlaying;
    if (isPlaying && !_waveAnimController.isAnimating) {
      _waveAnimController.repeat();
    } else if (!isPlaying && _waveAnimController.isAnimating) {
      _waveAnimController.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    _player?.removeListener(_onPlayerUpdate);
    _player?.dispose();

    if (_tempFilePath != null && !kIsWeb) {
      try {
        final f = File(_tempFilePath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  bool get _isPlaying => _player != null && _isInitialized && _player!.value.isPlaying;

  Future<void> _togglePlayPause() async {
    if (_player == null || !_isInitialized) return;
    try {
      if (_isPlaying) {
        await _player!.pause();
      } else {
        final pos = _player!.value.position;
        final dur = _player!.value.duration;
        if (pos >= dur && dur > Duration.zero) {
          await _player!.seekTo(Duration.zero);
        }
        await _player!.play();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _seekTo(double valueSeconds) async {
    if (_player == null || !_isInitialized) return;
    final target = Duration(milliseconds: (valueSeconds * 1000).round());
    await _player!.seekTo(target);
  }

  Future<void> _toggleMute() async {
    if (_player == null) return;
    if (_isMuted) {
      await _player!.setVolume(_volume);
      setState(() => _isMuted = false);
    } else {
      await _player!.setVolume(0.0);
      setState(() => _isMuted = true);
    }
  }

  Future<void> _setVolume(double newVol) async {
    if (_player == null) return;
    setState(() {
      _volume = newVol;
      _isMuted = newVol == 0.0;
    });
    await _player!.setVolume(newVol);
  }

  Future<void> _setPlaybackRate(double rate) async {
    if (_player == null) return;
    setState(() => _playbackRate = rate);
    await _player!.setPlaybackSpeed(rate);
  }

  Future<void> _toggleLooping() async {
    if (_player == null) return;
    final nextLoop = !_isLooping;
    setState(() => _isLooping = nextLoop);
    await _player!.setLooping(nextLoop);
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
    final dur = (_player != null && _isInitialized) ? _player!.value.duration : Duration.zero;
    final pos = (_player != null && _isInitialized) ? _player!.value.position : Duration.zero;
    final totalSec = dur.inMilliseconds > 0 ? dur.inMilliseconds / 1000.0 : 1.0;
    final currentSec = (pos.inMilliseconds / 1000.0).clamp(0.0, totalSec);

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
          // 1. Top Header Row with Format Badge & Actions
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
                  const Icon(Icons.audiotrack, size: 15, color: AppTheme.accent),
                  const Text(
                    'Interactive Audio Player',
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

              // Export Audio Button
              if (controller != null) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceElevated,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    side: const BorderSide(color: AppTheme.borderSubtle),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => controller.extractMediaFile(preferredExtension: widget.format.replaceAll('.', '')),
                  icon: const Icon(Icons.download_outlined, size: 13),
                  label: const Text('Export Audio', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // 2. Animated Equalizer Visualizer Card
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1216),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: AnimatedBuilder(
              animation: _waveAnimController,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(28, (index) {
                    final isPlaying = _isPlaying;
                    double barHeight = 8.0;
                    if (isPlaying) {
                      final phase = (index / 28.0) * 2 * math.pi;
                      final t = _waveAnimController.value * 2 * math.pi;
                      final wave1 = math.sin(phase + t);
                      final wave2 = math.cos(phase * 2 - t * 1.5);
                      final norm = ((wave1 + wave2) / 2.0).abs();
                      barHeight = 10.0 + (norm * 55.0);
                    }

                    final isAccent = (index % 4 == 0);
                    return Container(
                      width: 4,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? (isAccent ? AppTheme.accent : const Color(0xFFE5E7EB))
                            : const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: isPlaying && isAccent
                            ? [
                                BoxShadow(
                                  color: AppTheme.accent.withAlpha(80),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // 3. Audio Scrubber & Timestamps
          Row(
            children: [
              Text(
                _formatDuration(pos),
                style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: AppTheme.primary,
                    inactiveTrackColor: AppTheme.surfaceElevated,
                    thumbColor: AppTheme.primary,
                    overlayColor: AppTheme.primary.withAlpha(40),
                  ),
                  child: Slider(
                    value: currentSec,
                    min: 0.0,
                    max: totalSec,
                    onChanged: (val) => _seekTo(val),
                  ),
                ),
              ),
              Text(
                _formatDuration(dur),
                style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.textMuted),
              ),
            ],
          ),

          // 4. Playback Controls Toolbar
          Row(
            children: [
              // Main Play/Pause Button
              InkWell(
                onTap: _togglePlayPause,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: _isPlaying
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withAlpha(100),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: _isLoading
                      ? const Icon(
                          Icons.hourglass_top_rounded,
                          size: 20,
                          color: Color(0xFF0D0F12),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 24,
                          color: const Color(0xFF0D0F12),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Volume & Mute Button
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _isMuted ? 'Unmute' : 'Mute',
                icon: Icon(
                  _isMuted || _volume == 0
                      ? Icons.volume_off_rounded
                      : (_volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                onPressed: _toggleMute,
              ),
              SizedBox(
                width: 70,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                    activeTrackColor: AppTheme.textSecondary,
                    inactiveTrackColor: AppTheme.surfaceElevated,
                    thumbColor: AppTheme.textSecondary,
                  ),
                  child: Slider(
                    value: _isMuted ? 0.0 : _volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) => _setVolume(val),
                  ),
                ),
              ),

              const Spacer(),

              // Loop Toggle
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _isLooping ? 'Loop: Enabled' : 'Loop: Disabled',
                icon: Icon(
                  Icons.repeat_rounded,
                  size: 16,
                  color: _isLooping ? AppTheme.accent : AppTheme.textMuted,
                ),
                onPressed: _toggleLooping,
              ),
              const SizedBox(width: 4),

              // Speed Chips
              PopupMenuButton<double>(
                tooltip: 'Playback Speed',
                initialValue: _playbackRate,
                onSelected: _setPlaybackRate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_playbackRate}x',
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, size: 12, color: AppTheme.textMuted),
                    ],
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
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0x22EF4444),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x55EF4444)),
              ),
              child: Text(
                'Playback Notice: $_errorMessage',
                style: const TextStyle(fontSize: 10, color: Color(0xFFF87171)),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 5. Technical Audio Specs Bar
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildInfoBadge('Codec', widget.mediaInfo.audioCodec ?? 'MPEG Audio / AAC'),
              _buildInfoBadge('Size', NumberUtils.formatSizeKb(widget.audioBytes.length)),
              if (dur > Duration.zero)
                _buildInfoBadge('Length', _formatDuration(dur)),
              _buildInfoBadge('Container', 'Native Media Stream'),
            ],
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
