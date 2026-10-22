import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum CardVariant { outlined, elevated, filled }

class AppCard extends StatelessWidget {
  final Widget child;
  final CardVariant variant;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.variant = CardVariant.outlined,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Border? border;
    List<BoxShadow>? shadows;

    switch (variant) {
      case CardVariant.outlined:
        bg = backgroundColor ?? Colors.white;
        border = Border.all(color: borderColor ?? AppColors.borderLight);
        break;
      case CardVariant.elevated:
        bg = backgroundColor ?? Colors.white;
        shadows = [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
        break;
      case CardVariant.filled:
        bg = backgroundColor ?? AppColors.backgroundLight;
        break;
    }

    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: border,
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: container,
      );
    }

    return container;
  }
}
