import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/config/theme.dart';

/// A card component that matches the homepage design system
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
    return Container(
      width: width,
      height: height,
      margin: margin ?? const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor ?? CloudToLocalLLMTheme.backgroundCard,
        borderRadius: BorderRadius.circular(CloudToLocalLLMTheme.borderRadius),
        border: showBorder
            ? Border.all(
                color: borderColor ?? CloudToLocalLLMTheme.secondaryColor.withValues(alpha: 0.27),
                width: 1.5,
              )
            : null,
        boxShadow: showShadow ? CloudToLocalLLMTheme.cardShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CloudToLocalLLMTheme.borderRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.all(24),
            child: child,
          ),
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
          // Header with icon and title
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: iconColor ?? CloudToLocalLLMTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: CloudToLocalLLMTheme.primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: CloudToLocalLLMTheme.fontFamily,
                  ),
                ),
              ),
            ],
          ),

          // Description
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: const TextStyle(
                color: CloudToLocalLLMTheme.textColorLight,
                fontSize: 14,
                height: 1.5,
                fontFamily: CloudToLocalLLMTheme.fontFamily,
              ),
            ),
          ],

          // Custom content
          if (content != null) ...[
            const SizedBox(height: 16),
            content!,
          ],

          // Actions
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
          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: (iconColor ?? CloudToLocalLLMTheme.primaryColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: iconColor ?? CloudToLocalLLMTheme.primaryColor,
              size: 30,
            ),
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CloudToLocalLLMTheme.primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: CloudToLocalLLMTheme.fontFamily,
            ),
          ),

          const SizedBox(height: 8),

          // Description
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CloudToLocalLLMTheme.textColorLight,
              fontSize: 14,
              height: 1.5,
              fontFamily: CloudToLocalLLMTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
