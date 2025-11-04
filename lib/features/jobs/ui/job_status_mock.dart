import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// ----------------------------------------------------------------------
/// DROP-IN MOCK PRODUCTION MONITOR
/// - Single video acts as progress+final.
/// - Blurs during pipeline, unblurs smoothly.
/// - At completion: seek to 0, unmute, stop looping, pause; user taps Play.
/// - Timeline highlights current step, marks completed green.
/// - No external providers or models required.
/// ----------------------------------------------------------------------

class MockJobStatusScreen extends StatefulWidget {
  const MockJobStatusScreen({
    super.key,
    required this.videoUrl,
    this.totalSteps = 10,
    this.stepInterval = const Duration(seconds: 1),
    this.initialBlur = 100.0,
  });

  /// Your single unified video URL
  final String videoUrl;

  /// Number of steps to simulate (>= 1)
  final int totalSteps;

  /// Time between steps
  final Duration stepInterval;

  /// Starting blur sigma
  final double initialBlur;

  @override
  State<MockJobStatusScreen> createState() => _MockJobStatusScreenState();
}

class _MockJobStatusScreenState extends State<MockJobStatusScreen>
    with SingleTickerProviderStateMixin {
  late final VideoPlayerController _vc;
  Timer? _timer;

  // Pipeline status
  late List<String> _statuses;
  int _idx = 0; // current status index (0..last)
  bool get _done => _statuses[_idx] == 'done';

  // Animated blur
  late AnimationController _blurCtrl;
  late Animation<double> _blurAnim;

  // Download
  double _dlProgress = 0;
  bool _downloading = false;
  File? _downloaded;

  @override
  void initState() {
    super.initState();

    _statuses = _buildStatuses(widget.totalSteps);

    // Video
    _vc = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) async {
        await _vc.setLooping(true);
        await _vc.setVolume(0); // muted during progress
        await _vc.play();
        if (mounted) setState(() {});
      });

    // Blur animation
    _blurCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _blurAnim = Tween<double>(
      begin: widget.initialBlur,
      end: widget.initialBlur,
    ).animate(CurvedAnimation(parent: _blurCtrl, curve: Curves.easeOut));

    // Simulate pipeline
    _timer = Timer.periodic(widget.stepInterval, (_) => _advance());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vc.dispose();
    _blurCtrl.dispose();
    super.dispose();
  }

  List<String> _buildStatuses(int total) {
    // Curated sequence that matches your app’s states
    // We’ll expand it to fill totalSteps (at least 7 + done)
    final base = <String>[
      'queued',
      'generating_base_video',
      'base_ready',
      'faceswap_running',
      'tts_generating',
      'lipsync_running',
      'watermarking',
      'done',
    ];
    if (total <= base.length) return base.take(total).toList();

    // If totalSteps is larger, duplicate “progress” steps before done
    final extra = total - base.length;
    final progressFill = List.filled(extra, 'generating_base_video');
    final withFill = <String>[
      ...base.take(base.length - 1),
      ...progressFill,
      'done',
    ];
    return withFill;
  }

  Future<void> _advance() async {
    if (_idx >= _statuses.length - 1) {
      // we are on 'done'
      _timer?.cancel();
      await _completePipeline();
      return;
    }

    // Move to next step
    setState(() {
      _idx += 1;
    });

    // Smoothly animate blur down toward 0
    final nextBlur =
        (widget.initialBlur -
                (widget.initialBlur / (_statuses.length - 1)) * _idx)
            .clamp(0.0, widget.initialBlur);
    _blurAnim = Tween<double>(
      begin: _blurAnim.value,
      end: nextBlur,
    ).animate(CurvedAnimation(parent: _blurCtrl, curve: Curves.easeOut));
    _blurCtrl.forward(from: 0);

    if (_statuses[_idx] == 'done') {
      _timer?.cancel();
      await _completePipeline();
    }
  }

  Future<void> _completePipeline() async {
    // Finalize: reset to start, unmute, stop looping, pause (user presses play)
    await _vc.pause();
    await _vc.seekTo(Duration.zero);
    await _vc.setLooping(false);
    await _vc.setVolume(1);
    if (mounted) setState(() {});
  }

  // Timeline helpers
  int _rank(String s) {
    const order = [
      'queued',
      'generating_base_video',
      'base_ready',
      'faceswap_running',
      'tts_generating',
      'lipsync_running',
      'watermarking',
      'done',
    ];
    final i = order.indexOf(s);
    return i < 0 ? 0 : i;
  }

  _StepState _stateFor(String tag) {
    final current = _statuses[_idx];
    if (current == tag) {
      return current == 'done' ? _StepState.done : _StepState.running;
    }
    return _rank(current) > _rank(tag) ? _StepState.done : _StepState.pending;
  }

  String _directorBlurb(String s) {
    switch (s) {
      case 'queued':
        return '🎬 Slate is up. Your scene is queued — lights, camera, vibes.';
      case 'generating_base_video':
        return '🎥 Shooting the master shot with our virtual crew. Dailies appear below.';
      case 'base_ready':
        return '✅ Base reel is in the can. Moving your star to the front with face casting.';
      case 'faceswap_running':
        return '🎭 Casting underway — applying your headshots to the hero in frame.';
      case 'tts_generating':
        return '🎙️ VO session in progress — tone, pace, presence.';
      case 'lipsync_running':
        return '🔊 ADR pass running — aligning lips & micro-expressions.';
      case 'watermarking':
        return '✨ Final color + branding pass. Prepping a streamable master.';
      case 'done':
        return '🏁 Picture lock! Your reel is ready to screen & share.';
      default:
        return '🎞️ Processing your reel...';
    }
  }

  String _statusPill(String s) {
    switch (s) {
      case 'queued':
      case 'generating_base_video':
        return 'Shooting Base 🎥';
      case 'base_ready':
        return 'Base Ready ✅';
      case 'faceswap_running':
        return 'Casting & Face Swap 🎭';
      case 'tts_generating':
        return 'Recording VO 🎙️';
      case 'lipsync_running':
        return 'ADR & Lip Sync 🔊';
      case 'watermarking':
        return 'Final Touches ✨';
      case 'done':
        return 'Picture Lock ✅';
      default:
        return s;
    }
  }

  Future<void> _togglePlay() async {
    if (_vc.value.isPlaying) {
      await _vc.pause();
    } else {
      await _vc.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _downloadFinal() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _dlProgress = 0;
    });

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/leadrole-final.mp4';
      final dio = Dio();
      await dio.download(
        widget.videoUrl,
        path,
        onReceiveProgress: (rec, total) {
          if (total > 0) {
            setState(() => _dlProgress = rec / total);
          }
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      setState(() => _downloaded = File(path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Download failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _statuses[_idx];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Production Monitor'),
      ),
      body: _vc.value.isInitialized
          ? CustomScrollView(
              slivers: [
                // Header + Director’s Log
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(statusLabel: _statusPill(current)),
                        const SizedBox(height: 12),
                        _DirectorLog(text: _directorBlurb(current)),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Blurred video (progress) → unblur at end (paused at 0)
                SliverToBoxAdapter(
                  child: _BlurredUnifiedVideo(
                    controller: _vc,
                    blurAnimation: _blurAnim,
                    isDone: _done,
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_done) ...[
                          ElevatedButton.icon(
                            onPressed: _togglePlay,
                            icon: Icon(
                              _vc.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            label: Text(
                              _vc.value.isPlaying
                                  ? 'Pause Final Video'
                                  : 'Play Final Video',
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_downloading)
                            LinearProgressIndicator(
                              value: _dlProgress,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.neon,
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _downloading
                                      ? null
                                      : _downloadFinal,
                                  icon: const Icon(Icons.download),
                                  label: Text(
                                    _downloading
                                        ? 'Downloading… ${(_dlProgress * 100).toStringAsFixed(0)}%'
                                        : 'Download MP4',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_downloaded != null)
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      OpenFilex.open(_downloaded!.path),
                                  icon: const Icon(Icons.play_circle_outline),
                                  label: const Text('Open'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.neon,
                                    side: BorderSide(
                                      color: AppColors.neon.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ] else ...[
                          _WaitingCut(status: current),
                        ],
                      ],
                    ),
                  ),
                ),

                // Timeline
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: _Timeline(
                      steps: [
                        _Step(
                          icon: '🎥',
                          title: 'Master Shot (Luma)',
                          tag: 'generating_base_video',
                          state: _stateFor('generating_base_video'),
                          blurb:
                              'We film your base scene — composition, motion, light.',
                        ),
                        _Step(
                          icon: '📤',
                          title: 'Upload Base',
                          tag: 'base_ready',
                          state: _stateFor('base_ready'),
                          blurb:
                              'We archive a stable copy for the studio preview.',
                        ),
                        _Step(
                          icon: '🎭',
                          title: 'Casting (Face Swap)',
                          tag: 'faceswap_running',
                          state: _stateFor('faceswap_running'),
                          blurb: 'Your headshot becomes the star of the scene.',
                        ),
                        _Step(
                          icon: '🎙️',
                          title: 'Voiceover (TTS)',
                          tag: 'tts_generating',
                          state: _stateFor('tts_generating'),
                          blurb: 'We record narration with tone & pacing.',
                        ),
                        _Step(
                          icon: '🔊',
                          title: 'ADR (Lip Sync)',
                          tag: 'lipsync_running',
                          state: _stateFor('lipsync_running'),
                          blurb: 'We align lips & micro-expressions to the VO.',
                        ),
                        _Step(
                          icon: '✨',
                          title: 'Final Cut (Watermark)',
                          tag: 'watermarking',
                          state: _stateFor('watermarking'),
                          blurb: 'Tasteful branding + fast-start export.',
                        ),
                        _Step(
                          icon: '🏁',
                          title: 'Picture Lock',
                          tag: 'done',
                          state: _stateFor('done'),
                          blurb: 'Your reel is ready to screen & share.',
                        ),
                      ],
                    ),
                  ),
                ),

                // Final actions
              ],
            )
          : const _LoadingState(),
    );
  }
}

/// ---------------------- UI Pieces ----------------------

class _Header extends StatelessWidget {
  final String statusLabel;
  const _Header({required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Director’s Monitor',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.neon.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.neon.withOpacity(0.45)),
          ),
          child: Text(statusLabel, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _DirectorLog extends StatelessWidget {
  final String text;
  const _DirectorLog({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neon.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

/// One player used for progress and final.
/// Blur animates down to 0; when done, video is paused at 0 and unmuted.
class _BlurredUnifiedVideo extends StatelessWidget {
  final VideoPlayerController controller;
  final Animation<double> blurAnimation;
  final bool isDone;

  const _BlurredUnifiedVideo({
    required this.controller,
    required this.blurAnimation,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final ar = controller.value.aspectRatio == 0
        ? (9 / 16)
        : controller.value.aspectRatio;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: AnimatedBuilder(
          animation: blurAnimation,
          builder: (context, child) {
            return AspectRatio(
              aspectRatio: ar,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.neon.withOpacity(0.25)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: blurAnimation.value,
                        sigmaY: blurAnimation.value,
                      ),
                      child: VideoPlayer(controller),
                    ),
                    if (!isDone)
                      const Positioned(
                        bottom: 8,
                        right: 8,
                        child: _Badge(text: 'Preview (blurred, muted)'),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

enum _StepState { pending, running, done }

class _Step {
  final String icon;
  final String title;
  final String tag;
  final _StepState state;
  final String blurb;

  _Step({
    required this.icon,
    required this.title,
    required this.tag,
    required this.state,
    required this.blurb,
  });
}

class _Timeline extends StatelessWidget {
  final List<_Step> steps;
  const _Timeline({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neon.withOpacity(0.2)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: steps.length,
        separatorBuilder: (_, __) => Divider(color: Colors.white10, height: 20),
        itemBuilder: (_, i) => _TimelineRow(step: steps[i]),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _Step step;
  const _TimelineRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final Color dotColor = switch (step.state) {
      _StepState.pending => Colors.white24,
      _StepState.running => AppColors.neon,
      _StepState.done => Colors.greenAccent,
    };

    final Widget trail = switch (step.state) {
      _StepState.running => const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
      _StepState.done => const Icon(
        Icons.check_circle,
        color: Colors.greenAccent,
        size: 18,
      ),
      _StepState.pending => const SizedBox.shrink(),
    };

    final String sub = switch (step.state) {
      _StepState.pending => 'In queue...',
      _StepState.running => 'Rolling...',
      _StepState.done => 'Wrapped.',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // dot
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        // titles
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${step.icon}  ${step.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  trail,
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${step.blurb}  $sub',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaitingCut extends StatelessWidget {
  final String status;
  const _WaitingCut({required this.status});

  @override
  Widget build(BuildContext context) {
    final txt = switch (status) {
      'queued' => 'Queued on the call sheet...',
      'generating_base_video' => 'Shooting base plates...',
      'faceswap_running' => 'Casting your star into the scene...',
      'tts_generating' => 'Recording voiceover...',
      'lipsync_running' => 'ADR session in progress...',
      'watermarking' => 'Final polish...',
      _ => 'Working...',
    };
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.neon.withOpacity(0.08),
        border: Border.all(color: AppColors.neon.withOpacity(0.25)),
      ),
      child: Text(txt, style: const TextStyle(color: Colors.white70)),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          SizedBox(height: 40),
          CupertinoActivityIndicator(radius: 16, color: Colors.white70),
          SizedBox(height: 12),
          Text(
            'Queuing production status...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'In-Depth Details will be available shortly.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal color shim. Remove if you already have AppColors.
class AppColors {
  static const bgDark = Color(0xFF181818);
  static const neon = Color(0xFFD7F76D);
}
