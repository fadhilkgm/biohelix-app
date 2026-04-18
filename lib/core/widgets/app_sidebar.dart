import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_theme.dart';
import '../../features/session/providers/session_provider.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final int tabIndex;

  const SidebarItem({
    required this.icon,
    required this.label,
    required this.tabIndex,
  });
}

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavigate;

  static const _items = [
    SidebarItem(icon: Icons.home_rounded, label: 'Home', tabIndex: 0),
    SidebarItem(icon: Icons.folder_rounded, label: 'Records', tabIndex: 1),
    SidebarItem(
      icon: Icons.calendar_month_rounded,
      label: 'Bookings',
      tabIndex: 2,
    ),
    SidebarItem(
      icon: Icons.workspace_premium_rounded,
      label: 'My Club',
      tabIndex: 3,
    ),
    SidebarItem(icon: Icons.person_rounded, label: 'Profile', tabIndex: 4),
  ];

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final session = context.watch<SessionProvider>();
    final patient = session.patient;
    final themeProvider = context.watch<ThemeProvider>();

    return Drawer(
      backgroundColor: bg,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          boxShadow: AppShadows.high(dark: isDark),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadius + 4,
                  ),
                  boxShadow: AppShadows.primary(
                    Theme.of(context).primaryColor,
                    dark: isDark,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient?.name ?? 'BHRC Patient',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            patient?.registrationNumber ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Nav Items ─────────────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    ..._items.map(
                      (item) => _SidebarNavTile(
                        item: item,
                        isSelected: selectedIndex == item.tabIndex,
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).pop();
                          onNavigate(item.tabIndex);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(
                      color: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                    ),
                    const SizedBox(height: 8),

                    // ── Dark mode toggle ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            themeProvider.isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            size: 20,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Dark mode',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const Spacer(),
                          Switch.adaptive(
                            value: themeProvider.isDark,
                            activeThumbColor: Colors.white,
                            activeTrackColor: Theme.of(context).primaryColor,
                            onChanged: (_) => themeProvider.toggle(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Footer ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    Divider(
                      color: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Sign out',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await context.read<SessionProvider>().signOut();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarNavTile extends StatelessWidget {
  final SidebarItem item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarNavTile({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final fgColor = isSelected
        ? primaryColor
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? primaryColor.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        leading: Icon(item.icon, color: fgColor, size: 22),
        title: Text(
          item.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected
                ? (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight)
                : fgColor,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }
}
