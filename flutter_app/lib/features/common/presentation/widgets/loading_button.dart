import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class LoadingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const LoadingButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    required this.text,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 50,
    this.borderRadius = 10,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: textColor ?? Colors.white,
          disabledBackgroundColor: (backgroundColor ?? AppColors.primary).withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: padding,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class LoadingIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData icon;
  final Color? color;
  final double size;
  final String? tooltip;

  const LoadingIconButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    required this.icon,
    this.color,
    this.size = 24,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  color ?? AppColors.primary,
                ),
              ),
            )
          : Icon(icon, size: size, color: color),
      tooltip: tooltip,
    );
  }
}

class OutlinedLoadingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;
  final IconData? icon;
  final Color? borderColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;

  const OutlinedLoadingButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    required this.text,
    this.icon,
    this.borderColor,
    this.textColor,
    this.width,
    this.height = 50,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final color = borderColor ?? AppColors.primary;
    
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? color,
          side: BorderSide(color: isLoading ? color.withOpacity(0.5) : color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class ActionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isSelected;
  final Color? selectedColor;

  const ActionChip({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isSelected = false,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppColors.primary;
    
    return Material(
      color: isSelected ? color.withOpacity(0.1) : AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? Border.all(color: color) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

