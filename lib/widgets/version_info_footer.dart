import 'package:flutter/material.dart';
import '../config/app_config.dart';

class VersionInfoFooter extends StatelessWidget {
  final bool showBuild;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final bool isDiscrete;

  const VersionInfoFooter({
    super.key,
    this.showBuild = true,
    this.textColor,
    this.padding,
    this.isDiscrete = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = textColor ??
        theme.colorScheme.onSurfaceVariant.withValues(
          alpha: (0.7 * 255).toDouble(),
        );

    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        showBuild
            ? 'v${AppConfig.appVersion} (${AppConfig.buildNumber})'
            : 'v${AppConfig.appVersion}',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: isDiscrete ? 10 : 11,
          fontWeight: isDiscrete ? FontWeight.normal : FontWeight.w500,
        ),
      ),
    );
  }
}
