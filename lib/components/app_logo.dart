import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Custom app logo widget that matches the homepage design
class AppLogo extends StatelessWidget {
  final double size;
  final bool showBorder;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  const AppLogo({
    super.key,
    this.size = 40.0,
    this.showBorder = true,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  /// Large logo for headers and prominent displays
  const AppLogo.large({
    super.key,
    this.size = 70.0,
    this.showBorder = true,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  /// Medium logo for navigation bars
  const AppLogo.medium({
    super.key,
    this.size = 48.0,
    this.showBorder = true,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  /// Small logo for compact spaces
  const AppLogo.small({
    super.key,
    this.size = 32.0,
    this.showBorder = true,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  /// Favicon-sized logo
  const AppLogo.favicon({
    super.key,
    this.size = 16.0,
    this.showBorder = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? AppTheme.secondaryColor;
    final effectiveTextColor = textColor ?? AppTheme.primaryColor;
    final effectiveBorderColor = borderColor ?? AppTheme.primaryColor;

    // Calculate font size based on container size
    final fontSize = size * 0.35; // Approximately 35% of container size
    final borderWidth = size * 0.04; // Approximately 4% of container size

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: effectiveBorderColor, width: borderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: size * 0.1,
            offset: Offset(0, size * 0.03),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'LLM',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: effectiveTextColor,
            letterSpacing: fontSize * 0.02,
          ),
        ),
      ),
    );
  }
}

/// Animated logo widget with hover effects
class AnimatedAppLogo extends StatefulWidget {
  final double size;
  final bool showBorder;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AnimatedAppLogo({
    super.key,
    this.size = 40.0,
    this.showBorder = true,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.onTap,
  });

  @override
  State<AnimatedAppLogo> createState() => _AnimatedAppLogoState();
}

class _AnimatedAppLogoState extends State<AnimatedAppLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AppLogo(
                size: widget.size,
                showBorder: widget.showBorder,
                backgroundColor: widget.backgroundColor,
                textColor: widget.textColor,
                borderColor: widget.borderColor,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Logo with gradient background matching the homepage
class GradientAppLogo extends StatelessWidget {
  final double size;
  final bool showBorder;
  final Color? textColor;
  final Color? borderColor;

  const GradientAppLogo({
    super.key,
    this.size = 40.0,
    this.showBorder = true,
    this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppTheme.primaryColor;

    // Calculate font size based on container size
    final fontSize = size * 0.35;
    final borderWidth = size * 0.04;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.buttonGradient,
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: effectiveBorderColor, width: borderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: size * 0.15,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'LLM',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: fontSize * 0.02,
          ),
        ),
      ),
    );
  }
}
