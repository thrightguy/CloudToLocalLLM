import 'package:flutter/material.dart';
import '../config/app_config.dart';

class VersionInfoFooter extends StatelessWidget {
  final bool showBuild;
  final Color? textColor;

  const VersionInfoFooter({
    Key? key,
    this.showBuild = true,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        textColor ?? theme.colorScheme.onSurfaceVariant.withOpacity(0.7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        showBuild
            ? 'CloudToLocalLLM v${AppConfig.appVersion} (${AppConfig.buildNumber})'
            : 'CloudToLocalLLM v${AppConfig.appVersion}',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 11,
        ),
      ),
    );
  }
}
