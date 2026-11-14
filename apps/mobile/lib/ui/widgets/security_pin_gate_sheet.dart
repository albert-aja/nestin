import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/journal_entry.dart';
import '../../domain/security/diary_lock_helper.dart';
import '../../providers/settings_provider.dart';

class SecurityPinGateSheet extends StatefulWidget {
  final VoidCallback onUnlocked;
  final bool isSetupMode;
  final DiaryLockType lockType;
  final bool allowLockTypeSwitch;
  final bool allowBiometrics;
  final String? hint;
  final String? initialHint;
  final bool Function(String secret)? customVerifier;
  final ValueChanged<CustomEntryLockConfig>? onCustomLockConfigured;
  final String? title;
  final String? subtitle;

  const SecurityPinGateSheet({
    super.key,
    required this.onUnlocked,
    this.isSetupMode = false,
    this.lockType = DiaryLockType.pin,
    this.allowLockTypeSwitch = false,
    this.allowBiometrics = true,
    this.hint,
    this.initialHint,
    this.customVerifier,
    this.onCustomLockConfigured,
    this.title,
    this.subtitle,
  });

  /// Verifies the Global Diary Lock (4-8 digit PIN or Biometrics), or prompts
  /// initial PIN setup if none has been configured yet.
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

    final hasPin = settings.hasPin;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SecurityPinGateSheet(
        isSetupMode: !hasPin,
        allowBiometrics: true,
        hint: settings.securityPinHint,
        title: title ??
            (hasPin ? 'Unlock Private Journal' : 'Setup Security PIN'),
        subtitle: subtitle ??
            (hasPin
                ? 'Enter your 4-8 digit PIN or use Biometrics'
                : 'Create a 4-8 digit PIN to secure your private thoughts'),
        onUnlocked: () {
          settings.unlockDiary();
          Navigator.of(ctx).pop(true);
        },
      ),
    );

    return result ?? false;
  }

  /// Verifies access to a specific [entry].
  ///
  /// - Custom-locked entries strictly require that entry's own PIN/password
  ///   with biometrics disabled and no global PIN fallback.
  /// - Entries using Global Diary Lock delegate to [verifyOrPrompt].
  static Future<bool> verifyEntryOrPrompt(
    BuildContext context,
    JournalEntry entry, {
    String? title,
    String? subtitle,
  }) async {
    if (!entry.isPrivate) return true;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.isEntryLocked(entry)) return true;

    if (!entry.hasCustomLock) {
      return verifyOrPrompt(
        context,
        title: title ?? 'Unlock Private Entry',
        subtitle:
            subtitle ?? 'Enter your PIN or Biometrics to read this reflection',
      );
    }

    final isPassword = entry.usesCustomPassword;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SecurityPinGateSheet(
        isSetupMode: false,
        lockType: entry.customLockType ?? DiaryLockType.pin,
        allowBiometrics: false,
        hint: entry.customLockHint,
        title: title ??
            (isPassword
                ? 'Unlock With Entry Password'
                : 'Unlock With Entry PIN'),
        subtitle: subtitle ??
            (isPassword
                ? 'Enter this diary entry\'s unique password'
                : 'Enter this diary entry\'s 4-8 digit PIN'),
        customVerifier: entry.verifyCustomSecret,
        onUnlocked: () {
          settings.unlockEntry(entry.id);
          Navigator.of(ctx).pop(true);
        },
      ),
    );

    return result ?? false;
  }

  /// Opens setup or change flow for the Global 4-8 digit Diary PIN & clue.
  /// When a PIN already exists, verifies the current PIN first.
  static Future<bool> setupGlobalPin(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (settings.hasPin) {
      final verified = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => SecurityPinGateSheet(
          isSetupMode: false,
          allowBiometrics: true,
          hint: settings.securityPinHint,
          title: 'Verify Current PIN',
          subtitle: 'Confirm your current PIN before changing it',
          customVerifier: settings.verifyPin,
          onUnlocked: () => Navigator.of(ctx).pop(true),
        ),
      );
      if (verified != true || !context.mounted) return false;
    }

    final configured = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SecurityPinGateSheet(
        isSetupMode: true,
        allowBiometrics: false,
        initialHint: settings.securityPinHint,
        title: settings.hasPin ? 'Change Security PIN' : 'Set Security PIN',
        subtitle: 'Create a 4-8 digit PIN and optional clue',
        onUnlocked: () => Navigator.of(ctx).pop(true),
      ),
    );

    return configured ?? false;
  }

  /// Opens custom lock configuration for a single diary entry (4-8 digit PIN
  /// or alphanumeric password + optional clue).
  static Future<CustomEntryLockConfig?> setupCustomEntryLock(
    BuildContext context, {
    DiaryLockType initialType = DiaryLockType.pin,
    String? initialHint,
  }) async {
    CustomEntryLockConfig? configured;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SecurityPinGateSheet(
        isSetupMode: true,
        lockType: initialType,
        allowLockTypeSwitch: true,
        allowBiometrics: false,
        initialHint: initialHint,
        title: 'Custom Entry Lock',
        subtitle:
            'Protect this entry with its own PIN or password (no biometrics)',
        onCustomLockConfigured: (config) {
          configured = config;
          Navigator.of(ctx).pop();
        },
        onUnlocked: () {},
      ),
    );

    return configured;
  }

  @override
  State<SecurityPinGateSheet> createState() => _SecurityPinGateSheetState();
}

class _SecurityPinGateSheetState extends State<SecurityPinGateSheet>
    with SingleTickerProviderStateMixin {
  late DiaryLockType _activeLockType;
  late TextEditingController _passwordController;
  late TextEditingController _hintController;
  late AnimationController _shakeController;

  String _pin = '';
  String _firstEnteredSecret = '';
  bool _isConfirming = false;
  bool _obscurePassword = true;
  bool _showHint = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _activeLockType = widget.lockType;
    _passwordController = TextEditingController();
    _hintController = TextEditingController(text: widget.initialHint ?? '');
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _hintController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  String get _currentSecret =>
      _activeLockType == DiaryLockType.pin ? _pin : _passwordController.text;

  bool get _canSubmit {
    if (_activeLockType == DiaryLockType.pin) {
      return _pin.length >= DiaryLockHelper.minPinLength &&
          _pin.length <= DiaryLockHelper.maxPinLength;
    }
    return widget.isSetupMode
        ? DiaryLockHelper.isValidPassword(_passwordController.text)
        : _passwordController.text.isNotEmpty;
  }

  void _onKeyTap(String value) {
    if (_activeLockType != DiaryLockType.pin) return;
    if (_pin.length >= DiaryLockHelper.maxPinLength) return;
    HapticFeedback.selectionClick();

    setState(() {
      _pin += value;
      _errorMessage = null;
    });
  }

  void _onBackspace() {
    if (_activeLockType != DiaryLockType.pin || _pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  void _switchSetupLockType(DiaryLockType nextType) {
    if (_activeLockType == nextType) return;
    HapticFeedback.selectionClick();
    setState(() {
      _activeLockType = nextType;
      _pin = '';
      _passwordController.clear();
      _firstEnteredSecret = '';
      _isConfirming = false;
      _errorMessage = null;
    });
  }

  Future<void> _triggerBiometric() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

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

  Future<void> _submitCurrentSecret() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final secret = _currentSecret;

    if (widget.isSetupMode) {
      await _handleSetupSubmit(settings, secret);
    } else {
      _handleUnlockSubmit(settings, secret);
    }
  }

  Future<void> _handleSetupSubmit(
    SettingsProvider settings,
    String secret,
  ) async {
    if (!DiaryLockHelper.isValidSecret(_activeLockType, secret)) {
      final msg = _activeLockType == DiaryLockType.pin
          ? 'Enter 4 to 8 digits.'
          : 'Enter at least 4 characters.';
      _triggerError(msg);
      return;
    }

    if (!_isConfirming) {
      setState(() {
        _firstEnteredSecret = secret;
        _pin = '';
        _passwordController.clear();
        _isConfirming = true;
        _errorMessage = _activeLockType == DiaryLockType.pin
            ? 'Re-enter ${_firstEnteredSecret.length}-digit PIN to confirm'
            : 'Re-enter password to confirm';
      });
      return;
    }

    if (secret != _firstEnteredSecret) {
      _triggerError(
        _activeLockType == DiaryLockType.pin
            ? 'PINs do not match. Try again.'
            : 'Passwords do not match. Try again.',
      );
      setState(() {
        _firstEnteredSecret = '';
        _isConfirming = false;
      });
      return;
    }

    final normalizedHint = DiaryLockHelper.normalizeHint(_hintController.text);

    if (widget.onCustomLockConfigured != null) {
      HapticFeedback.mediumImpact();
      final config = DiaryLockHelper.createCustomLock(
        type: _activeLockType,
        secret: secret,
        hint: normalizedHint,
      );
      widget.onCustomLockConfigured!(config);
      return;
    }

    await settings.setSecurityPin(
      secret,
      hint: normalizedHint,
      clearHint: normalizedHint == null,
    );
    await settings.toggleDiaryLock(true);
    settings.unlockDiary();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Security PIN saved successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
    widget.onUnlocked();
  }

  void _handleUnlockSubmit(SettingsProvider settings, String secret) {
    final verifier = widget.customVerifier ?? settings.verifyPin;
    if (verifier(secret)) {
      HapticFeedback.mediumImpact();
      if (widget.customVerifier == null) {
        settings.unlockDiary();
      }
      widget.onUnlocked();
    } else {
      _triggerError(
        _activeLockType == DiaryLockType.pin
            ? 'Incorrect PIN. Try again.'
            : 'Incorrect password. Try again.',
      );
    }
  }

  void _triggerError(String msg) {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
    setState(() {
      _errorMessage = msg;
      _pin = '';
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final cleanHint = DiaryLockHelper.normalizeHint(widget.hint);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 14, 24, bottomInset + 16),
        decoration: BoxDecoration(
          color: AppColors.sheetSurface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _activeLockType == DiaryLockType.password
                      ? Icons.password_rounded
                      : Icons.lock_rounded,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                widget.title ??
                    (widget.isSetupMode
                        ? 'Set Security Lock'
                        : 'Private Journal Lock'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle ??
                    (_isConfirming
                        ? (_activeLockType == DiaryLockType.pin
                            ? 'Confirm your ${_firstEnteredSecret.length}-digit PIN'
                            : 'Confirm your entry password')
                        : (_activeLockType == DiaryLockType.pin
                            ? 'Enter a 4-8 digit PIN'
                            : 'Enter your password')),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),

              if (widget.isSetupMode &&
                  widget.allowLockTypeSwitch &&
                  !_isConfirming) ...[
                const SizedBox(height: 10),
                _buildLockTypeSwitcher(context),
              ],

              const SizedBox(height: 12),

              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final offset = (_shakeController.value * 12) *
                      (1 - _shakeController.value);
                  return Transform.translate(
                    offset: Offset(
                      offset * 4 * (_shakeController.value > 0.5 ? -1 : 1),
                      0,
                    ),
                    child: child,
                  );
                },
                child: _activeLockType == DiaryLockType.pin
                    ? _buildPinDotsIndicator(context)
                    : _buildPasswordField(context),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isConfirming &&
                            _errorMessage!.startsWith('Re-enter')
                        ? AppColors.accent
                        : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // Clue input in Setup mode (step 1) for both PIN and Password
              if (widget.isSetupMode && !_isConfirming) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _hintController,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: _activeLockType == DiaryLockType.pin
                        ? 'PIN Clue (Optional)'
                        : 'Password Clue (Optional)',
                    hintText: 'Helpful memory cue — never write the secret',
                    prefixIcon: const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.elevatedSurface(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                  ),
                ),
              ],

              // Optional clue reveal in Unlock mode (never shown until tapped)
              if (!widget.isSetupMode && cleanHint != null) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showHint = !_showHint);
                  },
                  icon: Icon(
                    _showHint
                        ? Icons.visibility_off_outlined
                        : Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  label: Text(
                    _showHint ? 'Hide Clue' : 'Show Clue',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                if (_showHint)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'Clue: $cleanHint',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],

              const SizedBox(height: 10),

              if (_activeLockType == DiaryLockType.pin)
                _buildNumericKeypad(context, settings),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submitCurrentSecret : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.elevatedSurface(context),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    widget.isSetupMode
                        ? (_isConfirming ? 'Save Lock' : 'Continue')
                        : 'Unlock',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _canSubmit
                          ? Colors.black
                          : AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockTypeSwitcher(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          _buildTypeOption(
            context,
            type: DiaryLockType.pin,
            icon: Icons.pin_rounded,
            label: 'PIN (4–8 digits)',
          ),
          _buildTypeOption(
            context,
            type: DiaryLockType.password,
            icon: Icons.password_rounded,
            label: 'Password',
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(
    BuildContext context, {
    required DiaryLockType type,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeLockType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchSetupLockType(type),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.black
                    : AppColors.textSecondary(context),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.black
                      : AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinDotsIndicator(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(DiaryLockHelper.maxPinLength, (index) {
            final isFilled = index < _pin.length;
            final hasErr = _errorMessage != null &&
                !(_isConfirming && _errorMessage!.startsWith('Re-enter'));
            final borderColor = hasErr
                ? AppColors.error
                : (isFilled
                    ? AppColors.accent
                    : AppColors.border(context).withValues(
                        alpha: index < DiaryLockHelper.minPinLength ? 1.0 : 0.45,
                      ));

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled
                    ? (hasErr ? AppColors.error : AppColors.accent)
                    : Colors.transparent,
                border: Border.all(color: borderColor, width: 2),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          '${_pin.length}/8 digits (min 4)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      autofocus: true,
      onChanged: (_) => setState(() {
        if (_errorMessage != null &&
            !(_isConfirming && _errorMessage!.startsWith('Re-enter'))) {
          _errorMessage = null;
        }
      }),
      onSubmitted: (_) {
        if (_canSubmit) _submitCurrentSecret();
      },
      decoration: InputDecoration(
        labelText: _isConfirming ? 'Confirm Password' : 'Entry Password',
        hintText: widget.isSetupMode ? 'At least 4 characters' : 'Enter password',
        prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.accent),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: AppColors.elevatedSurface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
      ),
    );
  }

  Widget _buildNumericKeypad(
    BuildContext context,
    SettingsProvider settings,
  ) {
    final canUseBiometrics = widget.allowBiometrics &&
        settings.isBiometricEnabled &&
        !widget.isSetupMode &&
        widget.customVerifier == null;

    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              width: 72,
              height: 46,
              child: canUseBiometrics
                  ? IconButton(
                      icon: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.accent,
                        size: 30,
                      ),
                      tooltip: 'Biometric Unlock',
                      onPressed: _triggerBiometric,
                    )
                  : const SizedBox.shrink(),
            ),
            _buildKeypadButton('0'),
            SizedBox(
              width: 72,
              height: 46,
              child: IconButton(
                icon: Icon(
                  Icons.backspace_outlined,
                  color: AppColors.textSecondary(context),
                  size: 22,
                ),
                onPressed: _onBackspace,
              ),
            ),
          ],
        ),
      ],
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 72,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Center(
          child: Text(
            key,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
      ),
    );
  }
}
