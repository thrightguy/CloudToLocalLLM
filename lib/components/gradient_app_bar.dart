import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/config/theme.dart';

/// A custom app bar with gradient background matching the homepage design
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
    return Container(
      decoration: const BoxDecoration(
        gradient: CloudToLocalLLMTheme.headerGradient,
        boxShadow: CloudToLocalLLMTheme.smallShadow,
      ),
      child: AppBar(
        title: showLogo ? _buildTitleWithLogo() : _buildTitle(),
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: centerTitle,
        titleSpacing: titleSpacing,
        toolbarHeight: toolbarHeight,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
    );
  }

  Widget _buildTitle() {
    if (subtitle != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: CloudToLocalLLMTheme.fontFamily,
            ),
          ),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Color(0xFFe0d7ff), // Light purple from homepage
              fontFamily: CloudToLocalLLMTheme.fontFamily,
            ),
          ),
        ],
      );
    }

    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontFamily: CloudToLocalLLMTheme.fontFamily,
      ),
    );
  }

  Widget _buildTitleWithLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: CloudToLocalLLMTheme.secondaryColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: CloudToLocalLLMTheme.primaryColor,
              width: 2,
            ),
            boxShadow: CloudToLocalLLMTheme.smallShadow,
          ),
          child: const Center(
            child: Text(
              'LLM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: CloudToLocalLLMTheme.fontFamily,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (subtitle != null)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: CloudToLocalLLMTheme.fontFamily,
                ),
              ),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFFe0d7ff),
                  fontFamily: CloudToLocalLLMTheme.fontFamily,
                ),
              ),
            ],
          )
        else
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: CloudToLocalLLMTheme.fontFamily,
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight);
}

/// A large header component matching the homepage hero section
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
      decoration: const BoxDecoration(
        gradient: CloudToLocalLLMTheme.headerGradient,
        boxShadow: CloudToLocalLLMTheme.smallShadow,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          children: [
            // Logo
            if (logo != null) ...[
              logo!,
              const SizedBox(height: 20),
            ] else ...[
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: CloudToLocalLLMTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: CloudToLocalLLMTheme.primaryColor,
                    width: 3,
                  ),
                  boxShadow: CloudToLocalLLMTheme.smallShadow,
                ),
                child: const Center(
                  child: Text(
                    'LLM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: CloudToLocalLLMTheme.fontFamily,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: CloudToLocalLLMTheme.fontFamily,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: Color(0x446e8efb), // rgba(110, 142, 251, 0.27)
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFFe0d7ff), // Light purple from homepage
                fontFamily: CloudToLocalLLMTheme.fontFamily,
              ),
            ),

            // Actions
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
