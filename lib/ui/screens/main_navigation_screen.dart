import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/alarm_provider.dart';
import 'home/home_dashboard_screen.dart';
import 'alarms/alarms_list_screen.dart';
import 'alarms/active_alarm_screen.dart';
import 'reminders/reminders_list_screen.dart';
import 'timers/timers_screen.dart';
import 'settings/settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final alarmProvider = Provider.of<AlarmProvider>(context);
    final ringingAlarm = alarmProvider.ringingAlarm;

    // Full-screen Active Alarm Trigger Overlay
    if (ringingAlarm != null) {
      return ActiveAlarmScreen(alarm: ringingAlarm);
    }

    final pages = [
      HomeDashboardScreen(onNavigateTab: _onTabSelected),
      const AlarmsListScreen(),
      const RemindersListScreen(),
      const TimersScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF23252E), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.alarm_outlined),
              activeIcon: Icon(Icons.alarm_rounded),
              label: 'Alarms',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt_outlined),
              activeIcon: Icon(Icons.task_alt_rounded),
              label: 'Reminders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timer_outlined),
              activeIcon: Icon(Icons.timer_rounded),
              label: 'Timers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_outlined),
              activeIcon: Icon(Icons.tune_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
