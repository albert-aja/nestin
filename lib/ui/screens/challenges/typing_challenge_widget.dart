import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/challenge_profile.dart';
import '../../../domain/challenge/challenge_engine.dart';

class TypingChallengeWidget extends StatefulWidget {
  final ChallengeDifficulty difficulty;
  final VoidCallback onCompleted;

  const TypingChallengeWidget({
    super.key,
    required this.difficulty,
    required this.onCompleted,
  });

  @override
  State<TypingChallengeWidget> createState() => _TypingChallengeWidgetState();
}

class _TypingChallengeWidgetState extends State<TypingChallengeWidget> {
  late String _targetPhrase;
  final TextEditingController _textController = TextEditingController();
  bool _isMatched = false;

  @override
  void initState() {
    super.initState();
    _targetPhrase = ChallengeEngine.generateTypingPhrase(widget.difficulty);
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final current = _textController.text.trim();
    if (current.toLowerCase() == _targetPhrase.trim().toLowerCase()) {
      setState(() {
        _isMatched = true;
      });
    } else {
      if (_isMatched) {
        setState(() {
          _isMatched = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Type the phrase exactly as shown:',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF8E929E),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),

        // Target Phrase Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2128),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.format_quote_rounded,
                  color: AppColors.accent, size: 24),
              const SizedBox(height: 6),
              Text(
                _targetPhrase,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _textController,
          autofocus: true,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Start typing here...',
            prefixIcon: const Icon(Icons.edit_note_rounded),
            suffixIcon: _isMatched
                ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                : null,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _isMatched ? widget.onCompleted : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: const Color(0xFF282A32),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            _isMatched ? 'Confirm & Dismiss Alarm' : 'Complete Typing to Unlock',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

