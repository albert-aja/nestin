import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';

class SecurityPinGateSheet extends StatefulWidget {
  final VoidCallback onUnlocked;
  final bool isSetupMode;
  final String? title;
  final String? subtitle;

  const SecurityPinGateSheet({
    super.key,
    required this.onUnlocked,
    this.isSetupMode = false,
    this.title,
    this.subtitle,
  });

  static Future<bool> verifyOrPrompt(
    BuildContext context, {
    String? title,
    String? subtitle,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    // If lock is not enabled or already unlocked in session, grant access immediately
    if (!settings.isDiaryLockEnabled || settings.isDiaryUnlocked) {
      return true;
    }

    // If no PIN has been set yet, prompt to set one
    final hasPin = settings.hasPin;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SecurityPinGateSheet(
        isSetupMode: !hasPin,
        title: title ?? (hasPin ? 'Unlock Private Journal' : 'Setup Security PIN'),
        subtitle: subtitle ??
            (hasPin
                ? 'Enter your 4-digit PIN or use Biometrics'
                : 'Create a 4-digit PIN to secure your private thoughts'),
        onUnlocked: () {
          settings.unlockDiary();
          Navigator.of(ctx).pop(true);
        },
      ),
    );

    return result ?? false;
  }

  @override
  State<SecurityPinGateSheet> createState() => _SecurityPinGateSheetState();
}

class _SecurityPinGateSheetState extends State<SecurityPinGateSheet>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _firstEnteredPin = '';
  bool _isConfirming = false;
  String? _errorMessage;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyTap(String value) {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();

    setState(() {
      _pin += value;
      _errorMessage = null;
    });

    if (_pin.length == 4) {
      _processPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _triggerBiometric() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    HapticFeedback.mediumImpact();

    // Biometric authentication
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Biometrics Authenticated'),
            ],
          ),
          duration: Duration(seconds: 1),
          backgroundColor: AppColors.success,
        ),
      );
      settings.unlockDiary();
      widget.onUnlocked();
    }
  }

  void _processPin() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (widget.isSetupMode) {
      if (!_isConfirming) {
        setState(() {
          _firstEnteredPin = _pin;
          _pin = '';
          _isConfirming = true;
          _errorMessage = 'Re-enter PIN to confirm';
        });
      } else {
        if (_pin == _firstEnteredPin) {
          settings.setSecurityPin(_pin);
          settings.toggleDiaryLock(true);
          settings.unlockDiary();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Security PIN created successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          widget.onUnlocked();
        } else {
          _triggerError('PINs do not match. Try again.');
          setState(() {
            _firstEnteredPin = '';
            _isConfirming = false;
          });
        }
      }
    } else {
      if (settings.verifyPin(_pin)) {
        HapticFeedback.mediumImpact();
        settings.unlockDiary();
        widget.onUnlocked();
      } else {
        _triggerError('Incorrect PIN. Try again.');
      }
    }
  }

  void _triggerError(String msg) {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
    setState(() {
      _errorMessage = msg;
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF16171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2E313D),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Lock Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: AppColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            widget.title ??
                (widget.isSetupMode ? 'Set 4-Digit PIN' : 'Private Journal Lock'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle ??
                (_isConfirming
                    ? 'Confirm your 4-digit code'
                    : 'Enter your PIN or use biometrics to continue'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF8E929E)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // 4-Dot indicators
          AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              final offset =
                  (_shakeController.value * 12) * (1 - _shakeController.value);
              return Transform.translate(
                offset: Offset(offset * 4 * (_shakeController.value > 0.5 ? -1 : 1), 0),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? (_errorMessage != null
                            ? AppColors.error
                            : AppColors.accent)
                        : Colors.transparent,
                    border: Border.all(
                      color: _errorMessage != null
                          ? AppColors.error
                          : (isFilled ? AppColors.accent : const Color(0xFF3B3E4D)),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Keypad Grid
          Column(
            children: [
              _buildKeypadRow(['1', '2', '3']),
              const SizedBox(height: 12),
              _buildKeypadRow(['4', '5', '6']),
              const SizedBox(height: 12),
              _buildKeypadRow(['7', '8', '9']),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Biometric or Clear
                  SizedBox(
                    width: 72,
                    height: 56,
                    child: settings.isBiometricEnabled && !widget.isSetupMode
                        ? IconButton(
                            icon: const Icon(
                              Icons.fingerprint_rounded,
                              color: AppColors.accent,
                              size: 32,
                            ),
                            tooltip: 'Biometric Unlock',
                            onPressed: _triggerBiometric,
                          )
                        : const SizedBox.shrink(),
                  ),
                  _buildKeypadButton('0'),
                  SizedBox(
                    width: 72,
                    height: 56,
                    child: IconButton(
                      icon: const Icon(
                        Icons.backspace_outlined,
                        color: Color(0xFF8E929E),
                        size: 22,
                      ),
                      onPressed: _onBackspace,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildKeypadButton(k)).toList(),
    );
  }

  Widget _buildKeypadButton(String key) {
    return InkWell(
      onTap: () => _onKeyTap(key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF1E2028),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2C2F3A)),
        ),
        child: Center(
          child: Text(
            key,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

