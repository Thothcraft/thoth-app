import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// Community Screen - Forums, success stories, challenges
/// Mirrors website Community.vue functionality
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryBlue,
                  AppColors.primaryBlue.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Thoth Community: Collaborate & Create',
                  style: AppTextStyles.heroTitle.copyWith(
                    fontSize: 36,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Text(
                    'Free tier users: Share projects in forums. Paid/Org: Host private federated sessions. Login to connect.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white.withOpacity(0.9),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryBlue,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text('Join Community'),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _launchUrl(AppConstants.portalUrl),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text('Login to Portal'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Community Resources
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Community Resources',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildResourceCard(Icons.forum, 'Discussion Forums', 'Connect with fellow innovators, ask questions, and share your discoveries. Open to all free tier users.')),
                          const SizedBox(width: 16),
                          Expanded(child: _buildResourceCard(Icons.book, 'Documentation', 'Comprehensive guides, tutorials, and API documentation to help you get the most out of your Thoth device.')),
                          const SizedBox(width: 16),
                          Expanded(child: _buildResourceCard(Icons.code, 'Open Source', 'Contribute to Thoth\'s development, share custom sensors, and collaborate on community-driven features.')),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildResourceCard(Icons.forum, 'Discussion Forums', 'Connect with fellow innovators, ask questions, and share your discoveries. Open to all free tier users.'),
                        const SizedBox(height: 16),
                        _buildResourceCard(Icons.book, 'Documentation', 'Comprehensive guides, tutorials, and API documentation to help you get the most out of your Thoth device.'),
                        const SizedBox(height: 16),
                        _buildResourceCard(Icons.code, 'Open Source', 'Contribute to Thoth\'s development, share custom sensors, and collaborate on community-driven features.'),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Success Stories
          Container(
            color: AppColors.backgroundSecondaryLight,
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Success Stories',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'See how our community members are using Thoth to innovate',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildSuccessStory(Icons.school, 'Student Success', 'Computer Science Student', 'Used free sensors + Obsidian for thesis notes—boosted my grades! The integration made it so easy to organize my research data and findings.', Colors.blue)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildSuccessStory(Icons.science, 'Research Breakthrough', 'PhD Researcher', 'Trained models across 10 devices with privacy—published in IEEE. The federated learning capabilities opened up entirely new research possibilities.', Colors.green)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildSuccessStory(Icons.build, 'Maker Innovation', 'Hardware Maker', 'Extended with custom ESP code—collaborated globally via portal. The open-source nature let me build exactly what I envisioned.', Colors.orange)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildSuccessStory(Icons.school, 'Student Success', 'Computer Science Student', 'Used free sensors + Obsidian for thesis notes—boosted my grades! The integration made it so easy to organize my research data and findings.', Colors.blue),
                        const SizedBox(height: 16),
                        _buildSuccessStory(Icons.science, 'Research Breakthrough', 'PhD Researcher', 'Trained models across 10 devices with privacy—published in IEEE. The federated learning capabilities opened up entirely new research possibilities.', Colors.green),
                        const SizedBox(height: 16),
                        _buildSuccessStory(Icons.build, 'Maker Innovation', 'Hardware Maker', 'Extended with custom ESP code—collaborated globally via portal. The open-source nature let me build exactly what I envisioned.', Colors.orange),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Community Stats
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Community by the Numbers',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 32,
                      crossAxisSpacing: 32,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard('500+', 'Active Users'),
                        _buildStatCard('1,200+', 'Projects Shared'),
                        _buildStatCard('50+', 'Countries'),
                        _buildStatCard('25+', 'Universities'),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Community Challenges
          Container(
            color: AppColors.backgroundSecondaryLight,
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Community Challenges',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Join monthly contests and collaborative projects',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildChallengeCard(Icons.emoji_events, 'Monthly Federated Learning Contest', 'Collaborate with researchers worldwide to train models on distributed datasets. This month\'s challenge: Environmental monitoring across continents.', 'Active', '15 participants')),
                          const SizedBox(width: 16),
                          Expanded(child: _buildChallengeCard(Icons.lightbulb, 'Innovation Showcase', 'Share your most creative Thoth applications. From smart gardens to AI-powered art installations—show us what you\'ve built!', 'Ongoing', '32 submissions')),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildChallengeCard(Icons.emoji_events, 'Monthly Federated Learning Contest', 'Collaborate with researchers worldwide to train models on distributed datasets. This month\'s challenge: Environmental monitoring across continents.', 'Active', '15 participants'),
                        const SizedBox(height: 16),
                        _buildChallengeCard(Icons.lightbulb, 'Innovation Showcase', 'Share your most creative Thoth applications. From smart gardens to AI-powered art installations—show us what you\'ve built!', 'Ongoing', '32 submissions'),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Final CTA
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Ready to Join the Community?',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 32,
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connect with innovators worldwide, share your projects, and collaborate on the future of AI/IoT.',
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
                      onPressed: () => _launchUrl(AppConstants.portalUrl),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text('Login & Join a Challenge'),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text('Browse Projects'),
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

  Widget _buildResourceCard(IconData icon, String title, String description) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.primaryBlue),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.h4.copyWith(color: AppColors.textPrimaryLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {},
              child: const Text('Learn More'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessStory(IconData icon, String title, String role, String quote, Color color) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.h4.copyWith(color: AppColors.textPrimaryLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              quote,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                role,
                style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String number, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          number,
          style: AppTextStyles.heroTitle.copyWith(
            fontSize: 48,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildChallengeCard(IconData icon, String title, String description, String status, String participants) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.h4.copyWith(color: AppColors.textPrimaryLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(status),
                  backgroundColor: AppColors.success.withOpacity(0.2),
                  labelStyle: const TextStyle(color: AppColors.success, fontSize: 12),
                ),
                Chip(
                  label: Text(participants),
                  backgroundColor: AppColors.textTertiaryLight.withOpacity(0.2),
                  labelStyle: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _launchUrl(AppConstants.portalUrl),
                child: const Text('Join Challenge'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
