import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shop Screen - Browse and purchase Thoth kits
/// Mirrors website Shop.vue functionality
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero Section
          Container(
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
              children: [
                Text(
                  'Shop Thoth Kits: Start Building Today',
                  style: AppTextStyles.heroTitle.copyWith(
                    fontSize: 36,
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Text(
                    'Kits include Raspberry Pi, ESP32, Sense HAT sensors, camera, 500mAh battery, and case. Pair with a plan for full unlock.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Product Cards
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Choose Your Kit',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildStarterKit(context)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildProKit(context)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildClassroomBundle(context)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildStarterKit(context),
                        const SizedBox(height: 16),
                        _buildProKit(context),
                        const SizedBox(height: 16),
                        _buildClassroomBundle(context),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Portal Login Reminder
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimaryLight,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Post-Purchase: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: 'Login to Portal for setup guide and full device configuration.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // What's Included Section
          Container(
            color: AppColors.backgroundSecondaryLight,
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'What\'s in Every Kit',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900
                        ? 4
                        : constraints.maxWidth > 600
                            ? 2
                            : 1;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 32,
                      crossAxisSpacing: 32,
                      childAspectRatio: 1.0,
                      children: [
                        _buildComponentCard(
                          Icons.memory,
                          'Raspberry Pi 4',
                          'Powerful ARM-based computer for AI processing',
                        ),
                        _buildComponentCard(
                          Icons.wifi,
                          'ESP32 Module',
                          'Wireless connectivity and edge computing',
                        ),
                        _buildComponentCard(
                          Icons.sensors,
                          'Sensor Suite',
                          'Environmental, motion, and visual sensors',
                        ),
                        _buildComponentCard(
                          Icons.battery_charging_full,
                          'Portable Power',
                          '500mAh battery in durable case',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // CTA Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Ready to Start Your AI/IoT Journey?',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Text(
                    'Join hundreds of students, researchers, and makers who are already building the future with Thoth.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => _launchUrl(AppConstants.portalUrl),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Shop Now'),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.pushNamed(context, '/plans'),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Compare Plans'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarterKit(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Starter Kit',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$99',
              style: AppTextStyles.heroTitle.copyWith(
                fontSize: 48,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'For students/makers: Core sensors + free tier access. \'Your first AI project, out-of-the-box.\' Includes curriculum basics.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            _buildFeatureList([
              'Raspberry Pi 4',
              'ESP32 Module',
              'Basic Sensors',
              'Durable Case',
              'Free Tier Access',
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _launchUrl(AppConstants.portalUrl),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Buy & Login'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProKit(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryBlue, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.primaryBlue.withOpacity(0.02),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pro Kit',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.primaryBlue,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Popular',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '\$149',
              style: AppTextStyles.heroTitle.copyWith(
                fontSize: 48,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'For researchers: Full camera + paid tier trial. \'Deep learning ready—collaborate securely.\'',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            _buildFeatureList([
              'Everything in Starter',
              'High-Quality Camera',
              'Advanced Sensors',
              '1-Month Paid Tier Trial',
              'Deep Learning Ready',
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _launchUrl(AppConstants.portalUrl),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Buy & Login'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassroomBundle(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Classroom Bundle',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$499',
              style: AppTextStyles.heroTitle.copyWith(
                fontSize: 48,
                color: AppColors.textPrimaryLight,
              ),
            ),
            Text(
              '5 units',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'For organizations: Education kit + custom plan. \'Equip your lab for collaborative innovation.\'',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            _buildFeatureList([
              '5x Starter Kits',
              'Education Curriculum',
              'Team Dashboard',
              'Instructor Support',
              'Custom Plan Access',
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _launchUrl(AppConstants.portalUrl),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Contact Sales'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList(List<String> features) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 20,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feature,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildComponentCard(IconData icon, String title, String description) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: AppColors.primaryBlue),
        const SizedBox(height: 16),
        Text(
          title,
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
