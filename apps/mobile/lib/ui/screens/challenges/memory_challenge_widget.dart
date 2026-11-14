import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/challenge_profile.dart';
import '../../../domain/challenge/challenge_engine.dart';

class MemoryChallengeWidget extends StatefulWidget {
  final ChallengeDifficulty difficulty;
  final VoidCallback onCompleted;

  const MemoryChallengeWidget({
    super.key,
    required this.difficulty,
    required this.onCompleted,
  });

  @override
  State<MemoryChallengeWidget> createState() => _MemoryChallengeWidgetState();
}

class _MemoryChallengeWidgetState extends State<MemoryChallengeWidget> {
  late List<int> _targetSequence;
  final List<int> _playerInputs = [];
  bool _isDemonstrating = true;
  int? _activeFlashingIndex;
  String _statusMessage = 'Memorize the pattern...';

  final List<Color> _padColors = const [
    Color(0xFFFF9E1B), // Amber
    Color(0xFFE04A3A), // Crimson
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
  ];

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    _targetSequence = ChallengeEngine.generateMemorySequence(widget.difficulty);
    _playerInputs.clear();
    _playDemonstration();
  }

  Future<void> _playDemonstration() async {
    setState(() {
      _isDemonstrating = true;
      _statusMessage = 'Watch the sequence...';
      _playerInputs.clear();
    });

    await Future.delayed(const Duration(milliseconds: 600));

    for (int i = 0; i < _targetSequence.length; i++) {
      if (!mounted) return;
      setState(() {
        _activeFlashingIndex = _targetSequence[i];
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _activeFlashingIndex = null;
      });
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (mounted) {
      setState(() {
        _isDemonstrating = false;
        _statusMessage = 'Your turn! Repeat the pattern.';
      });
    }
  }

  void _onPadTapped(int index) {
    if (_isDemonstrating) return;

    _playerInputs.add(index);
    final currentStep = _playerInputs.length - 1;

    if (_targetSequence[currentStep] != index) {
      // Mistake!
      setState(() {
        _statusMessage = 'Wrong sequence! Try again.';
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _playDemonstration();
      });
      return;
    }

    if (_playerInputs.length == _targetSequence.length) {
      // Completed full sequence!
      setState(() {
        _statusMessage = 'Great job! Sequence verified.';
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        widget.onCompleted();
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _statusMessage,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _isDemonstrating
                ? AppColors.adaptive(
                    context,
                    dark: AppColors.accent,
                    light: const Color(0xFFB45309),
                  )
                : AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Input: ${_playerInputs.length} / ${_targetSequence.length}',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 24),

        // 2x2 Grid of pads
        AspectRatio(
          aspectRatio: 1.0,
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(4, (index) {
              final isLit = _activeFlashingIndex == index;
              final color = _padColors[index];

              return GestureDetector(
                onTap: () => _onPadTapped(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isLit ? color : color.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLit ? Colors.white : color.withOpacity(0.6),
                      width: isLit ? 3 : 1.5,
                    ),
                    boxShadow: isLit
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.8),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.touch_app_rounded,
                      size: 32,
                      color: isLit ? Colors.white : color.withOpacity(0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

