import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/hero_section.dart';

/// Home Screen - Landing page with hero, value props, and CTAs
/// Merges About content from the website
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero Section
          HeroSection(
            title: 'Thoth',
            subtitle:
                'Revolutionary IoT Device with Raspberry Pi, Sense HAT & PiSugar.\nLearn AI, Build Smart Systems, Join the Future.',
            primaryButtonText: 'Get Started',
            secondaryButtonText: 'Learn More',
            backgroundImage: 'assets/images/hero_bg.jpg',
            onPrimaryTap: () => _launchExternal(AppConstants.frontendUrl),
            onSecondaryTap: () => _scrollToSection(context),
          ),

          // Core Capabilities Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 64),
            child: Column(
              children: [
                Text(
                  'Core Capabilities',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                _buildCapabilitiesGrid(),
              ],
            ),
          ),

          // Mission Section (About merged)
          Container(
            color: AppColors.backgroundSecondaryLight,
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Our Mission',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Text(
                    'Thoth bridges the gap between learning and innovation. We believe in democratizing access to AI and IoT technologies, empowering students, researchers, and makers to build the future with tools that are powerful yet accessible.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 48),
                _buildValuesGrid(),
              ],
            ),
          ),

          // Product Showcase
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Powered by Raspberry Pi & Sense HAT',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Text(
                    'Experience the perfect fusion of Raspberry Pi computing power, Sense HAT environmental sensors, and PiSugar battery management. Collect real-time data, train ML models on-device, and participate in federated learning—all in one portable IoT platform.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                _buildProductCarousel(),
              ],
            ),
          ),

          // Video Tutorials Section
          Container(
            color: AppColors.backgroundSecondaryLight,
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'See It In Action',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Quick tutorials to get you started',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                _buildVideoTutorials(),
              ],
            ),
          ),

          // Pricing Teaser Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Simple Pricing',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                _buildPricingTeaser(context),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/plans'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text('Compare Plans'),
                  ),
                ),
              ],
            ),
          ),

          // CTA Section
          Container(
            color: AppColors.backgroundSecondaryLight,
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Join Our Community',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connect with innovators worldwide. Share ideas. Build together.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/demos'),
                      child: const Text('Explore Demos'),
                    ),
                    OutlinedButton(
                      onPressed: () => _launchExternal(AppConstants.portalUrl),
                      child: const Text('Sign In'),
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

  Widget _buildCapabilitiesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            childAspectRatio: 0.9,
            children: [
              _buildCapabilityCard(
                'AI Processing',
                'On-device machine learning with TensorFlow Lite',
                'assets/images/icons/artificial-intelligence.gif',
              ),
              _buildCapabilityCard(
                'IoT Connectivity',
                'Seamless integration with ESP32 modules',
                'assets/images/icons/iot.gif',
              ),
              _buildCapabilityCard(
                'Data Collection',
                'Multi-sensor array for environmental data',
                'assets/images/icons/data-collection.gif',
              ),
              _buildCapabilityCard(
                'Privacy First',
                'Differential privacy and federated learning',
                'assets/images/icons/privacy.gif',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCapabilityCard(String title, String description, String iconPath) {
    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            iconPath,
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.science, size: 80);
            },
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textPrimaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValuesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 600 ? 3 : 1;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 32,
            crossAxisSpacing: 32,
            childAspectRatio: 1.2,
            children: [
              _buildValueCard(
                Icons.lightbulb_outline,
                'Innovation',
                'Pushing boundaries in AI/IoT integration',
              ),
              _buildValueCard(
                Icons.people_outline,
                'Community',
                'Building a global network of innovators',
              ),
              _buildValueCard(
                Icons.shield_outlined,
                'Privacy',
                'Protecting your data with advanced technologies',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildValueCard(IconData icon, String title, String description) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 48, color: AppColors.textPrimaryLight),
        ),
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

  Widget _buildProductCarousel() {
    return SizedBox(
      height: 300,
      child: PageView(
        children: [
          Image.asset(
            'assets/images/products/white_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppColors.backgroundSecondaryLight,
                child: const Icon(Icons.devices, size: 100),
              );
            },
          ),
          Image.asset(
            'assets/images/products/closeup.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppColors.backgroundSecondaryLight,
                child: const Icon(Icons.devices, size: 100),
              );
            },
          ),
          Image.asset(
            'assets/images/products/lifestyle.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppColors.backgroundSecondaryLight,
                child: const Icon(Icons.devices, size: 100),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTutorials() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            children: [
              Expanded(child: _buildVideoCard('Getting Started', 'Set up your Thoth device in under 60 seconds.', 'assets/videos/getting_started.mp4')),
              const SizedBox(width: 16),
              Expanded(child: _buildVideoCard('First Project', 'Build your first AI/IoT project step by step.', 'assets/videos/first.mp4')),
              const SizedBox(width: 16),
              Expanded(child: _buildVideoCard('Sensor Setup', 'Connect and configure multiple sensors.', 'assets/videos/sensors.mp4')),
            ],
          );
        }
        return Column(
          children: [
            _buildVideoCard('Getting Started', 'Set up your Thoth device in under 60 seconds.', 'assets/videos/getting_started.mp4'),
            const SizedBox(height: 16),
            _buildVideoCard('First Project', 'Build your first AI/IoT project step by step.', 'assets/videos/first.mp4'),
            const SizedBox(height: 16),
            _buildVideoCard('Sensor Setup', 'Connect and configure multiple sensors.', 'assets/videos/sensors.mp4'),
          ],
        );
      },
    );
  }

  Widget _buildVideoCard(String title, String description, String videoPath) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              color: AppColors.backgroundSecondaryLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.play_circle_outline, size: 64, color: AppColors.primaryBlue),
                // TODO: Replace with actual video player widget
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h4.copyWith(color: AppColors.textPrimaryLight),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingTeaser(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPricingCard('Free', null, 'Get started with basic features and community support.', false)),
              const SizedBox(width: 16),
              Expanded(child: _buildPricingCard('Pro', '\$9.99/mo', 'Unlimited computing power and premium features.', true)),
              const SizedBox(width: 16),
              Expanded(child: _buildPricingCard('Enterprise', 'Custom', 'Tailored solutions for organizations.', false)),
            ],
          );
        }
        return Column(
          children: [
            _buildPricingCard('Free', null, 'Get started with basic features and community support.', false),
            const SizedBox(height: 16),
            _buildPricingCard('Pro', '\$9.99/mo', 'Unlimited computing power and premium features.', true),
            const SizedBox(height: 16),
            _buildPricingCard('Enterprise', 'Custom', 'Tailored solutions for organizations.', false),
          ],
        );
      },
    );
  }

  Widget _buildPricingCard(String title, String? price, String description, bool featured) {
    return GlassCard(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: featured
            ? BoxDecoration(
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
              )
            : null,
        child: Column(
          children: [
            Text(
              title,
              style: AppTextStyles.h3.copyWith(
                color: featured ? AppColors.primaryBlue : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            if (price != null)
              Text(
                price,
                style: AppTextStyles.h4.copyWith(
                  color: featured ? AppColors.primaryBlue : AppColors.textSecondaryLight,
                ),
              )
            else
              const SizedBox(height: 28),
            const SizedBox(height: 16),
            Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _launchExternal(String url) {
    // TODO: Implement url_launcher
    debugPrint('Launch: $url');
  }

  void _scrollToSection(BuildContext context) {
    // TODO: Implement smooth scroll
    debugPrint('Scroll to section');
  }
}
