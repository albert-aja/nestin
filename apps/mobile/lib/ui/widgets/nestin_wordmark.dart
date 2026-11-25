import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

/// Custom geometric lowercase `"nestin"` wordmark matching `assets/banner.jpg`:
/// - **`nest`** in dark charcoal (`#2D3036` Light Mode / crisp off-white `#F3F5F7` Dark Mode)
/// - **`in`** in Nestin Leaf Green (`#649330` Light Mode / `#7CB342` Dark Mode)
///
/// Pass [onDarkBackdrop] = `true` when rendering over illustrated sky artwork
/// (e.g. Treehouse Scene mode) so the wordmark stays crisp in both Light and Dark themes.
class NestinWordmark extends StatelessWidget {
  final double fontSize;
  final bool onDarkBackdrop;
  final Key? textKey;

  const NestinWordmark({
    super.key,
    this.fontSize = 24.0,
    this.onDarkBackdrop = false,
    this.textKey,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final useLightInk = onDarkBackdrop || isDark;
    final nestColor =
        useLightInk ? AppColors.wordmarkOffWhite : AppColors.wordmarkCharcoal;
    final inColor = useLightInk ? AppColors.primaryLight : AppColors.primary;
    final shadows = onDarkBackdrop
        ? const [
            Shadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 1),
            ),
          ]
        : null;

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          height: 1.0,
          fontFamilyFallback: const [
            'Nunito',
            'Quicksand',
            'SF Pro Rounded',
            'Roboto',
          ],
          shadows: shadows,
        ),
        children: [
          TextSpan(
            text: 'nest',
            style: TextStyle(color: nestColor),
          ),
          TextSpan(
            text: 'in',
            style: TextStyle(color: inColor),
          ),
        ],
      ),
      key: textKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: 'Nestin',
    );
  }
}
