import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/challenge_profile.dart';
import '../../../domain/challenge/challenge_engine.dart';

class MathChallengeWidget extends StatefulWidget {
  final ChallengeDifficulty difficulty;
  final int totalQuestions;
  final VoidCallback onCompleted;

  const MathChallengeWidget({
    super.key,
    required this.difficulty,
    required this.totalQuestions,
    required this.onCompleted,
  });

  @override
  State<MathChallengeWidget> createState() => _MathChallengeWidgetState();
}

class _MathChallengeWidgetState extends State<MathChallengeWidget> {
  int _currentQuestionIndex = 0;
  late MathQuestion _currentQuestion;
  String _inputBuffer = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNextQuestion();
  }

  void _loadNextQuestion() {
    setState(() {
      _currentQuestion = ChallengeEngine.generateMathQuestion(widget.difficulty);
      _inputBuffer = '';
      _errorMessage = null;
    });
  }

  void _appendDigit(String digit) {
    if (_inputBuffer.length >= 6) return;
    setState(() {
      _inputBuffer += digit;
      _errorMessage = null;
    });
  }

  void _deleteDigit() {
    if (_inputBuffer.isNotEmpty) {
      setState(() {
        _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _submitAnswer() {
    if (_inputBuffer.isEmpty) return;
    final parsed = int.tryParse(_inputBuffer);
    if (parsed == _currentQuestion.correctAnswer) {
      if (_currentQuestionIndex + 1 >= widget.totalQuestions) {
        widget.onCompleted();
      } else {
        setState(() {
          _currentQuestionIndex++;
        });
        _loadNextQuestion();
      }
    } else {
      setState(() {
        _errorMessage = 'Incorrect answer! Try again.';
        _inputBuffer = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentQuestionIndex + 1} of ${widget.totalQuestions}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.adaptive(
                  context,
                  dark: AppColors.accent,
                  light: const Color(0xFFB45309),
                ),
              ),
            ),
            Text(
              widget.difficulty.name.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / widget.totalQuestions,
            backgroundColor: AppColors.trackSurface(context),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 24),

        // Problem Card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            children: [
              Text(
                _currentQuestion.questionText,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.recessedSurface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _errorMessage != null
                        ? AppColors.error
                        : AppColors.accent.withValues(alpha: 0.5),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _inputBuffer.isEmpty ? 'Tap digits below' : _inputBuffer,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _inputBuffer.isEmpty
                        ? AppColors.textMuted(context)
                        : AppColors.textPrimary(context),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Custom Numeric Keypad
        _buildKeypad(),
      ],
    );
  }

  Widget _buildKeypad() {
    return Builder(
      builder: (context) => Column(
        children: [
          for (var row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['DEL', '0', 'GO'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: row.map((key) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () {
                          if (key == 'DEL') {
                            _deleteDigit();
                          } else if (key == 'GO') {
                            _submitAnswer();
                          } else {
                            _appendDigit(key);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: key == 'GO'
                                ? AppColors.primary
                                : (key == 'DEL'
                                    ? AppColors.elevatedSurface(context)
                                    : AppColors.cardSurface(context)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: key == 'GO'
                                  ? AppColors.primaryLight
                                  : AppColors.border(context),
                            ),
                          ),
                        alignment: Alignment.center,
                        child: key == 'DEL'
                            ? const Icon(Icons.backspace_outlined, size: 20)
                            : (key == 'GO'
                                ? const Icon(Icons.check_rounded,
                                    size: 26, color: Colors.white)
                                : Text(
                                    key,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

