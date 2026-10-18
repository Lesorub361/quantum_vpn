import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/vpn_connection_service.dart';
import 'ui/theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/servers_screen.dart';
import 'ui/screens/logs_screen.dart';
import 'ui/screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: QuantumVpnApp()));
}

class QuantumVpnApp extends StatelessWidget {
  const QuantumVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuantumVPN',
      debugShowCheckedModeBanner: false,
      theme: QuantumVpnTheme.darkTheme,
      home: const MainNavigationScaffold(),
    );
  }
}

class MainNavigationScaffold extends ConsumerStatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  ConsumerState<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends ConsumerState<MainNavigationScaffold> {
  int _currentIndex = 0;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        await ref.read(vpnConnectionProvider.notifier).emergencyNetworkReset();
        return AppExitResponse.exit;
      },
    );

    if (Platform.isLinux) {
      try {
        ProcessSignal.sigint.watch().listen((_) async {
          await ref.read(vpnConnectionProvider.notifier).emergencyNetworkReset();
          exit(0);
        });
        ProcessSignal.sigterm.watch().listen((_) async {
          await ref.read(vpnConnectionProvider.notifier).emergencyNetworkReset();
          exit(0);
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    final screens = [
      HomeScreen(onSelectServerTap: () => setState(() => _currentIndex = 1)),
      ServersScreen(onConnectedNav: () => setState(() => _currentIndex = 0)),
      const LogsScreen(),
      const SettingsScreen(),
    ];

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Desktop Sidebar
            NavigationRail(
              backgroundColor: QuantumVpnTheme.surface,
              selectedIndex: _currentIndex,
              onDestinationSelected: (val) => setState(() => _currentIndex = val),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    const Icon(LucideIcons.shield, color: QuantumVpnTheme.primaryCyan, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'QuantumVPN',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              selectedIconTheme: const IconThemeData(color: QuantumVpnTheme.primaryCyan),
              unselectedIconTheme: const IconThemeData(color: Colors.white54),
              selectedLabelTextStyle: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: QuantumVpnTheme.primaryCyan,
              ),
              unselectedLabelTextStyle: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(LucideIcons.shield),
                  selectedIcon: Icon(LucideIcons.shield_check),
                  label: Text('Главная'),
                ),
                NavigationRailDestination(
                  icon: Icon(LucideIcons.globe),
                  selectedIcon: Icon(LucideIcons.globe),
                  label: Text('Серверы'),
                ),
                NavigationRailDestination(
                  icon: Icon(LucideIcons.terminal),
                  selectedIcon: Icon(LucideIcons.terminal),
                  label: Text('Логи'),
                ),
                NavigationRailDestination(
                  icon: Icon(LucideIcons.settings),
                  selectedIcon: Icon(LucideIcons.settings_2),
                  label: Text('Настройки'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1, color: QuantumVpnTheme.cardBorder),
            Expanded(child: screens[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.shield, color: QuantumVpnTheme.primaryCyan, size: 20),
            const SizedBox(width: 8),
            Text(
              'QuantumVPN',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
          ],
        ),
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: QuantumVpnTheme.surface,
          border: Border(top: BorderSide(color: QuantumVpnTheme.cardBorder, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (val) => setState(() => _currentIndex = val),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: QuantumVpnTheme.primaryCyan,
          unselectedItemColor: Colors.white54,
          selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.shield),
              activeIcon: Icon(LucideIcons.shield_check),
              label: 'Главная',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.globe),
              activeIcon: Icon(LucideIcons.globe),
              label: 'Серверы',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.terminal),
              activeIcon: Icon(LucideIcons.terminal),
              label: 'Логи',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.settings),
              activeIcon: Icon(LucideIcons.settings_2),
              label: 'Настройки',
            ),
          ],
        ),
      ),
    );
  }
}
