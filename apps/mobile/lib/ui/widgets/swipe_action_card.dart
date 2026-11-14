import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

/// Visual configuration for a directional swipe action background.
class SwipeActionStyle {
  final String label;
  final IconData icon;
  final Color color;

  const SwipeActionStyle({
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Standardized horizontal swipe card across Nestin list screens.
///
/// Swiping right (`startToEnd`) executes [onSwipeRight] in-place (snapping
/// the card back if still in the filtered list), while swiping left
/// (`endToStart`) dismisses the row and triggers [onSwipeLeft].
class SwipeActionCard extends StatelessWidget {
  final Key dismissKey;
  final Widget child;
  final SwipeActionStyle swipeRightStyle;
  final SwipeActionStyle swipeLeftStyle;
  final FutureOr<void> Function() onSwipeRight;
  final FutureOr<void> Function() onSwipeLeft;
  final double borderRadius;

  const SwipeActionCard({
    super.key,
    required this.dismissKey,
    required this.child,
    required this.swipeRightStyle,
    required this.swipeLeftStyle,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.32,
        DismissDirection.endToStart: 0.35,
      },
      background: _SwipeBackground(
        style: swipeRightStyle,
        isLeading: true,
        borderRadius: borderRadius,
      ),
      secondaryBackground: _SwipeBackground(
        style: swipeLeftStyle,
        isLeading: false,
        borderRadius: borderRadius,
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        if (direction == DismissDirection.startToEnd) {
          await onSwipeRight();
          // Return false so in-place toggles (e.g. Pin or unfiltered lists)
          // never leave a dismissed Dismissible still mounted in the tree.
          return false;
        }
        return direction == DismissDirection.endToStart;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onSwipeLeft();
        }
      },
      child: child,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final SwipeActionStyle style;
  final bool isLeading;
  final double borderRadius;

  const _SwipeBackground({
    required this.style,
    required this.isLeading,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = isLight
        ? Color.lerp(style.color, Colors.black, 0.25) ?? style.color
        : style.color;

    final children = <Widget>[
      Icon(style.icon, color: foreground, size: 22),
      const SizedBox(width: 8),
      Text(
        style.label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: foreground,
          letterSpacing: 0.2,
        ),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: isLight ? 0.14 : 0.18),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: style.color.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: isLeading ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeading ? children : children.reversed.toList(),
      ),
    );
  }
}

/// Displays a floating 4-second snackbar with an Undo action.
///
/// Any currently visible snackbar is dismissed first so consecutive swipes
/// never queue stale restore prompts.
void showUndoSnackBar({
  required BuildContext context,
  required String message,
  required FutureOr<void> Function() onUndo,
  Color color = AppColors.accent,
  IconData icon = Icons.check_circle_outline_rounded,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        persist: false,
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.adaptive(
          context,
          dark: const Color(0xFF1F222B),
          light: AppColors.lightTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        content: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: color,
          onPressed: () {
            HapticFeedback.selectionClick();
            onUndo();
          },
        ),
      ),
    );
}
