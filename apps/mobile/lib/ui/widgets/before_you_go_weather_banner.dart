import 'package:material_ui/material_ui.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/before_you_go.dart';
import '../../data/services/weather_service.dart';
import '../../providers/before_you_go_provider.dart';

/// Shared adaptive weather-aware prompt banner used by [BeforeYouGoCard]
/// (`compact: true`) and [BeforeYouGoSheet] (`compact: false`).
class BeforeYouGoWeatherBanner extends StatelessWidget {
  final BeforeYouGoProvider provider;
  final bool compact;
  final bool borderless;
  final Color? stripTintColor;

  const BeforeYouGoWeatherBanner({
    super.key,
    required this.provider,
    this.compact = false,
    this.borderless = false,
    this.stripTintColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final langCode = l10n.isIndonesian ? 'id' : 'en';
    final weather = provider.currentWeather;
    final preset = provider.activePreset;

    if (weather == null) {
      return const SizedBox.shrink();
    }

    final suggestions = provider.suggestedWeatherItemsForPreset(preset);
    final dismissed = provider.dismissedWeatherSuggestionsForPreset(preset);

    if (compact && suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final visual = resolveWeatherVisual(context, weather);
    final tint = visual.color;
    final isDark = AppColors.isDark(context);
    final effectiveStripTint = stripTintColor ?? tint;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: borderless
          ? BoxDecoration(
              color: effectiveStripTint.withValues(alpha: isDark ? 0.10 : 0.08),
              borderRadius: BorderRadius.circular(14),
            )
          : BoxDecoration(
              color: AppColors.recessedSurface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: suggestions.isNotEmpty
                    ? tint.withValues(alpha: 0.36)
                    : AppColors.border(context),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(visual.icon, size: 15, color: tint),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  compact
                      ? _advisorySummary(l10n, weather)
                      : '${weather.temperatureCelsius.round()}°C • ${weather.condition} (${weather.rainChancePercent}% ${l10n.tr('rain')})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              if (suggestions.length >= 2)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => _handleAddAll(context, preset, suggestions, langCode, l10n),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.tr('add_all', {'suggestions_length': suggestions.length}),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tint,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!compact) ...[
                const SizedBox(width: 6),
                _ScenarioPickerPill(
                  provider: provider,
                  langCode: langCode,
                  tint: tint,
                ),
              ],
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            if (!compact) ...[
              const SizedBox(height: 6),
              Text(
                l10n.tr('scout_suggests_for', {'preset_name': preset.name}),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: suggestions
                  .map(
                    (suggestion) => _SuggestionActionChip(
                      suggestion: suggestion,
                      langCode: langCode,
                      tint: tint,
                      borderless: borderless,
                      onAdd: () => _handleAddSingle(
                        context,
                        preset,
                        suggestion,
                        langCode,
                        l10n,
                      ),
                      onDismiss: () => provider.dismissWeatherSuggestion(
                        preset.id,
                        suggestion.key,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else if (!compact && dismissed.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  size: 13,
                  color: AppColors.textSecondary(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.tr('weather_suggestion_s_hidden_for', {'dismissed_length': dismissed.length, 'preset_name': preset.name}),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      provider.restoreDismissedWeatherSuggestions(preset.id),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(
                    l10n.tr('show', {'dismissed_length': dismissed.length}),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tint,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (!compact && weather.hasBeforeYouGoAdvisories) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.tr('already_covers_today_s_weather_gear', {'preset_name': preset.name}),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (!compact) ...[
            const SizedBox(height: 5),
            Text(
              l10n.tr('no_extra_rain_or_cool_weather'),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAddSingle(
    BuildContext context,
    DeparturePreset preset,
    WeatherSuggestedItem suggestion,
    String langCode,
    AppLocalizations l10n,
  ) async {
    final label = suggestion.localizedLabel(langCode);
    final added = await provider.addWeatherSuggestionToPreset(
      preset.id,
      suggestion,
      localizedLabelOverride: label,
    );
    if (!context.mounted || !added) return;
    _showSnack(
      context,
      l10n.tr('added_to', {'label': label, 'preset_name': preset.name}),
    );
  }

  Future<void> _handleAddAll(
    BuildContext context,
    DeparturePreset preset,
    List<WeatherSuggestedItem> suggestions,
    String langCode,
    AppLocalizations l10n,
  ) async {
    final count = await provider.addAllWeatherSuggestionsToPreset(
      preset.id,
      languageCode: langCode,
    );
    if (!context.mounted || count == 0) return;
    _showSnack(
      context,
      l10n.tr('added_weather_items_to', {'count': count, 'preset_name': preset.name}),
    );
  }

  void _showSnack(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _advisorySummary(AppLocalizations l10n, WeatherInfo weather) {
    if (weather.isRainy && weather.isCool) {
      return l10n.tr('rain_cool_c', {'weather_round': weather.temperatureCelsius.round(), 'weather_rainChancePercent': weather.rainChancePercent});
    }
    if (weather.isRainy) {
      return l10n.tr('rain_likely', {'weather_rainChancePercent': weather.rainChancePercent, 'weather_condition': weather.condition});
    }
    return l10n.tr('cool_weather_c_low_c', {'weather_round': weather.lowTemp.round()});
  }

  /// Maps weather condition intensity to a crisp Material icon & theme-adaptive accent tint.
  static ({IconData icon, Color color}) resolveWeatherVisual(
    BuildContext context,
    WeatherInfo weather,
  ) {
    if (weather.isHeavyRain) {
      return (
        icon: Icons.thunderstorm_rounded,
        color: AppColors.adaptive(
          context,
          dark: AppColors.sky,
          light: AppColors.skyDeep,
        ),
      );
    }
    if (weather.isRainy) {
      return (
        icon: Icons.umbrella_rounded,
        color: AppColors.adaptive(
          context,
          dark: AppColors.scoutLight,
          light: AppColors.scoutDark,
        ),
      );
    }
    if (weather.isCool) {
      return (
        icon: weather.isCold ? Icons.ac_unit_rounded : Icons.air_rounded,
        color: AppColors.adaptive(
          context,
          dark: AppColors.sky,
          light: AppColors.skyDark,
        ),
      );
    }
    return (
      icon: Icons.wb_sunny_rounded,
      color: AppColors.adaptive(
        context,
        dark: AppColors.accent,
        light: AppColors.twillDark,
      ),
    );
  }
}

class _SuggestionActionChip extends StatelessWidget {
  final WeatherSuggestedItem suggestion;
  final String langCode;
  final Color tint;
  final bool borderless;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  const _SuggestionActionChip({
    required this.suggestion,
    required this.langCode,
    required this.tint,
    this.borderless = false,
    required this.onAdd,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final label = suggestion.localizedLabel(langCode);
    final isDark = AppColors.isDark(context);
    return Container(
      decoration: borderless
          ? BoxDecoration(
              color: tint.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(999),
            )
          : BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tint.withValues(alpha: 0.4)),
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onAdd,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 5, 6, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(suggestion.icon, size: 13, color: tint),
                  const SizedBox(width: 4),
                  Text(
                    '+ $label',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onDismiss,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 5, 8, 5),
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioPickerPill extends StatelessWidget {
  final BeforeYouGoProvider provider;
  final String langCode;
  final Color tint;

  const _ScenarioPickerPill({
    required this.provider,
    required this.langCode,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final current = provider.localWeatherScenario;
    return PopupMenuButton<LocalWeatherScenario>(
      tooltip: context.l10n.tr('local_weather_condition'),
      onSelected: (scenario) => provider.setLocalWeatherScenario(scenario),
      itemBuilder: (context) => LocalWeatherScenario.values
          .map(
            (scenario) => PopupMenuItem<LocalWeatherScenario>(
              value: scenario,
              child: Row(
                children: [
                  Icon(
                    scenario == current
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 16,
                    color: scenario == current ? tint : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    scenario.localizedLabel(langCode),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: scenario == current
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.localizedLabel(langCode),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 15,
              color: AppColors.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}
