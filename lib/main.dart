import 'package:flutter/material.dart';
import 'add_sheet.dart';
import 'goals.dart';
import 'history.dart';
import 'insights.dart';
import 'settings.dart';
import 'sms.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const ChumaApp());
}

class ChumaApp extends StatelessWidget {
  const ChumaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Chuma',
        debugShowCheckedModeBanner: false,
        theme: chumaTheme(),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (_, __) => switch (tab) {
            0 => const TodayScreen(),
            1 => const HistoryScreen(),
            2 => const InsightsScreen(),
            3 => const GoalsScreen(),
            _ => const SettingsScreen(),
          },
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'sms',
            tooltip: 'Paste mobile money SMS',
            backgroundColor: Colors.white,
            foregroundColor: C.navy,
            onPressed: () => openSmsPaste(context),
            child: const Icon(Icons.sms_outlined),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => openAdd(context),
            backgroundColor: C.navy,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Today'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'Insights'),
          NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'Goals'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}
