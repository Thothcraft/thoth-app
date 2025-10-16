import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// Plans Screen - Detailed pricing comparison and plan selection
/// Mirrors website Plans.vue functionality
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

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
                  'Thoth Plans: Scale Your Innovation',
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
                    'From free trials to enterprise support—choose what fits your role as student, researcher, or maker.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Plan Comparison Cards
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildFreePlan(context)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildPaidPlan(context)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildOrgPlan(context)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildFreePlan(context),
                    const SizedBox(height: 16),
                    _buildPaidPlan(context),
                    const SizedBox(height: 16),
                    _buildOrgPlan(context),
                  ],
                );
              },
            ),
          ),

          // Detailed Features Section
          Container(
            color: AppColors.backgroundSecondaryLight,
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Compare Features',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildFeatureComparisonTable(),
              ],
            ),
          ),

          // Plan Details Expansions
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Plan Details',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildPlanDetailsExpansion(),
              ],
            ),
          ),

          // FAQ Section
          Container(
            color: AppColors.backgroundSecondaryLight,
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Frequently Asked Questions',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildFAQSection(),
              ],
            ),
          ),

          // CTA Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Ready to Choose Your Plan?',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 32,
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Start with our free plan and upgrade as your projects grow. Join the Thoth community today!',
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
                        child: Text('Select Plan'),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _launchUrl(AppConstants.portalUrl),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text('Login to Manage'),
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

  Widget _buildFreePlan(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Free', style: AppTextStyles.h2.copyWith(color: AppColors.textPrimaryLight)),
            const SizedBox(height: 8),
            Text('\$0', style: AppTextStyles.heroTitle.copyWith(fontSize: 48, color: AppColors.textPrimaryLight)),
            Text('per month', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 16),
            Text(
              'For entry-level exploration and learning',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 24),
            _buildFeatureList([
              'Basic sensor data collection',
              'Community forum access',
              'Introductory curriculum',
              'Multi-platform access',
              'Basic privacy features',
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _launchUrl(AppConstants.portalUrl),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Get Started'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidPlan(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryBlue, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppColors.primaryBlue.withOpacity(0.02)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 6),
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
                Text('Paid', style: AppTextStyles.h2.copyWith(color: AppColors.primaryBlue)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Most Popular',
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('\$9.99', style: AppTextStyles.heroTitle.copyWith(fontSize: 48, color: AppColors.primaryBlue)),
            Text('per month', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 16),
            Text(
              'For power users and dedicated researchers',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 24),
            _buildFeatureList([
              'Everything in Free',
              'Full sensor data collection',
              'Deep learning training',
              'Private collaboration tools',
              'Full differential privacy',
              'Complete curriculum access',
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _launchUrl(AppConstants.portalUrl),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Select Plan'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrgPlan(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Organization', style: AppTextStyles.h2.copyWith(color: AppColors.textPrimaryLight)),
            const SizedBox(height: 8),
            Text('Custom', style: AppTextStyles.heroTitle.copyWith(fontSize: 48, color: AppColors.textPrimaryLight)),
            Text('pricing', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 16),
            Text(
              'For teams with institutional discounts',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 24),
            _buildFeatureList([
              'Everything in Paid',
              'Custom sensor configurations',
              'Enterprise-grade interfaces',
              'Scalable deep learning',
              'Compliance-ready privacy',
              'Dedicated support team',
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
              const Icon(Icons.check_circle, size: 20, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feature,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimaryLight),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureComparisonTable() {
    final features = [
      {'name': 'Sensor Data Collection', 'free': 'Basic', 'paid': 'Full', 'org': 'Full + Custom'},
      {'name': 'Multi-Platform Interface', 'free': '✓', 'paid': '✓ + Premium', 'org': '✓ Enterprise'},
      {'name': 'Obsidian Integration', 'free': '✓', 'paid': '✓ Advanced', 'org': '✓ Team Sync'},
      {'name': 'Deep Learning Training', 'free': '−', 'paid': '✓', 'org': '✓ Scalable'},
      {'name': 'Collaborative Learning', 'free': 'Community', 'paid': '✓ Private', 'org': '✓ Institutional'},
      {'name': 'Differential Privacy', 'free': 'Basic', 'paid': '✓ Full', 'org': '✓ Compliant'},
      {'name': 'Education Curriculum', 'free': '✓ Intro', 'paid': '✓ Full', 'org': '✓ Licensed'},
    ];

    return GlassCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.backgroundSecondaryLight),
          columns: const [
            DataColumn(label: Text('Feature', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Free', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Paid', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Organization', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
          rows: features.map((feature) {
            return DataRow(cells: [
              DataCell(Text(feature['name']!)),
              DataCell(Text(feature['free']!)),
              DataCell(Text(feature['paid']!, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(feature['org']!)),
            ],);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPlanDetailsExpansion() {
    return ExpansionPanelList.radio(
      elevation: 0,
      children: [
        ExpansionPanelRadio(
          value: 'free',
          headerBuilder: (context, isExpanded) => const ListTile(
            leading: Icon(Icons.card_giftcard),
            title: Text('Free Plan - Perfect for Getting Started'),
          ),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Dive in risk-free—collect data, take notes, join forums. Upgrade anytime. '
              'Includes basic sensor data collection, community forum access, and introductory curriculum.',
            ),
          ),
        ),
        ExpansionPanelRadio(
          value: 'paid',
          headerBuilder: (context, isExpanded) => const ListTile(
            leading: Icon(Icons.star),
            title: Text('Paid Plan - For Serious Researchers'),
          ),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Unlock pro tools for training and privacy. Ideal for solo deep dives. '
              'Everything in Free plus deep learning training, private collaboration, and full privacy features.',
            ),
          ),
        ),
        ExpansionPanelRadio(
          value: 'org',
          headerBuilder: (context, isExpanded) => const ListTile(
            leading: Icon(Icons.business),
            title: Text('Organization Plan - For Teams & Institutions'),
          ),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Bulk kits, dedicated onboarding, and curricula tailored to your syllabus. '
              'Everything in Paid plus custom configurations, enterprise interfaces, and dedicated support.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFAQSection() {
    return ExpansionPanelList.radio(
      elevation: 0,
      children: [
        ExpansionPanelRadio(
          value: 'switch',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Can I switch plans anytime?'),
          ),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Yes! You can upgrade or downgrade your plan at any time. Changes take effect immediately, '
              'and you\'ll be billed pro-rata for any upgrades.',
            ),
          ),
        ),
        ExpansionPanelRadio(
          value: 'data',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('What happens to my data if I downgrade?'),
          ),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Your data remains safe. However, some advanced features may become read-only until you upgrade again. '
              'We provide 30 days to export any data before permanent restrictions apply.',
            ),
          ),
        ),
        ExpansionPanelRadio(
          value: 'discount',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Do you offer educational discounts?'),
          ),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Yes! We offer significant discounts for educational institutions. '
              'Contact our sales team for custom pricing based on your needs and student count.',
            ),
          ),
        ),
        ExpansionPanelRadio(
          value: 'trial',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Is there a free trial for paid plans?'),
          ),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The Free plan serves as our trial. However, we offer a 14-day money-back guarantee on all paid plans, '
              'so you can try risk-free.',
            ),
          ),
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
