import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/seren_relaxation_models.dart';
import '../../providers/seren_relaxation_provider.dart';

/// Passive, low-GPU 2D ambient visual canvas for Seren Relaxation (Features E & F).
/// Automatically pauses animation ticks when [lowMotion] is enabled or when
/// [playbackMode] is [RelaxationPlaybackMode.audioOnly].
class SerenVisualCanvas extends StatefulWidget {
  final VisualEnvironmentScene scene;
  final bool lowMotion;
  final double height;
  final BorderRadius? borderRadius;
  final Widget? overlayChild;

  const SerenVisualCanvas({
    super.key,
    required this.scene,
    this.lowMotion = false,
    this.height = 190,
    this.borderRadius,
    this.overlayChild,
  });

  @override
  State<SerenVisualCanvas> createState() => _SerenVisualCanvasState();
}

class _SerenVisualCanvasState extends State<SerenVisualCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (!widget.lowMotion) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SerenVisualCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lowMotion != oldWidget.lowMotion) {
      if (widget.lowMotion) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _SerenScenePainter(
                scene: widget.scene,
                phase: widget.lowMotion ? 0.35 : _controller.value,
                lowMotion: widget.lowMotion,
              ),
              child: widget.overlayChild,
            );
          },
        ),
      ),
    );
  }
}

class _SerenScenePainter extends CustomPainter {
  final VisualEnvironmentScene scene;
  final double phase;
  final bool lowMotion;

  _SerenScenePainter({
    required this.scene,
    required this.phase,
    required this.lowMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: scene.gradientColors,
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final particlePaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (scene.id) {
      case 'rainyWindow':
        strokePaint.color = scene.accentParticleColor.withValues(alpha: 0.28);
        strokePaint.strokeWidth = 1.4;
        for (int i = 0; i < 22; i++) {
          final seed = (i * 37) % 100 / 100.0;
          final x = (seed * size.width);
          final yProgress = (phase * 1.5 + (i * 0.13)) % 1.0;
          final y = yProgress * size.height;
          canvas.drawLine(
            Offset(x, y),
            Offset(x - 4, y + 18),
            strokePaint,
          );
        }
        break;

      case 'oceanSunset':
      case 'moonlitLake':
        // Horizon glow orb
        particlePaint.color = scene.accentParticleColor.withValues(alpha: 0.22);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.36),
          size.height * 0.22,
          particlePaint,
        );
        // Gentle waves
        for (int w = 0; w < 3; w++) {
          final path = Path();
          final baseY = size.height * (0.62 + w * 0.11);
          path.moveTo(0, baseY);
          for (double x = 0; x <= size.width; x += 16) {
            final wave = sin((x / size.width * 2 * pi) +
                    (phase * 2 * pi) +
                    (w * 1.1)) *
                (6.0 + w * 2.0);
            path.lineTo(x, baseY + wave);
          }
          path.lineTo(size.width, size.height);
          path.lineTo(0, size.height);
          path.close();
          particlePaint.color =
              scene.accentParticleColor.withValues(alpha: 0.08 + w * 0.04);
          canvas.drawPath(path, particlePaint);
        }
        break;

      case 'starrySky':
      case 'forestFireflies':
        final count = scene.id == 'forestFireflies' ? 16 : 26;
        for (int i = 0; i < count; i++) {
          final fx = ((i * 53) % 97) / 97.0 * size.width;
          final fyBase = ((i * 71) % 89) / 89.0 * size.height;
          final drift = scene.id == 'forestFireflies'
              ? sin(phase * 2 * pi + i) * 8.0
              : 0.0;
          final pulse = 0.25 + 0.55 * (0.5 + 0.5 * sin(phase * 2 * pi + i * 0.9));
          particlePaint.color =
              scene.accentParticleColor.withValues(alpha: pulse * 0.65);
          final radius = scene.id == 'forestFireflies' ? 3.2 : 1.8;
          canvas.drawCircle(Offset(fx, fyBase + drift), radius, particlePaint);
        }
        break;

      case 'morningSunrise':
      case 'sunlitCanopy':
        // Soft sun rays
        particlePaint.color = scene.accentParticleColor.withValues(alpha: 0.18);
        final sunY = size.height * (0.55 - 0.12 * sin(phase * pi));
        canvas.drawCircle(
          Offset(size.width * 0.5, sunY),
          size.height * 0.28,
          particlePaint,
        );
        break;

      case 'underwaterSanctuary':
        for (int i = 0; i < 14; i++) {
          final bx = ((i * 43) % 95) / 95.0 * size.width;
          final byProgress = 1.0 - ((phase + i * 0.11) % 1.0);
          final by = byProgress * size.height;
          particlePaint.color = scene.accentParticleColor.withValues(alpha: 0.24);
          canvas.drawCircle(
            Offset(bx + sin(phase * 2 * pi + i) * 5, by),
            2.5 + (i % 4),
            particlePaint,
          );
        }
        break;

      default:
        // Soft drifting clouds / forest mist circles
        for (int i = 0; i < 6; i++) {
          final cx = ((phase * 0.4 + i * 0.2) % 1.2 - 0.1) * size.width;
          final cy = size.height * (0.25 + (i % 3) * 0.22);
          particlePaint.color = scene.accentParticleColor.withValues(alpha: 0.12);
          canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, cy), width: 110, height: 38),
            particlePaint,
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SerenScenePainter oldDelegate) {
    return oldDelegate.scene.id != scene.id ||
        oldDelegate.lowMotion != lowMotion ||
        (!lowMotion && oldDelegate.phase != phase);
  }
}

/// Distraction-free Fullscreen Sanctuary Player (Features E & F).
class SerenFullscreenVisualPlayer extends StatelessWidget {
  const SerenFullscreenVisualPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<SerenRelaxationProvider>(
      builder: (context, provider, _) {
        final scene = provider.activeVisualScene;
        final isAudioOnly =
            provider.playbackMode == RelaxationPlaybackMode.audioOnly;

        return Scaffold(
          backgroundColor: const Color(0xFF090A0F),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (!isAudioOnly)
                SerenVisualCanvas(
                  scene: scene,
                  lowMotion: provider.lowMotionVisuals,
                  height: MediaQuery.of(context).size.height,
                  borderRadius: BorderRadius.zero,
                )
              else
                Container(
                  color: const Color(0xFF090A0F),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.headphones_rounded,
                        size: 56,
                        color: Color(0xFFA78BFA),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.tr('seren_playback_audio_only'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.tr('seren_audio_only_screen_off_hint'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              // Minimal Top & Bottom Controls Overlay
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  scene.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  scene.subtitle,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.fullscreen_exit_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: l10n.tr('close'),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Mode Selector Pills
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: RelaxationPlaybackMode.values.map((mode) {
                          final selected = provider.playbackMode == mode;
                          return ChoiceChip(
                            label: Text(mode.label),
                            selected: selected,
                            selectedColor: const Color(0xFF8B5CF6),
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.45),
                            labelStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) => provider.setPlaybackMode(mode),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Bottom Playback Strip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => provider.toggleMixerPlayback(),
                              icon: Icon(
                                provider.isMixerPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                                color: const Color(0xFFA78BFA),
                                size: 36,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    provider.isMixerPlaying
                                        ? l10n.tr('seren_soundscape_playing')
                                        : l10n.tr('seren_soundscape_paused'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (provider.isTimerActive)
                                    Text(
                                      '${l10n.tr('seren_sleep_timer')}: ${provider.formattedTimerRemaining}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            FilterChip(
                              label: Text(
                                l10n.tr('seren_low_motion'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                              selected: provider.lowMotionVisuals,
                              selectedColor: const Color(0xFF8B5CF6),
                              backgroundColor: Colors.white12,
                              onSelected: (v) => provider.setLowMotionVisuals(v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
