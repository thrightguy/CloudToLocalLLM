import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../config/theme.dart';

/// Settings section definition
class SettingsSection {
  final String id;
  final String title;
  final IconData icon;
  final String? subtitle;

  const SettingsSection({
    required this.id,
    required this.title,
    required this.icon,
    this.subtitle,
  });
}

/// A sidebar component showing the list of settings sections
/// Follows the same design pattern as ConversationList for consistency
class SettingsSidebar extends StatelessWidget {
  final List<SettingsSection> sections;
  final String? selectedSectionId;
  final Function(String) onSectionSelected;
  final bool isCollapsed;

  const SettingsSidebar({
    super.key,
    required this.sections,
    this.selectedSectionId,
    required this.onSectionSelected,
    this.isCollapsed = false,
  });

  // Platform-specific settings sections
  static List<SettingsSection> get defaultSections {
    if (kIsWeb) {
      // Web platform - hide desktop-specific sections
      return [
        const SettingsSection(
          id: 'general',
          title: 'General',
          icon: Icons.settings,
          subtitle: 'Basic app settings',
        ),
        const SettingsSection(
          id: 'appearance',
          title: 'Appearance',
          icon: Icons.palette,
          subtitle: 'Display settings',
        ),
        const SettingsSection(
          id: 'llm-provider',
          title: 'LLM Provider',
          icon: Icons.memory,
          subtitle: 'Cloud proxy settings',
        ),
        const SettingsSection(
          id: 'cloud-sync',
          title: 'Cloud & Sync',
          icon: Icons.cloud,
          subtitle: 'Premium features',
        ),
        const SettingsSection(
          id: 'about',
          title: 'About',
          icon: Icons.info,
          subtitle: 'Version and info',
        ),
      ];
    } else {
      // Desktop platform - show all sections
      return [
        const SettingsSection(
          id: 'general',
          title: 'General',
          icon: Icons.settings,
          subtitle: 'Core app settings',
        ),
        const SettingsSection(
          id: 'appearance',
          title: 'Appearance',
          icon: Icons.palette,
          subtitle: 'Display settings',
        ),
        const SettingsSection(
          id: 'llm-provider',
          title: 'LLM Provider',
          icon: Icons.memory,
          subtitle: 'Local & cloud config',
        ),
        const SettingsSection(
          id: 'system-tray',
          title: 'System Tray',
          icon: Icons.desktop_windows,
          subtitle: 'Advanced tray settings',
        ),
        const SettingsSection(
          id: 'cloud-sync',
          title: 'Cloud & Sync',
          icon: Icons.cloud,
          subtitle: 'Secure tunnel & sync',
        ),
        const SettingsSection(
          id: 'about',
          title: 'About',
          icon: Icons.info,
          subtitle: 'Version and info',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return _buildCollapsedView();
    }

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        border: Border(
          right: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildSectionsList()),
        ],
      ),
    );
  }

  Widget _buildCollapsedView() {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        border: Border(
          right: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Settings icon header
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingS),
            child: Icon(Icons.settings, color: AppTheme.primaryColor, size: 28),
          ),
          const Divider(height: 1),

          // Collapsed section icons
          Expanded(
            child: ListView.builder(
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                final isSelected = section.id == selectedSectionId;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingXS,
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadiusS,
                      ),
                      border: isSelected
                          ? Border.all(color: AppTheme.primaryColor, width: 2)
                          : null,
                    ),
                    child: IconButton(
                      onPressed: () => onSectionSelected(section.id),
                      icon: Icon(section.icon),
                      iconSize: 20,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textColorLight,
                      tooltip: section.title,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.settings, color: AppTheme.primaryColor, size: 24),
          SizedBox(width: AppTheme.spacingS),
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsList() {
    if (sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 48, color: AppTheme.textColorLight),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'No settings available',
              style: TextStyle(color: AppTheme.textColorLight),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return _buildSectionItem(section);
      },
    );
  }

  Widget _buildSectionItem(SettingsSection section) {
    final isSelected = section.id == selectedSectionId;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        border: isSelected
            ? Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingXS,
        ),
        leading: Icon(
          section.icon,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textColorLight,
          size: 20,
        ),
        title: Text(
          section.title,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        subtitle: section.subtitle != null
            ? Text(
                section.subtitle!,
                style: TextStyle(color: AppTheme.textColorLight, fontSize: 12),
              )
            : null,
        onTap: () => onSectionSelected(section.id),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        ),
      ),
    );
  }
}
