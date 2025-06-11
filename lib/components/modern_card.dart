import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Modern card component with hover effects matching homepage design
class ModernCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool enableHover;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.enableHover = true,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    if (!widget.enableHover) return;

    setState(() => _isHovered = isHovered);
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return MouseRegion(
          onEnter: (_) => _onHover(true),
          onExit: (_) => _onHover(false),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              margin: widget.margin ?? EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.backgroundCard,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                border: Border.all(
                  color: _isHovered
                      ? AppTheme.primaryColor
                      : AppTheme.secondaryColor.withValues(alpha: 0.27),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? AppTheme.primaryColor.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.4),
                    blurRadius: _isHovered ? 32 : 24,
                    offset: Offset(0, _isHovered ? 8 : 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                child: widget.onTap != null
                    ? InkWell(
                        onTap: widget.onTap,
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusM,
                        ),
                        child: Container(
                          padding:
                              widget.padding ??
                              EdgeInsets.all(AppTheme.spacingL),
                          child: widget.child,
                        ),
                      )
                    : Container(
                        padding:
                            widget.padding ?? EdgeInsets.all(AppTheme.spacingL),
                        child: widget.child,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Info card component for displaying feature information
class InfoCard extends StatelessWidget {
  final String title;
  final String description;
  final List<String>? features;
  final Widget? action;
  final IconData? icon;
  final Color? iconColor;

  const InfoCard({
    super.key,
    required this.title,
    required this.description,
    this.features,
    this.action,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with icon and title
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppTheme.primaryColor).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppTheme.spacingM),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AppTheme.spacingM),

          // Description
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textColorLight,
              fontSize: 16,
              height: 1.5,
            ),
          ),

          // Features list
          if (features != null && features!.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingL),
            ...features!.map(
              (feature) => Padding(
                padding: EdgeInsets.only(bottom: AppTheme.spacingS),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Text(
                        feature,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textColor,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Action button
          if (action != null) ...[SizedBox(height: AppTheme.spacingL), action!],
        ],
      ),
    );
  }
}
