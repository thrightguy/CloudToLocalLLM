import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/config/theme.dart';

/// A button with gradient background matching the homepage design
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool isLoading;
  final double? width;
  final double? height;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.padding,
    this.fontSize,
    this.fontWeight,
    this.isLoading = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 48,
      decoration: BoxDecoration(
        gradient: CloudToLocalLLMTheme.buttonGradient,
        borderRadius: BorderRadius.circular(CloudToLocalLLMTheme.borderRadiusSmall),
        boxShadow: CloudToLocalLLMTheme.smallShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(CloudToLocalLLMTheme.borderRadiusSmall),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else if (icon != null) ...[
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                ],
                if (!isLoading)
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize ?? 16,
                      fontWeight: fontWeight ?? FontWeight.w600,
                      fontFamily: CloudToLocalLLMTheme.fontFamily,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A secondary button with outline style matching the homepage design
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool isLoading;
  final double? width;
  final double? height;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.padding,
    this.fontSize,
    this.fontWeight,
    this.isLoading = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 48,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(CloudToLocalLLMTheme.borderRadiusSmall),
        border: Border.all(
          color: CloudToLocalLLMTheme.primaryColor,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(CloudToLocalLLMTheme.borderRadiusSmall),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(CloudToLocalLLMTheme.primaryColor),
                    ),
                  )
                else if (icon != null) ...[
                  Icon(
                    icon,
                    color: CloudToLocalLLMTheme.primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                ],
                if (!isLoading)
                  Text(
                    text,
                    style: TextStyle(
                      color: CloudToLocalLLMTheme.primaryColor,
                      fontSize: fontSize ?? 16,
                      fontWeight: fontWeight ?? FontWeight.w600,
                      fontFamily: CloudToLocalLLMTheme.fontFamily,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
