import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/alarm_provider.dart';
import 'home/home_dashboard_screen.dart';
import 'time/time_hub_screen.dart';
import 'organize/organize_hub_screen.dart';
import 'journal/journal_hub_screen.dart';
import 'explore/explore_hub_screen.dart';
import 'alarms/active_alarm_screen.dart';
import '../widgets/quick_capture_sheet.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int _timeHubSubTab = 0;
  int _organizeHubSubTab = 0;
  int _journalHubSubTab = 0;

  void _onTabSelected(int index, [int? subTabIndex]) {
    setState(() {
      _currentIndex = index;
      if (index == 1 && subTabIndex != null) {
        _timeHubSubTab = subTabIndex;
      } else if (index == 2 && subTabIndex != null) {
        _organizeHubSubTab = subTabIndex;
      } else if (index == 3 && subTabIndex != null) {
        _journalHubSubTab = subTabIndex;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final alarmProvider = Provider.of<AlarmProvider>(context);
    final ringingAlarm = alarmProvider.ringingAlarm;

    // Full-screen Active Alarm Trigger Overlay (Preserved)
    if (ringingAlarm != null) {
      return ActiveAlarmScreen(alarm: ringingAlarm);
    }

    final pages = [
      HomeDashboardScreen(
        onNavigateTab: (tab, [subTab]) => _onTabSelected(tab, subTab),
      ),
      TimeHubScreen(
        key: ValueKey('time_$_timeHubSubTab'),
        initialTabIndex: _timeHubSubTab,
      ),
      OrganizeHubScreen(
        key: ValueKey('organize_$_organizeHubSubTab'),
        initialTabIndex: _organizeHubSubTab,
      ),
      JournalHubScreen(
        key: ValueKey('journal_$_journalHubSubTab'),
        initialTabIndex: _journalHubSubTab,
      ),
      const ExploreHubScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => QuickCaptureSheet.show(context),
        backgroundColor: AppColors.primary,
        tooltip: 'Quick Capture',
        elevation: 4,
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141519),
          border: Border(
            top: BorderSide(color: Color(0xFF23252E), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => _onTabSelected(index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF141519),
          selectedItemColor: AppColors.primaryLight,
          unselectedItemColor: const Color(0xFF8E929E),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.today_outlined),
              activeIcon: Icon(Icons.today_rounded),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_outlined),
              activeIcon: Icon(Icons.access_time_filled_rounded),
              label: 'Time',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder_rounded),
              label: 'Organize',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_stories_outlined),
              activeIcon: Icon(Icons.auto_stories_rounded),
              label: 'Journal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: 'Explore',
            ),
          ],
        ),
      ),
    );
  }
}
