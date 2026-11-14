import 'package:flutter/material.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/alarm_category.dart';

class CategoryBadge extends StatelessWidget {
  final AlarmCategory category;
  final bool compact;

  const CategoryBadge({
    super.key,
    required this.category,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: category.color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: category.color.withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            category.icon,
            size: compact ? 11 : 13,
            color: category.color,
          ),
          const SizedBox(width: 4),
          Text(
            context.l10n.categoryName(category.type),
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }
}

