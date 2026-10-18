import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/vpn_connection_service.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _killSwitch = true;
  bool _autoReconnect = true;
  String _selectedDns = '143.20.64.55 (Bezmezhau SmartDNS / DoT: dns.bezmezhau.com)';
  bool _isResettingNetwork = false;

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
      _selectedDns = prefs.getString('vpn_dns') ?? '143.20.64.55 (Bezmezhau SmartDNS / DoT: dns.bezmezhau.com)';
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

  Future<void> _triggerEmergencyReset() async {
    setState(() => _isResettingNetwork = true);
    try {
      await ref.read(vpnConnectionProvider.notifier).emergencyNetworkReset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.circle_check, color: QuantumVpnTheme.successGreen, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Сетевые маршруты и системный DNS успешно сброшены! Интернет восстановлен.'),
                ),
              ],
            ),
            backgroundColor: QuantumVpnTheme.surface,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResettingNetwork = false);
      }
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
          // ── Emergency Network Reset (Linux / Stale Routes Fix) ─────────────
          if (Platform.isLinux) ...[
            _sectionTitle('СЕТЬ И АВАРИЙНЫЙ СБРОС (LINUX)'),
            const SizedBox(height: 8),
            _card(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: QuantumVpnTheme.warningOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.rotate_ccw, color: QuantumVpnTheme.warningOrange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Восстановление интернета в 1 клик',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Используйте эту кнопку, если после закрытия программы перестал работать интернет или сайты не открываются. Кнопка принудительно завершает зависший OpenVPN, сбрасывает маршруты интерфейса tun0 и восстанавливает рабочий DNS.',
                            style: TextStyle(fontSize: 11, color: Colors.white60, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isResettingNetwork ? null : _triggerEmergencyReset,
                    icon: _isResettingNetwork
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(LucideIcons.rotate_ccw, size: 16),
                    label: Text(
                      _isResettingNetwork ? 'Сброс сетевых параметров...' : 'Восстановить интернет и сбросить сеть',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantumVpnTheme.warningOrange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

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
                '143.20.64.55 (Bezmezhau SmartDNS / DoT: dns.bezmezhau.com)',
                '111.88.96.50 (SmartDNS Antigravity / xbox-dns)',
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
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.sparkles, color: QuantumVpnTheme.primaryCyan, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Bezmezhau SmartDNS (Рекомендуется)',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: QuantumVpnTheme.primaryCyan),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Специальный DNS-резолвер для обхода блокировок Google AI, Gemini, Antigravity IDE и стримингов без падения скорости.\n'
                      '• Основной IPv4: 143.20.64.55\n'
                      '• Дополнительный IPv4: 31.58.216.201\n'
                      '• Android Private DNS (DoT): dns.bezmezhau.com\n'
                      '• DoH: https://dns.bezmezhau.com/dns-query',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
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
                'Поддерживает две открытые бесплатные сети серверов:\n'
                '1. VPN Gate Университета Цукуба (Япония) — более 40 стран мира.\n'
                '2. VPNBook Free OpenVPN — быстрые серверы в США, Канаде, Германии, Франции, Великобритании и Польше.\n\n'
                'Все серверы полностью бесплатны, безопасны и шифруют трафик по протоколу OpenVPN.',
                style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
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
