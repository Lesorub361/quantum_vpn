import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _killSwitch = true;
  bool _autoReconnect = true;
  String _selectedDns = '1.1.1.1 (Cloudflare)';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _killSwitch = prefs.getBool('vpn_kill_switch') ?? true;
      _autoReconnect = prefs.getBool('vpn_auto_reconnect') ?? true;
      _selectedDns = prefs.getString('vpn_dns') ?? '1.1.1.1 (Cloudflare)';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки VPN'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('БЕЗОПАСНОСТЬ И ЗАЩИТА'),
          const SizedBox(height: 8),
          _card(
            children: [
              SwitchListTile(
                value: _killSwitch,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: QuantumVpnTheme.primaryCyan,
                title: Text(
                  'Аварийный выключатель (Kill Switch)',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: const Text(
                  'Блокирует интернет трафик при случайном разрыве VPN соединения для защиты реального IP.',
                  style: TextStyle(fontSize: 11, color: Colors.white60),
                ),
                onChanged: (val) {
                  setState(() => _killSwitch = val);
                  _saveSetting('vpn_kill_switch', val);
                },
              ),
              const Divider(color: Colors.white10),
              SwitchListTile(
                value: _autoReconnect,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: QuantumVpnTheme.primaryCyan,
                title: Text(
                  'Авто-переподключение',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: const Text(
                  'Автоматически восстанавливает соединение к лучшему серверу при сбоях сети.',
                  style: TextStyle(fontSize: 11, color: Colors.white60),
                ),
                onChanged: (val) {
                  setState(() => _autoReconnect = val);
                  _saveSetting('vpn_auto_reconnect', val);
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          _sectionTitle('DNS СЕРВЕР'),
          const SizedBox(height: 8),
          _card(
            children: [
              Text(
                'Защита от утечек DNS (DNS Leak Protection):',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              ...[
                '1.1.1.1 (Cloudflare)',
                '8.8.8.8 (Google Public DNS)',
                '9.9.9.9 (Quad9 Security)',
                '94.140.14.14 (AdGuard Блокировка рекламы)',
              ].map((dns) {
                final isSelected = _selectedDns == dns;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected ? LucideIcons.circle_check : LucideIcons.circle,
                    size: 16,
                    color: isSelected ? QuantumVpnTheme.primaryCyan : Colors.white30,
                  ),
                  title: Text(dns, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: Colors.white)),
                  onTap: () {
                    setState(() => _selectedDns = dns);
                    _saveSetting('vpn_dns', dns);
                  },
                );
              }),
            ],
          ),

          const SizedBox(height: 20),

          _sectionTitle('О ПРИЛОЖЕНИИ'),
          const SizedBox(height: 8),
          _card(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.shield, color: QuantumVpnTheme.primaryCyan, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('QuantumVPN 2026', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('Кроссплатформенный VPN клиент (Linux Desktop & Mobile)', style: TextStyle(fontSize: 11, color: Colors.white60)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Использует открытую академическую сеть серверов VPN Gate Университета Цукуба (Япония). Все серверы полностью бесплатны, не требуют регистрации и шифруют трафик по протоколу OpenVPN.',
                style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: Colors.white38,
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QuantumVpnTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QuantumVpnTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
