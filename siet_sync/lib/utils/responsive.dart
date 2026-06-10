import 'package:flutter/material.dart';

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1280;
  static const double largeDesktop = 1600;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
  static bool isLargeDesktop(double width) => width >= largeDesktop;

  static int gridCrossAxisCount(double width) {
    if (width < mobile) return 2;
    if (width < tablet) return 3;
    if (width < desktop) return 3;
    if (width < largeDesktop) return 4;
    return 5;
  }

  static double contentMaxWidth(double width) {
    if (width < desktop) return double.infinity;
    if (width < largeDesktop) return 1200;
    return 1400;
  }

  static double pagePadding(double width) {
    if (width < mobile) return 12;
    if (width < desktop) return 20;
    return 32;
  }

  static double gridSpacing(double width) {
    if (width < mobile) return 12;
    if (width < desktop) return 16;
    return 20;
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints)
  builder;
  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: builder);
  }
}

class AdaptiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavDestination> destinations;
  final Widget? drawer;
  final Color? accentColor;
  final String title;
  final List<Widget>? appBarActions;
  final VoidCallback? onLogout;
  final Widget? floatingActionButton;

  const AdaptiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.drawer,
    this.accentColor,
    required this.title,
    this.appBarActions,
    this.onLogout,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Treat wider tablets and desktops as rail layouts for better responsiveness.
    final useRail = width >= 900;
    // Always show extended rail (full labels) when using rail.
    final shouldExtend = useRail;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor ?? Theme.of(context).primaryColor;

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
              extended: shouldExtend,
              accentColor: accent,
              isDark: isDark,
              onLogout: onLogout,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDark
            ? const Color(0xFF000000)
            : const Color(0xFFF2F2F7),
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        leading: Builder(
          builder: (context) => Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                Icons.menu,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        actions:
            appBarActions ??
            [
              if (onLogout != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.logout,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: onLogout,
                  ),
                ),
            ],
      ),
      drawer: drawer,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

class NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _DesktopRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavDestination> destinations;
  final bool extended;
  final Color accentColor;
  final bool isDark;
  final VoidCallback? onLogout;

  const _DesktopRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.extended,
    required this.accentColor,
    required this.isDark,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      extended: extended,
      labelType: NavigationRailLabelType.none,
      minExtendedWidth: 220,
      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      selectedIconTheme: IconThemeData(color: accentColor),
      unselectedIconTheme: IconThemeData(
        color: isDark ? Colors.white54 : Colors.grey.shade500,
      ),
      selectedLabelTextStyle: TextStyle(
        color: accentColor,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: isDark ? Colors.white54 : Colors.grey.shade600,
        fontSize: 13,
      ),
      indicatorColor: accentColor.withValues(alpha: 0.12),
      leading: extended
          ? Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: Text(
                'StaffSync',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: accentColor,
                ),
              ),
            )
          : null,
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
      trailing: onLogout != null
          ? Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    icon: Icon(Icons.logout, color: Colors.red.shade400),
                    onPressed: onLogout,
                    tooltip: 'Logout',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxW = maxWidth ?? Breakpoints.contentMaxWidth(width);
    final pad = padding ?? EdgeInsets.all(Breakpoints.pagePadding(width));

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(padding: pad, child: child),
      ),
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double? childAspectRatio;
  final double? maxCrossAxisExtent;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.childAspectRatio,
    this.maxCrossAxisExtent,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = Breakpoints.gridCrossAxisCount(width);
    final spacing = Breakpoints.gridSpacing(width);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio:
          childAspectRatio ?? (Breakpoints.isMobile(width) ? 1.15 : 1.1),
      children: children,
    );
  }
}
