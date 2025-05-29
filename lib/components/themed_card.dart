import 'package:flutter/material.dart';

/// A custom card component that matches the website's card styling
class ThemedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double elevation;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  
  const ThemedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.elevation = 4.0,
    this.borderRadius,
    this.borderColor,
    this.borderWidth = 1.5,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16.0);
    final border = borderColor != null
        ? Border.all(color: borderColor!, width: borderWidth)
        : Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: borderWidth,
          );
    
    final cardContent = Padding(
      padding: padding,
      child: child,
    );
    
    return Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: borderColor ?? Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: borderWidth,
        ),
      ),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: cardContent,
            )
          : cardContent,
    );
  }
}