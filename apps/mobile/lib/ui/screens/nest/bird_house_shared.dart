import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_provider.dart';

/// Safely watches [T] from Provider without throwing if a minimal test tree
/// omits optional domain providers.
T? tryWatchProvider<T>(BuildContext context) {
  try {
    return Provider.of<T>(context);
  } on ProviderNotFoundException {
    return null;
  }
}

/// Safely reads [T] without listening.
T? tryReadProvider<T>(BuildContext context) {
  try {
    return Provider.of<T>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

/// Unified borderless surface decoration for Bird House Hero cards and tool
/// tiles: `#FFFFFF` + soft diffused shadow on `#F4F6F9` in Light Mode, and
/// `#1A1B20` on `#111215` in Dark Mode, with optional subtle `4–6%` top tint
/// for Hero cards.
BoxDecoration birdHouseCardDecoration(
  BuildContext context, {
  Color? heroTintColor,
  double radius = 18,
}) {
  final isDark = AppColors.isDark(context);
  final baseSurface = AppColors.cardSurface(context);
  final topTint = heroTintColor != null
      ? Color.lerp(baseSurface, heroTintColor, isDark ? 0.06 : 0.05)!
      : null;

  return BoxDecoration(
    color: topTint == null ? baseSurface : null,
    gradient: topTint != null
        ? LinearGradient(
            colors: [topTint, baseSurface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: isDark
        ? null
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
  );
}

/// Soft radial domain-tinted glow (`12–16%` opacity) anchored behind each Hero
/// bird sprite so dark feathers stay crisp on dark and light surfaces alike.
class BirdHeroSpriteHalo extends StatelessWidget {
  final String assetPath;
  final Color accentColor;
  final IconData fallbackIcon;
  final double size;

  const BirdHeroSpriteHalo({
    super.key,
    required this.assetPath,
    required this.accentColor,
    required this.fallbackIcon,
    this.size = 82,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accentColor.withValues(alpha: isDark ? 0.16 : 0.13),
            accentColor.withValues(alpha: 0.0),
          ],
          stops: const [0.35, 1.0],
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          fallbackIcon,
          size: size * 0.54,
          color: accentColor,
        ),
      ),
    );
  }
}

/// Borderless `999dp` status pill with a `6dp` colored status dot and crisp
/// `AppColors.textPrimary(context)` ink.
class BirdStatusPill extends StatelessWidget {
  final String label;
  final Color dotColor;
  final bool tabular;
  final Key? pillKey;

  const BirdStatusPill({
    super.key,
    required this.label,
    required this.dotColor,
    this.tabular = false,
    this.pillKey,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      key: pillKey,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                fontFeatures:
                    tabular ? const [FontFeature.tabularFigures()] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clean shared AppBar for every Bird House screen: Back arrow, House title,
/// and subtle subtitle (no redundant boxed bird avatar).
PreferredSizeWidget buildBirdHouseAppBar(
  BuildContext context, {
  required String title,
  required String subtitle,
  String? spriteAsset,
  Color? accentColor,
  IconData? fallbackIcon,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    titleSpacing: 4,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    ),
    actions: actions,
    bottom: bottom,
  );
}

/// Section header inside a Bird House screen.
class BirdSectionLabel extends StatelessWidget {
  final String text;
  final Color? accentColor;

  const BirdSectionLabel({
    super.key,
    required this.text,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (accentColor != null) ...[
            Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Borderless scannable tool tile used inside each Bird House's 2-column grid.
class BirdToolTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final Widget? trailingBadge;
  final Key? tileKey;

  const BirdToolTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.trailingBadge,
    this.tileKey,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return InkWell(
      key: tileKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.all(16),
        decoration: birdHouseCardDecoration(context, radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.16 : 0.11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: accentColor,
                  ),
                ),
                const Spacer(),
                if (trailingBadge != null)
                  trailingBadge!
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary(context),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.25,
                color: AppColors.textSecondary(context),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a responsive 2-column grid of equal-height rows without fixed aspect
/// ratios, preventing RenderFlex overflows on narrow screens (`<= 390dp`).
class BirdToolGrid extends StatelessWidget {
  final List<Widget> tiles;
  final double spacing;

  const BirdToolGrid({
    super.key,
    required this.tiles,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final left = tiles[i];
      final right = i + 1 < tiles.length ? tiles[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < tiles.length ? spacing : 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: left),
                SizedBox(width: spacing),
                Expanded(child: right ?? const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Wraps an existing embedded sub-screen (such as `CalendarScreen` or
/// `DiaryEntriesScreen`) with a clean Back AppBar and optional Diary auto-lock
/// lifecycle hooks.
class BirdToolPageScaffold extends StatefulWidget {
  final String title;
  final Widget child;
  final bool trackDiaryLifecycle;

  const BirdToolPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.trackDiaryLifecycle = false,
  });

  @override
  State<BirdToolPageScaffold> createState() => _BirdToolPageScaffoldState();
}

class _BirdToolPageScaffoldState extends State<BirdToolPageScaffold> {
  SettingsProvider? _settingsProvider;

  @override
  void initState() {
    super.initState();
    if (widget.trackDiaryLifecycle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _settingsProvider = tryReadProvider<SettingsProvider>(context);
        _settingsProvider?.notifyDiaryEntered();
      });
    }
  }

  @override
  void dispose() {
    if (widget.trackDiaryLifecycle) {
      _settingsProvider?.notifyDiaryLeft();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: widget.child,
    );
  }
}

/// Wraps two closely related sub-screens (e.g. Tasks & Routines, or Memories &
/// Timeline) in a clean 2-tab page with a back button.
class BirdTwoTabPageScaffold extends StatelessWidget {
  final String title;
  final Color accentColor;
  final String firstLabel;
  final IconData firstIcon;
  final Widget firstChild;
  final String secondLabel;
  final IconData secondIcon;
  final Widget secondChild;
  final int initialIndex;

  const BirdTwoTabPageScaffold({
    super.key,
    required this.title,
    required this.accentColor,
    required this.firstLabel,
    required this.firstIcon,
    required this.firstChild,
    required this.secondLabel,
    required this.secondIcon,
    required this.secondChild,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(
            indicatorColor: accentColor,
            labelColor: accentColor,
            unselectedLabelColor: AppColors.textSecondary(context),
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(icon: Icon(firstIcon, size: 18), text: firstLabel),
              Tab(icon: Icon(secondIcon, size: 18), text: secondLabel),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            firstChild,
            secondChild,
          ],
        ),
      ),
    );
  }
}
