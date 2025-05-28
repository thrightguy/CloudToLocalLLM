import 'package:flutter/material.dart';

/// A custom app bar with default Material styles
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final double? elevation;
  final bool centerTitle;
  final double? titleSpacing;
  final double? toolbarHeight;
  final bool showLogo;

  const GradientAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.elevation,
    this.centerTitle = true,
    this.titleSpacing,
    this.toolbarHeight,
    this.showLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      elevation: elevation,
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      toolbarHeight: toolbarHeight,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight);
}

/// A large header component with default Material styles
class HeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? logo;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;

  const HeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.logo,
    this.actions,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).primaryColor,
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          children: [
            if (logo != null) ...[
              logo!,
              const SizedBox(height: 20),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            if (actions != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
