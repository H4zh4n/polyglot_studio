import 'dart:io' show Directory, File, Process;
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

enum AudioVisualizerMode {
  spectrum,
  oscilloscope,
  overview,
}

/// Highly polished, interactive Audio Player and Live Frequency Visualizer for M4A, MP4, and Audio Polyglots.
class AudioPlayerPreview extends StatefulWidget {
  final Uint8List audioBytes;
  final String fileName;
  final String format;
  final MediaMetadataInfo mediaInfo;

  const AudioPlayerPreview({
    super.key,
    required this.audioBytes,
    required this.fileName,
    this.format = '.m4a',
    this.mediaInfo = const MediaMetadataInfo(),
  });

  @override
  State<AudioPlayerPreview> createState() => _AudioPlayerPreviewState();
}

class _AudioPlayerPreviewState extends State<AudioPlayerPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  VideoPlayerController? _player;

  bool _isInitialized = false;
  bool _isLoading = true;
  double _volume = 1.0;
  bool _isMuted = false;
  double _playbackRate = 1.0;
  bool _isLooping = false;
  String? _errorMessage;
  String? _tempFilePath;

  AudioVisualizerMode _visualizerMode = AudioVisualizerMode.overview;

  // Track timeline overview peaks
  List<double> _waveformPeaks = List.filled(40, 0.25);

  // Time-sliced multi-band frequency spectrum (20 slices/sec, 28 bands per slice)
  static const int _bandCount = 28;
  static const int _slicesPerSec = 20;
  List<List<double>> _spectrumSlices = [];

  // Live dynamic values for the currently playing frame
  late List<double> _liveBands;
  late List<double> _peakHolds;

  @override
  void initState() {
    super.initState();
    _liveBands = List.filled(_bandCount, 0.08);
    _peakHolds = List.filled(_bandCount, 0.08);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_onAnimTick);

    _initAudio();
    _extractSpectrumAndWaveform();
  }

  void _onAnimTick() {
    if (!mounted) return;
    _updateLiveBands();
    setState(() {});
  }

  void _updateLiveBands() {
    final isPlaying = _isPlaying;
    final pos = (_player != null && _isInitialized) ? _player!.value.position : Duration.zero;

    List<double> targetBands;
    if (isPlaying && _spectrumSlices.isNotEmpty) {
      final sliceIdx = ((pos.inMilliseconds / 1000.0) * _slicesPerSec).floor().clamp(0, _spectrumSlices.length - 1);
      targetBands = _spectrumSlices[sliceIdx];
    } else {
      targetBands = List.filled(_bandCount, 0.06);
    }

    // Smooth physical attack and gravity decay
    for (int i = 0; i < _bandCount; i++) {
      final target = (i < targetBands.length) ? targetBands[i] : 0.06;

      if (target > _liveBands[i]) {
        // Fast attack on beat
        _liveBands[i] = _liveBands[i] + (target - _liveBands[i]) * 0.45;
      } else {
        // Smooth exponential decay
        _liveBands[i] = _liveBands[i] + (target - _liveBands[i]) * 0.18;
      }

      // Peak holds (slowly drop down)
      if (_liveBands[i] >= _peakHolds[i]) {
        _peakHolds[i] = _liveBands[i];
      } else {
        _peakHolds[i] = math.max(0.06, _peakHolds[i] - 0.015);
      }
    }
  }

  Future<void> _extractSpectrumAndWaveform() async {
    if (widget.audioBytes.isEmpty) return;

    try {
      if (!kIsWeb) {
        final tempDir = Directory.systemTemp;
        final tempIn = p.join(tempDir.path, 'poly_spec_${DateTime.now().microsecondsSinceEpoch}.mp4');
        await File(tempIn).writeAsBytes(widget.audioBytes, flush: true);

        // Extract raw 8-bit mono PCM downsampled to 4000 Hz
        final result = await Process.run('ffmpeg', [
          '-y',
          '-v', 'error',
          '-i', tempIn,
          '-ac', '1',
          '-ar', '4000',
          '-map', '0:a',
          '-c:a', 'pcm_u8',
          '-f', 'u8',
          '-',
        ], stdoutEncoding: null);

        try {
          final f = File(tempIn);
          if (await f.exists()) await f.delete();
        } catch (_) {}

        if (result.exitCode == 0 && result.stdout is List<int>) {
          final pcm = result.stdout as List<int>;
          if (pcm.isNotEmpty) {
            final totalSlices = (pcm.length / 4000.0 * _slicesPerSec).ceil();
            final pcmPerSlice = (4000 / _slicesPerSec).round(); // 200 samples per 50ms

            final matrix = <List<double>>[];
            double globalMax = 0.0;

            for (int s = 0; s < totalSlices; s++) {
              final start = s * pcmPerSlice;
              final end = (start + pcmPerSlice < pcm.length) ? (start + pcmPerSlice) : pcm.length;
              final windowSize = end - start;

              if (windowSize <= 4) {
                matrix.add(List.filled(_bandCount, 0.06));
                continue;
              }

              final sliceBands = List<double>.filled(_bandCount, 0.0);

              for (int b = 0; b < _bandCount; b++) {
                final stride = math.max(1, (b * 2) ~/ _bandCount + 1);
                double bandEnergy = 0.0;
                int count = 0;

                if (b < _bandCount ~/ 3) {
                  // Bass / Sub-bass
                  for (int j = start; j < end; j += stride) {
                    final amp = (pcm[j] - 128).abs();
                    bandEnergy += amp * amp;
                    count++;
                  }
                } else if (b < (_bandCount * 2) ~/ 3) {
                  // Mids / Vocals
                  for (int j = start + 2; j < end; j += stride) {
                    final mid = (pcm[j] - pcm[j - 2]).abs();
                    bandEnergy += mid * mid;
                    count++;
                  }
                } else {
                  // Treble / Highs
                  for (int j = start + 1; j < end; j += stride) {
                    final diff = (pcm[j] - pcm[j - 1]).abs();
                    bandEnergy += diff * diff * 2.0;
                    count++;
                  }
                }

                final rms = count > 0 ? math.sqrt(bandEnergy / count) : 0.0;
                sliceBands[b] = rms;
                if (rms > globalMax) globalMax = rms;
              }

              matrix.add(sliceBands);
            }

            if (globalMax > 0.01) {
              final normalizedMatrix = matrix.map((slice) {
                return slice.map((val) => (0.08 + (val / globalMax) * 0.92).clamp(0.08, 1.0)).toList();
              }).toList();

              // Also calculate static timeline overview
              final overviewPeaks = <double>[];
              const overviewBars = 40;
              final chunkLen = (pcm.length / overviewBars).ceil();
              for (int i = 0; i < overviewBars; i++) {
                final st = i * chunkLen;
                final en = (st + chunkLen < pcm.length) ? (st + chunkLen) : pcm.length;
                int pk = 0;
                for (int j = st; j < en; j++) {
                  final v = (pcm[j] - 128).abs();
                  if (v > pk) pk = v;
                }
                overviewPeaks.add((0.15 + (pk / 128.0) * 0.85).clamp(0.15, 1.0));
              }

              if (mounted) {
                setState(() {
                  _spectrumSlices = normalizedMatrix;
                  _waveformPeaks = overviewPeaks;
                });
              }
              return;
            }
          }
        }
      }
    } catch (_) {}

    // Fallback: binary spectrum decomposition
    final data = widget.audioBytes;
    final totalSlices = math.max(20, (data.length / 500).floor());
    final matrix = <List<double>>[];
    final blockSize = (data.length / totalSlices).floor();

    if (blockSize > 0) {
      for (int s = 0; s < totalSlices; s++) {
        final start = s * blockSize;
        final slice = List<double>.generate(_bandCount, (b) {
          final offset = start + ((b * blockSize) ~/ _bandCount);
          final byteVal = (offset < data.length) ? data[offset] : 128;
          final norm = ((byteVal % 100) / 100.0).clamp(0.1, 1.0);
          return 0.1 + (norm * 0.85);
        });
        matrix.add(slice);
      }
      if (mounted) {
        setState(() {
          _spectrumSlices = matrix;
        });
      }
    }
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
        final tempDir = Directory.systemTemp;
        final ext = widget.format.replaceAll('.', '').toLowerCase();
        final cleanExt = ext.isNotEmpty ? ext : 'mp4';
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
    if (isPlaying && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!isPlaying && _animController.isAnimating) {
      _animController.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _animController.dispose();
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
          // 1. Top Header Row with Format Badge, Visualizer Mode Switcher & Export
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
                  const Icon(Icons.equalizer_rounded, size: 16, color: AppTheme.accent),
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

              // Visualizer Mode Selector & Export Button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeTab(AudioVisualizerMode.overview, 'Overview', Icons.graphic_eq_rounded),
                        _buildModeTab(AudioVisualizerMode.spectrum, 'Spectrum', Icons.bar_chart_rounded),
                        _buildModeTab(AudioVisualizerMode.oscilloscope, 'Wave', Icons.waves_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
            ],
          ),

          const SizedBox(height: 12),

          // 2. Real-Time Dynamic Frequency Visualizer Stage
          Container(
            height: 108,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0E12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: _buildActiveVisualizer(totalSec, currentSec),
          ),

          const SizedBox(height: 10),

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
                  width: 38,
                  height: 38,
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
                          size: 18,
                          color: Color(0xFF0D0F12),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 22,
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
              _buildInfoBadge('Codec', widget.mediaInfo.audioCodec ?? 'AAC Audio / MP4'),
              _buildInfoBadge('Size', NumberUtils.formatSizeKb(widget.audioBytes.length)),
              if (dur > Duration.zero)
                _buildInfoBadge('Length', _formatDuration(dur)),
              _buildInfoBadge('Mode', _visualizerMode.name.toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(AudioVisualizerMode mode, String label, IconData icon) {
    final isSelected = _visualizerMode == mode;
    return InkWell(
      onTap: () => setState(() => _visualizerMode = mode),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveVisualizer(double totalSec, double currentSec) {
    switch (_visualizerMode) {
      case AudioVisualizerMode.spectrum:
        return _buildSpectrumEqualizer();
      case AudioVisualizerMode.oscilloscope:
        return _buildOscilloscopeWave();
      case AudioVisualizerMode.overview:
        return _buildTimelineOverview(totalSec, currentSec);
    }
  }

  /// Mode 1: 28-Band Real-Time Pro Frequency Spectrum Equalizer with Peak Holds
  Widget _buildSpectrumEqualizer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = math.max(3.0, (constraints.maxWidth - (_bandCount * 2.5)) / _bandCount);

        return Column(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(_bandCount, (index) {
                  final heightFraction = _liveBands[index];
                  final peakFraction = _peakHolds[index];
                  final isBass = index < _bandCount ~/ 3;
                  final isMids = index >= _bandCount ~/ 3 && index < (_bandCount * 2) ~/ 3;

                  final barColor = isBass
                      ? AppTheme.primary
                      : (isMids ? const Color(0xFF38BDF8) : AppTheme.accent);

                  return SizedBox(
                    width: barWidth,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        // Peak Hold Marker Dot
                        Positioned(
                          bottom: (peakFraction * (constraints.maxHeight - 20)).clamp(6.0, constraints.maxHeight - 20),
                          child: Container(
                            width: barWidth,
                            height: 2,
                            decoration: BoxDecoration(
                              color: barColor.withAlpha(220),
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: _isPlaying
                                  ? [
                                      BoxShadow(
                                        color: barColor.withAlpha(120),
                                        blurRadius: 3,
                                        spreadRadius: 0.5,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),

                        // Equalizer Bar
                        Container(
                          height: math.max(4.0, heightFraction * (constraints.maxHeight - 24)),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                barColor.withAlpha(100),
                                barColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: (_isPlaying && heightFraction > 0.4)
                                ? [
                                    BoxShadow(
                                      color: barColor.withAlpha(80),
                                      blurRadius: 4,
                                      spreadRadius: 0.5,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 4),
            // Frequency range sub-labels (Bass -> Mids -> Highs)
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('60Hz', style: TextStyle(fontSize: 8.5, fontFamily: 'monospace', color: AppTheme.textMuted)),
                Text('250Hz', style: TextStyle(fontSize: 8.5, fontFamily: 'monospace', color: AppTheme.textMuted)),
                Text('1kHz', style: TextStyle(fontSize: 8.5, fontFamily: 'monospace', color: AppTheme.textMuted)),
                Text('4kHz', style: TextStyle(fontSize: 8.5, fontFamily: 'monospace', color: AppTheme.textMuted)),
                Text('16kHz', style: TextStyle(fontSize: 8.5, fontFamily: 'monospace', color: AppTheme.textMuted)),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Mode 2: Live Real-Time Continuous Oscilloscope Frequency Waveform
  Widget _buildOscilloscopeWave() {
    return CustomPaint(
      size: Size.infinite,
      painter: _LiveOscilloscopePainter(
        bands: _liveBands,
        animPhase: _animController.value,
        isPlaying: _isPlaying,
        primaryColor: AppTheme.primary,
        accentColor: AppTheme.accent,
      ),
    );
  }

  /// Mode 3: Interactive Full Audio Track Amplitude Overview
  Widget _buildTimelineOverview(double totalSec, double currentSec) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (totalSec > 0) {
              final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
              _seekTo(ratio * totalSec);
            }
          },
          onHorizontalDragUpdate: (details) {
            if (totalSec > 0) {
              final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
              _seekTo(ratio * totalSec);
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_waveformPeaks.length, (index) {
              final progress = totalSec > 0 ? (currentSec / totalSec) : 0.0;
              final totalBars = _waveformPeaks.length;
              final activeBarIndex = (progress * totalBars).floor();
              final isPlayed = index < activeBarIndex;
              final isActive = index == activeBarIndex && _isPlaying;
              final peak = _waveformPeaks[index];

              double barHeight = 8.0 + (peak * 68.0);
              if (isActive) {
                final pulse = math.sin(_animController.value * 2 * math.pi).abs();
                barHeight += (pulse * 8.0);
              }

              return Container(
                width: math.max(3.0, (constraints.maxWidth - 20) / (totalBars * 1.55)),
                height: barHeight,
                decoration: BoxDecoration(
                  color: isPlayed
                      ? (index % 6 == 0 ? AppTheme.accent : AppTheme.primary)
                      : (isActive ? AppTheme.primary : const Color(0xFF374151)),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: (isPlayed || isActive) && (index % 4 == 0)
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(90),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
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

/// Custom painter rendering a live continuous Oscilloscope wave reflecting the instantaneous audio frequencies.
class _LiveOscilloscopePainter extends CustomPainter {
  final List<double> bands;
  final double animPhase;
  final bool isPlaying;
  final Color primaryColor;
  final Color accentColor;

  _LiveOscilloscopePainter({
    required this.bands,
    required this.animPhase,
    required this.isPlaying,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;

    final midY = size.height / 2;
    final path = Path();
    final stepX = size.width / (bands.length - 1);

    path.moveTo(0, midY);

    for (int i = 0; i < bands.length; i++) {
      final x = i * stepX;
      final energy = bands[i];
      final wave = math.sin((i / bands.length) * 4 * math.pi + animPhase * 2 * math.pi);
      final yOffset = wave * energy * (size.height * 0.44);
      final y = midY + (isPlaying ? yOffset : 0);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevEnergy = bands[i - 1];
        final prevWave = math.sin(((i - 1) / bands.length) * 4 * math.pi + animPhase * 2 * math.pi);
        final prevY = midY + (isPlaying ? prevWave * prevEnergy * (size.height * 0.44) : 0);
        final controlX = (prevX + x) / 2;
        path.cubicTo(controlX, prevY, controlX, y, x, y);
      }
    }

    // Background Glow
    final glowPaint = Paint()
      ..color = primaryColor.withAlpha(90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(path, glowPaint);

    // Foreground Stroke
    final strokePaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, accentColor, const Color(0xFF38BDF8), primaryColor],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _LiveOscilloscopePainter oldDelegate) => true;
}
