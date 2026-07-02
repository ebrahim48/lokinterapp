import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_palette.dart';
import '../../chat/presentation/chat_inbox_page.dart';
import '../../deals/presentation/deals_page.dart';
import '../../home_feed/presentation/home_feed_page.dart';
import '../../profile/presentation/profile_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    HomeFeedPage(),
    DealsPage(),
    ChatInboxPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: cs.surface,
          indicatorColor: AppPalette.primary.withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.all(TextStyle(fontSize: 11.sp)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          height: 64.h,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppPalette.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.handshake_outlined),
              selectedIcon: Icon(Icons.handshake, color: AppPalette.primary),
              label: 'Deals',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble, color: AppPalette.primary),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppPalette.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
