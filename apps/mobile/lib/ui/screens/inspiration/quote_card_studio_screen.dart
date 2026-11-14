import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/inspiration_models.dart';
import '../../../data/services/quote_card_export_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../providers/inspiration_provider.dart';
import '../../widgets/inspiration/mascot_helper.dart';

class QuoteCardStudioScreen extends StatefulWidget {
  final String quoteText;
  final String authorName;
  final String? initialMascotDomain;
  final InspirationWallpaperTemplate? initialTemplate;
  final QuoteCardExportService? exportService;
  final GlobalKey? previewBoundaryKey;

  const QuoteCardStudioScreen({
    super.key,
    required this.quoteText,
    required this.authorName,
    this.initialMascotDomain,
    this.initialTemplate,
    this.exportService,
    this.previewBoundaryKey,
  });

  @override
  State<QuoteCardStudioScreen> createState() => _QuoteCardStudioScreenState();
}

class _QuoteCardStudioScreenState extends State<QuoteCardStudioScreen> {
  late final GlobalKey _boundaryKey;
  late final QuoteCardExportService _exportService;
  late QuoteCardDesignConfig _config;
  bool _isExporting = false;
  String? _lastExportedPath;

  static const List<_PalettePreset> _palettes = [
    _PalettePreset(
      id: 'sunrise-nest',
      name: 'Sunrise Nest',
      colors: [Color(0xFF1F1627), Color(0xFF3A1D2E), Color(0xFFE04A3A)],
      textColor: Color(0xFFFFF8F3),
      isGradient: true,
    ),
    _PalettePreset(
      id: 'seren-twilight',
      name: 'Seren Twilight',
      colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF312E81)],
      textColor: Color(0xFFF8FAFC),
      isGradient: true,
    ),
    _PalettePreset(
      id: 'pippin-sage',
      name: 'Pippin Sage',
      colors: [Color(0xFF102A26), Color(0xFF164E46), Color(0xFF059669)],
      textColor: Color(0xFFECFDF5),
      isGradient: true,
    ),
    _PalettePreset(
      id: 'paper-almanac',
      name: 'Paper Almanac',
      colors: [Color(0xFFFBF7F0), Color(0xFFF2E9DC)],
      textColor: Color(0xFF1E2028),
      isGradient: false,
    ),
    _PalettePreset(
      id: 'midnight-ink',
      name: 'Midnight Ink',
      colors: [Color(0xFF111215), Color(0xFF1E2028)],
      textColor: Color(0xFFF1F3F5),
      isGradient: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _boundaryKey = widget.previewBoundaryKey ?? GlobalKey();
    _exportService = widget.exportService ?? const QuoteCardExportService();
    final tpl = widget.initialTemplate;
    if (tpl != null) {
      _config = QuoteCardDesignConfig(
        templateId: tpl.id,
        aspectRatio: _ratioFromLayout(tpl.layoutType),
        useGradient: tpl.backgroundType == 'gradient',
        gradientColors: tpl.parsedGradientColors,
        solidColor: tpl.parsedGradientColors.first,
        textColor: tpl.parsedTextColor,
        fontFamily: tpl.fontFamily,
        textAlign: _alignFromString(tpl.textAlignment),
        showBranding: tpl.showBranding,
        mascotDomain: tpl.mascotIllustration ?? widget.initialMascotDomain,
      );
    } else {
      _config = QuoteCardDesignConfig(
        templateId: 'sunrise-nest',
        aspectRatio: QuoteCardAspectRatio.portrait4x5,
        gradientColors: _palettes.first.colors,
        solidColor: _palettes.first.colors.first,
        textColor: _palettes.first.textColor,
        mascotDomain: widget.initialMascotDomain ?? 'pippin',
      );
    }
  }

  QuoteCardAspectRatio _ratioFromLayout(String layoutType) {
    switch (layoutType) {
      case 'quote_card_square':
        return QuoteCardAspectRatio.square1x1;
      case 'lock_screen':
        return QuoteCardAspectRatio.lockScreen9x16;
      case 'home_screen':
        return QuoteCardAspectRatio.homeScreen9x16;
      default:
        return QuoteCardAspectRatio.portrait4x5;
    }
  }

  TextAlign _alignFromString(String align) {
    switch (align) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }

  void _applyTemplate(InspirationWallpaperTemplate tpl) {
    final nextRatio = _ratioFromLayout(tpl.layoutType);
    setState(() {
      _config = _config.copyWith(
        templateId: tpl.id,
        aspectRatio: nextRatio,
        useGradient: tpl.backgroundType == 'gradient',
        gradientColors: tpl.parsedGradientColors,
        solidColor: tpl.parsedGradientColors.first,
        textColor: tpl.parsedTextColor,
        fontFamily: tpl.fontFamily,
        textAlign: _alignFromString(tpl.textAlignment),
        showBranding: tpl.showBranding,
        mascotDomain: tpl.mascotIllustration,
        clearMascot: tpl.mascotIllustration == null,
        verticalPosition: nextRatio == QuoteCardAspectRatio.lockScreen9x16 &&
                _config.verticalPosition < 0.46
            ? 0.52
            : _config.verticalPosition,
      );
    });
  }

  Future<void> _exportCard({required bool share}) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final shareText = '“${widget.quoteText}” — ${widget.authorName} (Nestin)';
      final outcome = await _exportService.exportCardPng(
        boundaryKey: _boundaryKey,
        shareText: shareText,
        shareImmediately: share,
      );
      if (!mounted) return;
      setState(() => _lastExportedPath = outcome.filePath);
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            share
                ? (outcome.sharedViaNativeSheet
                    ? l10n.pick(
                        'Card exported and ready to share.',
                        'Kartu berhasil diekspor dan siap dibagikan.',
                      )
                    : l10n.pick(
                        'Card PNG saved locally & quote copied to clipboard.',
                        'PNG kartu disimpan di perangkat & kutipan disalin.',
                      ))
                : l10n.pick(
                    'Saved quote card PNG (${(outcome.pngBytes.lengthInBytes / 1024).toStringAsFixed(0)} KB)',
                    'PNG kartu tersimpan (${(outcome.pngBytes.lengthInBytes / 1024).toStringAsFixed(0)} KB)',
                  ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  TextStyle _quoteTypography(BuildContext context) {
    final baseFont = switch (_config.fontFamily) {
      'serif' => 'Georgia',
      'mono' => 'monospace',
      _ => null,
    };
    return TextStyle(
      fontFamily: baseFont,
      fontSize: _config.fontSize,
      fontWeight: FontWeight.w700,
      height: 1.38,
      color: _config.textColor,
      letterSpacing: _config.fontFamily == 'mono' ? -0.3 : 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final templates = context.watch<InspirationProvider>().templates;
    final mascotMeta = inspirationMascotFor(_config.mascotDomain);
    final isLockScreen =
        _config.aspectRatio == QuoteCardAspectRatio.lockScreen9x16;
    final safeVerticalBias =
        isLockScreen ? _config.verticalPosition.clamp(0.45, 0.78) : _config.verticalPosition;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pick('Quote Card Studio', 'Studio Kartu Kutipan')),
        actions: [
          IconButton(
            tooltip: l10n.pick('Save PNG', 'Simpan PNG'),
            onPressed: _isExporting ? null : () => _exportCard(share: false),
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: l10n.pick('Share Card', 'Bagikan Kartu'),
            onPressed: _isExporting ? null : () => _exportCard(share: true),
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live Preview Stage
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: AppColors.recessedSurface(context),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Center(
                child: AspectRatio(
                  aspectRatio: _config.aspectRatio.ratioValue,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          key: _boundaryKey,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _config.useGradient
                                  ? null
                                  : _config.solidColor,
                              gradient: _config.useGradient
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: _config.gradientColors,
                                    )
                                  : null,
                            ),
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                            child: Column(
                              children: [
                                if (isLockScreen) const SizedBox(height: 52),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment(
                                      0,
                                      (safeVerticalBias * 2) - 1,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 320,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            switch (_config.textAlign) {
                                          TextAlign.left =>
                                            CrossAxisAlignment.start,
                                          TextAlign.right =>
                                            CrossAxisAlignment.end,
                                          _ => CrossAxisAlignment.center,
                                        },
                                        children: [
                                          Text(
                                            '“${widget.quoteText}”',
                                            textAlign: _config.textAlign,
                                            style: _quoteTypography(context),
                                          ),
                                          if (_config.showAuthor &&
                                              widget.authorName
                                                  .trim()
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Text(
                                              '— ${widget.authorName}',
                                              textAlign: _config.textAlign,
                                              style: TextStyle(
                                                fontSize: (_config.fontSize * 0.58)
                                                    .clamp(11.0, 16.0),
                                                fontWeight: FontWeight.w600,
                                                color: _config.textColor
                                                    .withValues(alpha: 0.84),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Dedicated safe footer row prevents text overlapping mascot/branding
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (_config.showBranding)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _config.textColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'nestin',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.1,
                                            color: _config.textColor
                                                .withValues(alpha: 0.88),
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    if (mascotMeta != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.asset(
                                          mascotMeta.assetPath,
                                          width: 42,
                                          height: 42,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) => Icon(
                                            Icons.flutter_dash_rounded,
                                            size: 28,
                                            color: _config.textColor
                                                .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Non-exported wallpaper lock-screen clock safe-zone guide
                        if (isLockScreen)
                          Positioned(
                            top: 14,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: Column(
                                children: [
                                  Text(
                                    '08:15',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w300,
                                      color: _config.textColor
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                  Text(
                                    l10n.pick(
                                      'Lock Screen Clock Safe Zone',
                                      'Zona Aman Jam Layar Kunci',
                                    ),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _config.textColor
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Controls Panel
          Expanded(
            flex: 5,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                if (_lastExportedPath != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${l10n.pick('Saved', 'Tersimpan')}: $_lastExportedPath',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),

                // Format / Layout Ratio
                _sectionHeader(
                  context,
                  l10n.pick('Layout & Wallpaper Format', 'Format & Wallpaper'),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: QuoteCardAspectRatio.values.map((ratio) {
                    final label = switch (ratio) {
                      QuoteCardAspectRatio.square1x1 =>
                        l10n.pick('Square 1:1', 'Persegi 1:1'),
                      QuoteCardAspectRatio.portrait4x5 =>
                        l10n.pick('Portrait 4:5', 'Potret 4:5'),
                      QuoteCardAspectRatio.lockScreen9x16 =>
                        l10n.pick('Lock Screen 9:16', 'Layar Kunci'),
                      QuoteCardAspectRatio.homeScreen9x16 =>
                        l10n.pick('Home Screen 9:16', 'Layar Utama'),
                    };
                    return ChoiceChip(
                      label: Text(label),
                      selected: _config.aspectRatio == ratio,
                      onSelected: (_) {
                        setState(() {
                          _config = _config.copyWith(
                            aspectRatio: ratio,
                            verticalPosition:
                                ratio == QuoteCardAspectRatio.lockScreen9x16 &&
                                        _config.verticalPosition < 0.48
                                    ? 0.54
                                    : _config.verticalPosition,
                          );
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Templates & Palettes
                _sectionHeader(
                  context,
                  l10n.pick('Templates & Colors', 'Templat & Warna'),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...templates.map(
                        (tpl) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(tpl.name),
                            selected: _config.templateId == tpl.id,
                            onSelected: (_) => _applyTemplate(tpl),
                          ),
                        ),
                      ),
                      ..._palettes.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: CircleAvatar(
                              backgroundColor: p.colors.last,
                              radius: 8,
                            ),
                            label: Text(p.name),
                            selected: _config.templateId == p.id,
                            onSelected: (_) => setState(() {
                              _config = _config.copyWith(
                                templateId: p.id,
                                useGradient: p.isGradient,
                                gradientColors: p.colors,
                                solidColor: p.colors.first,
                                textColor: p.textColor,
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Typography & Alignment
                _sectionHeader(
                  context,
                  l10n.pick('Typography & Position', 'Tipografi & Posisi'),
                ),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Serif'),
                      selected: _config.fontFamily == 'serif',
                      onSelected: (_) => setState(() {
                        _config = _config.copyWith(fontFamily: 'serif');
                      }),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Sans'),
                      selected: _config.fontFamily == 'sans',
                      onSelected: (_) => setState(() {
                        _config = _config.copyWith(fontFamily: 'sans');
                      }),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Mono'),
                      selected: _config.fontFamily == 'mono',
                      onSelected: (_) => setState(() {
                        _config = _config.copyWith(fontFamily: 'mono');
                      }),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.format_align_left_rounded),
                      color: _config.textAlign == TextAlign.left
                          ? AppColors.primary
                          : AppColors.textSecondary(context),
                      onPressed: () => setState(() {
                        _config = _config.copyWith(textAlign: TextAlign.left);
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_align_center_rounded),
                      color: _config.textAlign == TextAlign.center
                          ? AppColors.primary
                          : AppColors.textSecondary(context),
                      onPressed: () => setState(() {
                        _config = _config.copyWith(textAlign: TextAlign.center);
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_align_right_rounded),
                      color: _config.textAlign == TextAlign.right
                          ? AppColors.primary
                          : AppColors.textSecondary(context),
                      onPressed: () => setState(() {
                        _config = _config.copyWith(textAlign: TextAlign.right);
                      }),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      l10n.pick('Size', 'Ukuran'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        min: 15,
                        max: 30,
                        value: _config.fontSize,
                        onChanged: (v) => setState(() {
                          _config = _config.copyWith(fontSize: v);
                        }),
                      ),
                    ),
                    Text(
                      l10n.pick('Pos', 'Posisi'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        min: isLockScreen ? 0.45 : 0.22,
                        max: 0.78,
                        value: safeVerticalBias,
                        onChanged: (v) => setState(() {
                          _config = _config.copyWith(verticalPosition: v);
                        }),
                      ),
                    ),
                  ],
                ),

                // Toggles & Bird Mascots
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      label: Text(l10n.pick('Gradient', 'Gradasi')),
                      selected: _config.useGradient,
                      onSelected: (v) => setState(() {
                        _config = _config.copyWith(useGradient: v);
                      }),
                    ),
                    FilterChip(
                      label: Text(l10n.pick('Author', 'Penulis')),
                      selected: _config.showAuthor,
                      onSelected: (v) => setState(() {
                        _config = _config.copyWith(showAuthor: v);
                      }),
                    ),
                    FilterChip(
                      label: Text(l10n.pick('Nestin Mark', 'Logo Nestin')),
                      selected: _config.showBranding,
                      onSelected: (v) => setState(() {
                        _config = _config.copyWith(showBranding: v);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _sectionHeader(
                  context,
                  l10n.pick('Bird Companion Badge', 'Ilustrasi Burung Nestin'),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(l10n.pick('None', 'Tanpa')),
                          selected: _config.mascotDomain == null,
                          onSelected: (_) => setState(() {
                            _config = _config.copyWith(clearMascot: true);
                          }),
                        ),
                      ),
                      ...allInspirationMascotDomains.map((domain) {
                        final meta = inspirationMascotFor(domain)!;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(meta.displayName),
                            selected: _config.mascotDomain == domain,
                            onSelected: (_) => setState(() {
                              _config = _config.copyWith(mascotDomain: domain);
                            }),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isExporting ? null : () => _exportCard(share: false),
                        icon: const Icon(Icons.save_alt_rounded, size: 18),
                        label: Text(l10n.pick('Export PNG', 'Simpan PNG')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            _isExporting ? null : () => _exportCard(share: true),
                        icon: _isExporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.share_rounded, size: 18),
                        label: Text(l10n.pick('Share Card', 'Bagikan')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary(context),
        ),
      ),
    );
  }
}

class _PalettePreset {
  final String id;
  final String name;
  final List<Color> colors;
  final Color textColor;
  final bool isGradient;

  const _PalettePreset({
    required this.id,
    required this.name,
    required this.colors,
    required this.textColor,
    required this.isGradient,
  });
}
