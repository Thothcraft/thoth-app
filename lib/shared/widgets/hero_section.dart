import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Hero section widget for landing pages
class HeroSection extends StatelessWidget {
  const HeroSection({
    required this.title,
    required this.subtitle,
    this.primaryButtonText,
    this.secondaryButtonText,
    this.backgroundImage,
    this.onPrimaryTap,
    this.onSecondaryTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? primaryButtonText;
  final String? secondaryButtonText;
  final String? backgroundImage;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundLight,
            AppColors.backgroundSecondaryLight,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: AppTextStyles.heroTitle.copyWith(
              color: AppColors.textPrimaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              subtitle,
              style: AppTextStyles.heroSubtitle.copyWith(
                color: AppColors.textTertiaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (primaryButtonText != null || secondaryButtonText != null)
            const SizedBox(height: 48),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              if (primaryButtonText != null)
                ElevatedButton(
                  onPressed: onPrimaryTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Text(primaryButtonText!),
                  ),
                ),
              if (secondaryButtonText != null)
                OutlinedButton(
                  onPressed: onSecondaryTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Text(secondaryButtonText!),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
