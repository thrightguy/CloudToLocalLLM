import 'package:flutter/material.dart';

/// A card component with default Material styles
class ThemedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool showBorder;
  final bool showShadow;
  final Color? backgroundColor;
  final Color? borderColor;

  const ThemedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.showBorder = true,
    this.showShadow = true,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? const EdgeInsets.all(8),
      color: backgroundColor ?? Theme.of(context).cardColor,
      elevation: showShadow ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: showBorder
            ? BorderSide(color: borderColor ?? Colors.grey.withOpacity(0.27), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }
}

/// A specialized card for displaying information with title and description
class InfoCard extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? content;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final List<Widget>? actions;

  const InfoCard({
    super.key,
    required this.title,
    this.description,
    this.content,
    this.icon,
    this.iconColor,
    this.onTap,
    this.padding,
    this.margin,
    this.width,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return ThemedCard(
      onTap: onTap,
      padding: padding,
      margin: margin,
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: iconColor ?? Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (content != null) ...[
            const SizedBox(height: 16),
            content!,
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}

/// A feature card for highlighting key features
class FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  const FeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.iconColor,
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return ThemedCard(
      onTap: onTap,
      margin: margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: (iconColor ?? Theme.of(context).primaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: iconColor ?? Theme.of(context).primaryColor,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
