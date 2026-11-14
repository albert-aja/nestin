import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/api_contracts.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/storage_service.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';

/// Non-intrusive optional account tile shown inside [SettingsScreen].
///
/// Works seamlessly both with [AccountProvider] in the widget tree and when
/// [SettingsScreen] is rendered in isolated tests with only [StorageService].
class NestinAccountSettingsTile extends StatefulWidget {
  const NestinAccountSettingsTile({super.key});

  @override
  State<NestinAccountSettingsTile> createState() =>
      _NestinAccountSettingsTileState();
}

class _NestinAccountSettingsTileState extends State<NestinAccountSettingsTile> {
  AccountProvider? _externalProvider;
  AccountProvider? _fallbackProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AccountProvider? found;
    try {
      found = Provider.of<AccountProvider>(context, listen: true);
    } catch (_) {
      found = null;
    }

    if (found != null) {
      if (_fallbackProvider != null) {
        _fallbackProvider!.removeListener(_handleFallbackChange);
        _fallbackProvider!.dispose();
        _fallbackProvider = null;
      }
      _externalProvider = found;
      return;
    }

    _externalProvider = null;
    if (_fallbackProvider == null) {
      try {
        final storage = Provider.of<StorageService>(context, listen: false);
        _fallbackProvider = AccountProvider(storage)
          ..addListener(_handleFallbackChange)
          ..initialize();
      } catch (_) {}
    }
  }

  void _handleFallbackChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _fallbackProvider?.removeListener(_handleFallbackChange);
    _fallbackProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = _externalProvider ?? _fallbackProvider;
    final isSignedIn = provider?.isSignedIn ?? false;
    final isLinked = provider?.isGuestLinked ?? false;
    final email = provider?.session?.email;

    final String subtitleText;
    final Color statusColor;
    final String statusBadge;

    if (isSignedIn && isLinked) {
      subtitleText = l10n.pick(
        '${email ?? 'Account active'} • Guest ID linked, local data intact',
        '${email ?? 'Akun aktif'} • ID Tamu tertaut, data lokal aman',
      );
      statusColor = AppColors.success;
      statusBadge = l10n.pick('Linked', 'Tertaut');
    } else if (isSignedIn) {
      subtitleText = l10n.pick(
        '${email ?? 'Signed in'} • Tap to link local Guest ID',
        '${email ?? 'Sudah masuk'} • Ketuk untuk tautkan ID Tamu lokal',
      );
      statusColor = AppColors.info;
      statusBadge = l10n.pick('Signed In', 'Masuk');
    } else {
      subtitleText = l10n.pick(
        'Guest mode active • Sign up anytime without altering local data',
        'Mode tamu aktif • Daftar kapan saja tanpa mengubah data lokal',
      );
      statusColor = AppColors.textSecondary(context);
      statusBadge = l10n.pick('Guest', 'Tamu');
    }

    return Card(
      child: InkWell(
        onTap: provider == null
            ? null
            : () => NestinAccountSheet.show(
                  context,
                  accountProvider: provider,
                ),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isSignedIn ? statusColor : AppColors.info)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSignedIn
                      ? Icons.verified_user_outlined
                      : Icons.person_outline_rounded,
                  color: isSignedIn ? statusColor : AppColors.info,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l10n.pick(
                            'Nestin Account (Optional)',
                            'Akun Nestin (Opsional)',
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusBadge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AuthFormMode {
  signUp,
  signIn,
}

class NestinAccountSheet extends StatefulWidget {
  final AccountProvider accountProvider;

  const NestinAccountSheet({
    super.key,
    required this.accountProvider,
  });

  static Future<void> show(
    BuildContext context, {
    required AccountProvider accountProvider,
  }) {
    accountProvider.clearMessages();
    if (!accountProvider.isInitialized) {
      accountProvider.initialize();
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NestinAccountSheet(accountProvider: accountProvider),
    );
  }

  @override
  State<NestinAccountSheet> createState() => _NestinAccountSheetState();
}

class _NestinAccountSheetState extends State<NestinAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  _AuthFormMode _mode = _AuthFormMode.signUp;
  bool _obscurePassword = true;
  bool _linkGuestAfterAuth = true;

  @override
  void initState() {
    super.initState();
    _linkGuestAfterAuth = widget.accountProvider.isBackendConfigured;
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _currentLangCode(BuildContext context) {
    try {
      return Provider.of<SettingsProvider>(context, listen: false)
          .language
          .code;
    } catch (_) {
      return context.l10n.language.code;
    }
  }

  Future<void> _submitAuth() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final lang = _currentLangCode(context);
    final provider = widget.accountProvider;

    bool ok;
    if (_mode == _AuthFormMode.signUp) {
      ok = await provider.signUp(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        displayName: _displayNameCtrl.text,
        preferredLanguage: lang,
        prepareMigrationOnSuccess:
            _linkGuestAfterAuth && provider.isBackendConfigured,
      );
    } else {
      ok = await provider.signIn(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        preferredLanguage: lang,
        prepareMigrationOnSuccess:
            _linkGuestAfterAuth && provider.isBackendConfigured,
      );
    }

    if (!mounted) return;
    if (ok &&
        provider.isSignedIn &&
        provider.lastErrorMessage == null &&
        provider.lastMigrationReceipt != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              'Guest ID linked safely. All local records remain untouched on-device.',
              'ID Tamu berhasil ditautkan. Semua data lokal tetap utuh di perangkat.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _handlePrepareMigration() async {
    final l10n = context.l10n;
    final result = await widget.accountProvider.prepareGuestMigration(
      preferredLanguage: _currentLangCode(context),
    );
    if (!mounted) return;
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              'Guest migration prepared. Local data preserved and cloud sync stays off.',
              'Persiapan migrasi tamu selesai. Data lokal aman & sinkronisasi cloud tetap nonaktif.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final l10n = context.l10n;
    await widget.accountProvider.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.pick(
            'Signed out cleanly. All local Nestin records remain intact.',
            'Berhasil keluar. Semua catatan lokal Nestin tetap utuh.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: widget.accountProvider,
      builder: (context, _) {
        final provider = widget.accountProvider;
        final guest = provider.guestIdentity;
        final session = provider.session;
        final receipt = provider.lastMigrationReceipt;
        final counts = provider.localRecordCounts;

        return Material(
          color: AppColors.sheetSurface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.scrimHandle(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.pick(
                              'Nestin Account (Optional)',
                              'Akun Nestin (Opsional)',
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.pick(
                              'Link your local guest identity without altering local records',
                              'Tautkan identitas tamu lokal tanpa mengubah catatan di perangkat',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Local-first guarantee banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.pick(
                            'Local-First Guarantee: Creating an account or preparing migration only links your Guest UUID on the server. None of your alarms, tasks, notes, diary entries, or money records are modified or uploaded.',
                            'Jaminan Lokal-Utama: Membuat akun atau menyiapkan migrasi hanya menautkan UUID Tamu di server. Alarm, tugas, catatan, jurnal, maupun data uang tidak diubah atau diunggah.',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // On-device Guest ID & local snapshot counts
                _buildGuestIdentityCard(context, l10n, guest, counts),
                const SizedBox(height: 14),

                if (provider.lastErrorMessage != null) ...[
                  _buildStatusBanner(
                    context,
                    icon: Icons.error_outline_rounded,
                    color: AppColors.error,
                    text: provider.lastErrorMessage!,
                  ),
                  const SizedBox(height: 12),
                ],

                if (provider.pendingConfirmationEmail != null) ...[
                  _buildStatusBanner(
                    context,
                    icon: Icons.mark_email_read_outlined,
                    color: AppColors.info,
                    text: l10n.pick(
                      'Confirmation sent to ${provider.pendingConfirmationEmail}. Verify your email first, then use Sign In to link your Guest ID.',
                      'Konfirmasi terkirim ke ${provider.pendingConfirmationEmail}. Verifikasi email Anda terlebih dahulu, lalu gunakan Masuk untuk menautkan ID Tamu.',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (provider.isSignedIn && session != null)
                  _buildSignedInSection(
                    context,
                    l10n,
                    provider,
                    session,
                    receipt,
                  )
                else
                  _buildAuthFormSection(context, l10n, provider),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuestIdentityCard(
    BuildContext context,
    AppLocalizations l10n,
    GuestIdentityProfile? guest,
    Map<String, int> counts,
  ) {
    final isLinked = guest?.authMode == AccountAuthMode.registered;
    final total = counts.values.fold<int>(0, (sum, val) => sum + val);
    final highlights = <MapEntry<String, int>>[
      MapEntry(l10n.pick('Alarms', 'Alarm'), counts['alarms'] ?? 0),
      MapEntry(l10n.pick('Tasks', 'Tugas'), counts['tasks'] ?? 0),
      MapEntry(l10n.pick('Notes', 'Catatan'), counts['notes'] ?? 0),
      MapEntry(l10n.pick('Journal', 'Jurnal'), counts['journalEntries'] ?? 0),
      MapEntry(l10n.pick('Money', 'Keuangan'), counts['moneyTransactions'] ?? 0),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.pick('On-Device Guest Identity', 'Identitas Tamu Perangkat'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isLinked ? AppColors.success : AppColors.accent)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isLinked
                      ? l10n.pick('Linked', 'Tertaut')
                      : l10n.pick('Local Guest', 'Tamu Lokal'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isLinked
                        ? AppColors.success
                        : AppColors.adaptive(
                            context,
                            dark: AppColors.accent,
                            light: AppColors.primaryDark,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            guest?.guestLocalId ?? l10n.pick('Provisioning...', 'Menyiapkan...'),
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.pick(
              '$total local records protected on this device:',
              '$total catatan lokal tersimpan aman di perangkat:',
            ),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: highlights
                .map(
                  (entry) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Text(
                      '${entry.key}: ${entry.value}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthFormSection(
    BuildContext context,
    AppLocalizations l10n,
    AccountProvider provider,
  ) {
    final supabaseReady = provider.isSupabaseConfigured;
    final backendReady = provider.isBackendConfigured;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!supabaseReady || !backendReady) ...[
            _buildStatusBanner(
              context,
              icon: Icons.cloud_off_rounded,
              color: AppColors.warning,
              text: !supabaseReady
                  ? l10n.pick(
                      'Offline-only build: configure NESTIN_SUPABASE_URL and NESTIN_SUPABASE_ANON_KEY via --dart-define to enable optional sign-up/sign-in.',
                      'Build khusus offline: konfigurasi NESTIN_SUPABASE_URL dan NESTIN_SUPABASE_ANON_KEY melalui --dart-define untuk mengaktifkan pendaftaran opsional.',
                    )
                  : l10n.pick(
                      'Supabase Auth is ready, but NESTIN_API_BASE_URL is not configured yet for server guest-migration linking.',
                      'Supabase Auth siap, namun NESTIN_API_BASE_URL belum dikonfigurasi untuk penautan migrasi tamu.',
                    ),
            ),
            const SizedBox(height: 12),
          ],
          SegmentedButton<_AuthFormMode>(
            segments: [
              ButtonSegment<_AuthFormMode>(
                value: _AuthFormMode.signUp,
                label: Text(l10n.pick('Sign Up', 'Daftar')),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              ),
              ButtonSegment<_AuthFormMode>(
                value: _AuthFormMode.signIn,
                label: Text(l10n.pick('Sign In', 'Masuk')),
                icon: const Icon(Icons.login_rounded, size: 18),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: provider.isSubmitting
                ? null
                : (selection) {
                    provider.clearMessages();
                    setState(() => _mode = selection.first);
                  },
          ),
          const SizedBox(height: 14),
          if (_mode == _AuthFormMode.signUp) ...[
            TextFormField(
              controller: _displayNameCtrl,
              enabled: !provider.isSubmitting,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.pick(
                  'Display Name (Optional)',
                  'Nama Tampilan (Opsional)',
                ),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _emailCtrl,
            enabled: !provider.isSubmitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.pick('Email Address', 'Alamat Email'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty || !trimmed.contains('@')) {
                return l10n.pick(
                  'Enter a valid email address',
                  'Masukkan alamat email yang valid',
                );
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            enabled: !provider.isSubmitting,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.pick('Password', 'Kata Sandi'),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              final raw = value ?? '';
              if (raw.isEmpty) {
                return l10n.pick(
                  'Enter your password',
                  'Masukkan kata sandi',
                );
              }
              if (_mode == _AuthFormMode.signUp && raw.length < 6) {
                return l10n.pick(
                  'Password must be at least 6 characters',
                  'Kata sandi minimal 6 karakter',
                );
              }
              return null;
            },
          ),
          if (backendReady) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _linkGuestAfterAuth,
              onChanged: provider.isSubmitting
                  ? null
                  : (val) => setState(() => _linkGuestAfterAuth = val ?? true),
              title: Text(
                l10n.pick(
                  'Prepare Guest ID migration right away',
                  'Siapkan tautan migrasi ID Tamu langsung',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                l10n.pick(
                  'Links your Guest UUID without uploading or changing local records.',
                  'Menautkan UUID Tamu tanpa mengunggah atau mengubah catatan lokal.',
                ),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed:
                (provider.isSubmitting || !supabaseReady) ? null : _submitAuth,
            icon: provider.isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _mode == _AuthFormMode.signUp
                        ? Icons.person_add_rounded
                        : Icons.login_rounded,
                  ),
            label: Text(
              _mode == _AuthFormMode.signUp
                  ? l10n.pick('Create Optional Account', 'Buat Akun Opsional')
                  : l10n.pick('Sign In', 'Masuk'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedInSection(
    BuildContext context,
    AppLocalizations l10n,
    AccountProvider provider,
    SupabaseAuthSession session,
    GuestMigrationReceipt? receipt,
  ) {
    final backendReady = provider.isBackendConfigured;
    final cloudSyncOptIn = provider.guestIdentity?.cloudSyncOptIn ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.email ??
                              l10n.pick(
                                'Authenticated Account',
                                'Akun Terautentikasi',
                              ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'UID: ${session.userId}',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _infoPill(
                    context,
                    label: cloudSyncOptIn
                        ? l10n.pick('Cloud Sync: Opt-In', 'Sinkronisasi Cloud: Aktif')
                        : l10n.pick(
                            'Cloud Sync: Off (Local-First)',
                            'Sinkronisasi Cloud: Nonaktif (Lokal)',
                          ),
                    color: AppColors.info,
                  ),
                  _infoPill(
                    context,
                    label: provider.isGuestLinked
                        ? l10n.pick('Guest UUID Linked', 'UUID Tamu Tertaut')
                        : l10n.pick('Not Linked Yet', 'Belum Tertaut'),
                    color: provider.isGuestLinked
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!backendReady) ...[
          _buildStatusBanner(
            context,
            icon: Icons.cloud_off_rounded,
            color: AppColors.warning,
            text: l10n.pick(
              'NESTIN_API_BASE_URL is not configured in this build. Guest migration linking requires a configured backend.',
              'NESTIN_API_BASE_URL belum dikonfigurasi pada build ini. Penautan migrasi tamu memerlukan URL backend.',
            ),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          onPressed: (provider.isSubmitting || !backendReady)
              ? null
              : _handlePrepareMigration,
          icon: provider.isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.link_rounded),
          label: Text(
            provider.isGuestLinked
                ? l10n.pick(
                    'Refresh Guest Migration Link',
                    'Perbarui Tautan Migrasi Tamu',
                  )
                : l10n.pick(
                    'Prepare Guest Migration',
                    'Siapkan Migrasi Tamu',
                  ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        if (receipt != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick(
                    'Migration Link Acknowledged',
                    'Tautan Migrasi Dikonfirmasi',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.pick(
                    'Local data preserved: ${receipt.localDataPreserved} • Cloud sync: ${receipt.cloudSyncOptIn ? 'On' : 'Off'} • Counts acknowledged: ${receipt.totalAcknowledgedCount}',
                    'Data lokal aman: ${receipt.localDataPreserved} • Sinkronisasi cloud: ${receipt.cloudSyncOptIn ? 'Aktif' : 'Nonaktif'} • Jumlah tercatat: ${receipt.totalAcknowledgedCount}',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: provider.isSubmitting ? null : _handleSignOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(
            l10n.pick(
              'Sign Out (Keep Local Data)',
              'Keluar (Pertahankan Data Lokal)',
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
