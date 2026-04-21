import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';

class QuickActionsGridWidget extends StatelessWidget {
  const QuickActionsGridWidget({
    super.key,
    required this.onActionTap,
    this.title = 'Quick Actions',
  });

  final ValueChanged<String> onActionTap;
  final String title;

  static const _actions = [
    _QuickActionItem(
      id: 'book_appointment',
      title: 'Book\nAppointment',
      icon: Icons.calendar_month_rounded,
      iconColor: Color(0xFF6366F1),
      iconBackground: Color(0xFFE8EAFE),
    ),
    _QuickActionItem(
      id: 'lab_reports',
      title: 'Lab\nReports',
      icon: Icons.description_rounded,
      iconColor: Color(0xFF8B5CF6),
      iconBackground: Color(0xFFEDE9FE),
    ),
    _QuickActionItem(
      id: 'prescriptions',
      title: 'Prescriptions',
      icon: Icons.medication_rounded,
      iconColor: Color(0xFF10B981),
      iconBackground: Color(0xFFDDF7EC),
    ),
    _QuickActionItem(
      id: 'ai_assistant',
      title: 'AI\nAssistant',
      icon: Icons.chat_bubble_rounded,
      iconColor: Color(0xFF0EA5E9),
      iconBackground: Color(0xFFDFF3FF),
      hasAiBadge: true,
    ),
    _QuickActionItem(
      id: 'lab_test_order',
      title: 'Lab Test\nOrder',
      icon: Icons.science_rounded,
      iconColor: Color(0xFFEF4444),
      iconBackground: Color(0xFFFEE2E2),
    ),
    _QuickActionItem(
      id: 'id_card',
      title: 'ID Card',
      icon: Icons.badge_rounded,
      iconColor: Color(0xFF3B82F6),
      iconBackground: Color(0xFFE7F0FE),
    ),
    _QuickActionItem(
      id: 'my_club',
      title: 'MyClub',
      icon: Icons.star_rounded,
      iconColor: Color(0xFFF59E0B),
      iconBackground: Color(0xFFFEF0E4),
    ),
    _QuickActionItem(
      id: 'health_trends',
      title: 'Health\nTrends',
      icon: Icons.trending_up_rounded,
      iconColor: Color(0xFF10B981),
      iconBackground: Color(0xFFDEF7EF),
      hasAiBadge: true,
    ),
    _QuickActionItem(
      id: 'discharge',
      title: 'Discharge',
      icon: Icons.folder_rounded,
      iconColor: Color(0xFFF59E0B),
      iconBackground: Color(0xFFFFF5DB),
    ),
    _QuickActionItem(
      id: 'ai_trend_analysis',
      title: 'AI Trend\nAnalysis',
      icon: Icons.show_chart_rounded,
      iconColor: Color(0xFF0EA5E9),
      iconBackground: Color(0xFFDFF3FF),
      hasAiBadge: true,
    ),
    _QuickActionItem(
      id: 'ai_package_design',
      title: 'AI Package\nDesign',
      icon: Icons.auto_awesome_rounded,
      iconColor: Color(0xFF8B5CF6),
      iconBackground: Color(0xFFF1E8FF),
      hasAiBadge: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.sectionTitle(context)),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final action = _actions[index];
            return _QuickActionCard(
              item: action,
              onTap: () => onActionTap(action.id),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.item, required this.onTap});

  final _QuickActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.iconColor.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: item.iconColor.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 12,
                  child: item.hasAiBadge
                      ? Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  item.iconColor,
                                  item.iconColor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: item.iconColor.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'AI',
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 2),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.iconBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: item.iconColor.withOpacity(0.1),
                    ),
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subText(context).copyWith(
                    color: const Color(0xFF1F2937),
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    fontSize: 12,
                    letterSpacing: -0.2,
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

class _QuickActionItem {
  const _QuickActionItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    this.hasAiBadge = false,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final bool hasAiBadge;
}
