import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../services/vpn_gate_service.dart';
import '../../services/vpn_connection_service.dart';
import '../../services/vpnbook_service.dart';
import '../../services/riseup_vpn_service.dart';
import '../../services/quantum_stealth_service.dart';
import '../../services/speedtest_service.dart';
import '../widgets/country_flag_widget.dart';
import 'speedtest_screen.dart';
import '../theme.dart';

class ServersScreen extends ConsumerStatefulWidget {
  final VoidCallback onConnectedNav;

  const ServersScreen({super.key, required this.onConnectedNav});

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends ConsumerState<ServersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int?> _testedPings = {};
  final Set<String> _testingHosts = {};
  bool _onlyTurbo = false;

  Future<void> _testServerLatency(String host, int port) async {
    setState(() => _testingHosts.add(host));
    final latency = await SpeedtestNotifier.testServerLatency(host, port: port);
    if (mounted) {
      setState(() {
        _testedPings[host] = latency;
        _testingHosts.remove(host);
      });
      if (latency != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.activity, color: QuantumVpnTheme.primaryCyan, size: 16),
                const SizedBox(width: 8),
                Text('Отклик $host: $latency ms (${latency < 70 ? "⚡ Отличная скорость" : latency < 140 ? "🟢 Хорошая скорость" : "🟡 Средняя скорость"})'),
              ],
            ),
            backgroundColor: QuantumVpnTheme.surface,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Сервер $host не ответил на пинг. Возможно, закрыт порт.'),
            backgroundColor: QuantumVpnTheme.dangerRed,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label скопирован в буфер: $text'),
        duration: const Duration(seconds: 2),
        backgroundColor: QuantumVpnTheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _downloadVpnBookConfig(VpnBookServerItem server, String protocol) async {
    try {
      final notifier = ref.read(vpnBookProvider.notifier);
      final config = await notifier.fetchOvpnConfig(server, protocol: protocol);
      
      final tempDir = await getTemporaryDirectory();
      final file = File(p.join(tempDir.path, '${server.hostname}_$protocol.ovpn'));
      await file.writeAsString(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Конфигурация сохранена: ${file.path}'),
            backgroundColor: QuantumVpnTheme.surface,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Скопировать путь',
              textColor: QuantumVpnTheme.primaryCyan,
              onPressed: () => _copyToClipboard(file.path, 'Путь к файлу'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка скачивания: $e'),
            backgroundColor: QuantumVpnTheme.dangerRed,
          ),
        );
      }
    }
  }

  Future<void> _downloadRiseupConfig(RiseupServerItem server, String protocol) async {
    try {
      final notifier = ref.read(riseupVpnProvider.notifier);
      final config = await notifier.fetchOvpnConfig(server, protocol: protocol);
      
      final tempDir = await getTemporaryDirectory();
      final file = File(p.join(tempDir.path, '${server.hostname}_$protocol.ovpn'));
      await file.writeAsString(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Конфигурация сохранена: ${file.path}'),
            backgroundColor: QuantumVpnTheme.surface,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Скопировать путь',
              textColor: QuantumVpnTheme.primaryCyan,
              onPressed: () => _copyToClipboard(file.path, 'Путь к файлу'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка скачивания: $e'),
            backgroundColor: QuantumVpnTheme.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateState = ref.watch(vpnGateProvider);
    final gateNotifier = ref.read(vpnGateProvider.notifier);
    final riseupState = ref.watch(riseupVpnProvider);
    final riseupNotifier = ref.read(riseupVpnProvider.notifier);
    final vpnBookState = ref.watch(vpnBookProvider);
    final vpnBookNotifier = ref.read(vpnBookProvider.notifier);
    final stealthState = ref.watch(quantumStealthProvider);
    final stealthNotifier = ref.read(quantumStealthProvider.notifier);
    final connState = ref.watch(vpnConnectionProvider);
    final connNotifier = ref.read(vpnConnectionProvider.notifier);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Бесплатные VPN Серверы'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: QuantumVpnTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: QuantumVpnTheme.cardBorder),
              ),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.4)),
                ),
                labelColor: QuantumVpnTheme.primaryCyan,
                unselectedLabelColor: Colors.white60,
                labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(
                    icon: const Icon(LucideIcons.zap, size: 15, color: QuantumVpnTheme.accentNeon),
                    text: '⚡ Quantum Stealth (${stealthState.servers.length})',
                  ),
                  Tab(
                    icon: const Icon(LucideIcons.globe, size: 15),
                    text: 'VPN Gate (${gateState.servers.length})',
                  ),
                  Tab(
                    icon: const Icon(LucideIcons.shield, size: 15, color: QuantumVpnTheme.primaryCyan),
                    text: 'Riseup (${riseupState.servers.length})',
                  ),
                  Tab(
                    icon: const Icon(LucideIcons.book_open, size: 15),
                    text: 'VPNBook (${vpnBookState.servers.length})',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.gauge, size: 18, color: QuantumVpnTheme.primaryCyan),
              tooltip: 'Тест скорости',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SpeedtestScreen()),
                );
              },
            ),
            IconButton(
              icon: (gateState.isLoading || riseupState.isLoading || stealthState.isLoading)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: QuantumVpnTheme.primaryCyan),
                    )
                  : const Icon(LucideIcons.refresh_cw, size: 18, color: QuantumVpnTheme.primaryCyan),
              tooltip: 'Обновить',
              onPressed: () {
                stealthNotifier.fetchLiveServers();
                gateNotifier.refreshServers();
                riseupNotifier.fetchLiveGateways();
                vpnBookNotifier.fetchLatestCredentials();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // ── Tab 0: Quantum Stealth (Xray Core) ───────────────────────────
            _buildStealthTab(stealthState, stealthNotifier, connState, connNotifier),

            // ── Tab 1: VPN Gate ──────────────────────────────────────────────
            _buildVpnGateTab(gateState, gateNotifier, connState, connNotifier),

            // ── Tab 2: Riseup VPN ────────────────────────────────────────────
            _buildRiseupTab(riseupState, riseupNotifier, connState, connNotifier),

            // ── Tab 3: VPNBook ───────────────────────────────────────────────
            _buildVpnBookTab(vpnBookState, vpnBookNotifier, connState, connNotifier),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupProtoItem(String proto, String title, String current) {
    final isSelected = proto == current;
    return PopupMenuItem<String>(
      value: proto,
      child: Row(
        children: [
          if (isSelected)
            const Icon(LucideIcons.check, size: 14, color: QuantumVpnTheme.accentNeon)
          else
            const SizedBox(width: 14),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: isSelected ? QuantumVpnTheme.accentNeon : Colors.white)),
        ],
      ),
    );
  }

  Widget _buildStealthTab(
    QuantumStealthState stealthState,
    QuantumStealthNotifier stealthNotifier,
    VpnConnectionState connState,
    VpnConnectionNotifier connNotifier,
  ) {
    final filtered = stealthState.filteredServers;
    final countries = stealthState.availableCountries;

    return Column(
      children: [
        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  onChanged: (text) => stealthNotifier.setSearchQuery(text),
                  decoration: InputDecoration(
                    hintText: 'Поиск (страна, IP, VLESS, Shadowsocks)...',
                    hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                    prefixIcon: const Icon(LucideIcons.search, size: 16, color: Colors.white54),
                    filled: true,
                    fillColor: QuantumVpnTheme.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: QuantumVpnTheme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: QuantumVpnTheme.cardBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: QuantumVpnTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: QuantumVpnTheme.cardBorder),
                  ),
                  child: const Icon(LucideIcons.funnel, size: 16, color: QuantumVpnTheme.accentNeon),
                ),
                tooltip: 'Фильтр протокола',
                onSelected: (proto) => stealthNotifier.setProtocolFilter(proto),
                itemBuilder: (context) => [
                  _popupProtoItem('all', '🌐 Все протоколы', stealthState.selectedProtocol),
                  _popupProtoItem('vless', '🛡️ VLESS Reality (DPI-Immune)', stealthState.selectedProtocol),
                  _popupProtoItem('shadowsocks', '⚡ Shadowsocks 2022', stealthState.selectedProtocol),
                  _popupProtoItem('trojan', '🔒 Trojan TLS', stealthState.selectedProtocol),
                ],
              ),
            ],
          ),
        ),

        // Protocol & Country Filter Chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  avatar: const Icon(LucideIcons.shield_check, size: 13, color: QuantumVpnTheme.primaryCyan),
                  label: const Text('🛡️ VLESS Reality', style: TextStyle(fontSize: 11)),
                  selected: stealthState.selectedProtocol == 'vless',
                  selectedColor: QuantumVpnTheme.primaryCyan,
                  labelStyle: TextStyle(
                    color: stealthState.selectedProtocol == 'vless' ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: QuantumVpnTheme.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(
                    color: stealthState.selectedProtocol == 'vless' ? QuantumVpnTheme.primaryCyan : QuantumVpnTheme.cardBorder,
                  ),
                  onSelected: (val) => stealthNotifier.setProtocolFilter(val ? 'vless' : 'all'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  avatar: const Icon(LucideIcons.zap, size: 13, color: QuantumVpnTheme.accentNeon),
                  label: const Text('⚡ Shadowsocks', style: TextStyle(fontSize: 11)),
                  selected: stealthState.selectedProtocol == 'shadowsocks',
                  selectedColor: QuantumVpnTheme.accentNeon,
                  labelStyle: TextStyle(
                    color: stealthState.selectedProtocol == 'shadowsocks' ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: QuantumVpnTheme.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(
                    color: stealthState.selectedProtocol == 'shadowsocks' ? QuantumVpnTheme.accentNeon : QuantumVpnTheme.cardBorder,
                  ),
                  onSelected: (val) => stealthNotifier.setProtocolFilter(val ? 'shadowsocks' : 'all'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('Все страны', style: TextStyle(fontSize: 11)),
                  selected: stealthState.selectedCountry == 'all',
                  selectedColor: QuantumVpnTheme.primaryCyan,
                  labelStyle: TextStyle(
                    color: stealthState.selectedCountry == 'all' ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: QuantumVpnTheme.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(
                    color: stealthState.selectedCountry == 'all'
                        ? QuantumVpnTheme.primaryCyan
                        : QuantumVpnTheme.cardBorder,
                  ),
                  onSelected: (_) => stealthNotifier.setCountryFilter('all'),
                ),
              ),
              ...countries.where((c) => c != 'all').map((c) {
                final isSel = stealthState.selectedCountry == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: CountryFlagWidget(countryCode: c, width: 18, height: 12),
                    label: Text(c, style: const TextStyle(fontSize: 11)),
                    selected: isSel,
                    selectedColor: QuantumVpnTheme.primaryCyan,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: QuantumVpnTheme.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(
                      color: isSel ? QuantumVpnTheme.primaryCyan : QuantumVpnTheme.cardBorder,
                    ),
                    onSelected: (_) => stealthNotifier.setCountryFilter(isSel ? 'all' : c),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Server List
        Expanded(
          child: stealthState.isLoading && stealthState.servers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: QuantumVpnTheme.primaryCyan),
                      SizedBox(height: 16),
                      Text('Загрузка серверов нового поколения (Xray Core)...', style: TextStyle(color: Colors.white60)),
                    ],
                  ),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.shield_alert, size: 48, color: Colors.white24),
                          const SizedBox(height: 12),
                          Text(
                            stealthState.errorMessage ?? 'Серверы не найдены',
                            style: const TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => stealthNotifier.fetchLiveServers(),
                            icon: const Icon(LucideIcons.refresh_cw, size: 14),
                            label: const Text('Обновить серверы'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QuantumVpnTheme.primaryCyan,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final server = filtered[index];
                        final isCurrentlyActive = connState.activeServer?.ip == server.ip &&
                            connState.activeServer?.protocolType == server.protocolType;
                        final isConnected = connState.isConnected && isCurrentlyActive;
                        final isConnecting = connState.isConnecting && isCurrentlyActive;

                        return Container(
                          decoration: BoxDecoration(
                            color: QuantumVpnTheme.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isConnected
                                  ? QuantumVpnTheme.successGreen
                                  : isConnecting
                                      ? QuantumVpnTheme.primaryCyan
                                      : QuantumVpnTheme.cardBorder,
                              width: (isConnected || isConnecting) ? 1.5 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CountryFlagWidget(countryCode: server.countryShort, width: 34, height: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${server.countryLong} (${server.countryShort})',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: server.protocolType == 'vless'
                                                  ? QuantumVpnTheme.primaryCyan.withValues(alpha: 0.15)
                                                  : QuantumVpnTheme.accentNeon.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: server.protocolType == 'vless'
                                                    ? QuantumVpnTheme.primaryCyan.withValues(alpha: 0.5)
                                                    : QuantumVpnTheme.accentNeon.withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Text(
                                              server.protocolBadge,
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: server.protocolType == 'vless'
                                                    ? QuantumVpnTheme.primaryCyan
                                                    : QuantumVpnTheme.accentNeon,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '${server.ip}:${server.port ?? 443}',
                                            style: GoogleFonts.firaCode(fontSize: 11, color: Colors.white54),
                                          ),
                                          if (server.sni != null && server.sni!.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              '• SNI: ${server.sni}',
                                              style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _testServerLatency(server.ip, server.port ?? 443),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.white12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (_testingHosts.contains(server.ip))
                                                    const SizedBox(
                                                      width: 10,
                                                      height: 10,
                                                      child: CircularProgressIndicator(strokeWidth: 1.5, color: QuantumVpnTheme.primaryCyan),
                                                    )
                                                  else
                                                    const Icon(LucideIcons.activity, size: 10, color: QuantumVpnTheme.primaryCyan),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _testedPings[server.ip] != null
                                                        ? '${_testedPings[server.ip]} ms'
                                                        : '${server.ping} ms (тест)',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: (_testedPings[server.ip] != null && _testedPings[server.ip]! < 100)
                                                          ? QuantumVpnTheme.successGreen
                                                          : QuantumVpnTheme.primaryCyan,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(LucideIcons.shield_check, size: 11, color: QuantumVpnTheme.accentNeon),
                                          const SizedBox(width: 2),
                                          Text(
                                            'DPI Bypass 100%',
                                            style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: isConnecting
                                      ? null
                                      : () async {
                                          if (isConnected) {
                                            await connNotifier.disconnect();
                                          } else {
                                            await connNotifier.connect(server);
                                            widget.onConnectedNav();
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isConnected
                                        ? QuantumVpnTheme.dangerRed
                                        : QuantumVpnTheme.primaryCyan,
                                    foregroundColor: isConnected ? Colors.white : Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: isConnecting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                        )
                                      : Text(
                                          isConnected ? 'Отключить' : 'Старт',
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildVpnGateTab(
    VpnGateState gateState,
    VpnGateNotifier gateNotifier,
    VpnConnectionState connState,
    VpnConnectionNotifier connNotifier,
  ) {
    var filteredServers = gateState.filteredServers;
    if (_onlyTurbo) {
      filteredServers = filteredServers.where((s) => (s.speedBps / 1000000) >= 50.0).toList();
    }
    final countries = gateState.availableCountries;

    return Column(
      children: [
        // Search & Sort Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  onChanged: (text) => gateNotifier.setSearchQuery(text),
                  decoration: InputDecoration(
                    hintText: 'Поиск страны, IP или хоста...',
                    hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                    prefixIcon: const Icon(LucideIcons.search, size: 16, color: Colors.white54),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 14, color: Colors.white54),
                            onPressed: () {
                              _searchController.clear();
                              gateNotifier.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: QuantumVpnTheme.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: QuantumVpnTheme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: QuantumVpnTheme.cardBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<VpnSortOrder>(
                icon: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: QuantumVpnTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: QuantumVpnTheme.cardBorder),
                  ),
                  child: const Icon(LucideIcons.arrow_up_down, size: 16, color: QuantumVpnTheme.primaryCyan),
                ),
                tooltip: 'Сортировка',
                onSelected: (order) => gateNotifier.setSortOrder(order),
                itemBuilder: (context) => [
                  _popupItem(VpnSortOrder.fastestSpeed, '⚡ По максимальной скорости', gateState.sortOrder),
                  _popupItem(VpnSortOrder.lowestPing, '🚀 По минимальному пингу', gateState.sortOrder),
                  _popupItem(VpnSortOrder.highestScore, '⭐ По рейтингу надежности', gateState.sortOrder),
                  _popupItem(VpnSortOrder.country, '🌍 По стране (А-Я)', gateState.sortOrder),
                ],
              ),
            ],
          ),
        ),

        // Country & Speed Filter Chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  avatar: const Icon(LucideIcons.zap, size: 13, color: QuantumVpnTheme.accentNeon),
                  label: const Text('🚀 Турбо (>50 Мб/с)', style: TextStyle(fontSize: 11)),
                  selected: _onlyTurbo,
                  selectedColor: QuantumVpnTheme.accentNeon,
                  labelStyle: TextStyle(
                    color: _onlyTurbo ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: QuantumVpnTheme.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(
                    color: _onlyTurbo ? QuantumVpnTheme.accentNeon : QuantumVpnTheme.cardBorder,
                  ),
                  onSelected: (val) => setState(() => _onlyTurbo = val),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('Все страны', style: TextStyle(fontSize: 11)),
                  selected: gateState.selectedCountryFilter == null,
                  selectedColor: QuantumVpnTheme.primaryCyan,
                  labelStyle: TextStyle(
                    color: gateState.selectedCountryFilter == null ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: QuantumVpnTheme.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(
                    color: gateState.selectedCountryFilter == null
                        ? QuantumVpnTheme.primaryCyan
                        : QuantumVpnTheme.cardBorder,
                  ),
                  onSelected: (_) => gateNotifier.setCountryFilter(null),
                ),
              ),
              ...countries.map((c) {
                final isSel = gateState.selectedCountryFilter == c['code'];
                final countryCode = c['code']!;

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: CountryFlagWidget(countryCode: countryCode, width: 18, height: 12),
                    label: Text(c['name']!, style: const TextStyle(fontSize: 11)),
                    selected: isSel,
                    selectedColor: QuantumVpnTheme.primaryCyan,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: QuantumVpnTheme.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(
                      color: isSel ? QuantumVpnTheme.primaryCyan : QuantumVpnTheme.cardBorder,
                    ),
                    onSelected: (_) => gateNotifier.setCountryFilter(isSel ? null : c['code']),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Server List
        Expanded(
          child: gateState.isLoading && gateState.servers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: QuantumVpnTheme.primaryCyan),
                      SizedBox(height: 16),
                      Text('Загрузка бесплатных VPN серверов мира...', style: TextStyle(color: Colors.white60)),
                    ],
                  ),
                )
              : filteredServers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.search_x, size: 48, color: Colors.white24),
                          const SizedBox(height: 12),
                          Text(
                            gateState.error ?? 'Серверы не найдены',
                            style: const TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => gateNotifier.refreshServers(),
                            icon: const Icon(LucideIcons.refresh_cw, size: 14),
                            label: const Text('Повторить запрос'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QuantumVpnTheme.primaryCyan,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredServers.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final server = filteredServers[index];
                        final isCurrentlyActive = connState.activeServer?.ip == server.ip;
                        final isConnected = connState.isConnected && isCurrentlyActive;
                        final isConnecting = connState.isConnecting && isCurrentlyActive;

                        return Container(
                          decoration: BoxDecoration(
                            color: QuantumVpnTheme.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isConnected
                                  ? QuantumVpnTheme.successGreen
                                  : isConnecting
                                      ? QuantumVpnTheme.primaryCyan
                                      : QuantumVpnTheme.cardBorder,
                              width: (isConnected || isConnecting) ? 1.5 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CountryFlagWidget(countryCode: server.countryShort, width: 34, height: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        server.countryLong,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'IP: ${server.ip} · ${server.numVpnSessions} польз.',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          color: Colors.white54,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          _badge(
                                            LucideIcons.zap,
                                            server.speedFormatted,
                                            QuantumVpnTheme.primaryCyan,
                                          ),
                                          _badge(
                                            LucideIcons.activity,
                                            server.pingFormatted,
                                            server.ping < 60
                                                ? QuantumVpnTheme.successGreen
                                                : server.ping < 120
                                                    ? QuantumVpnTheme.warningOrange
                                                    : QuantumVpnTheme.dangerRed,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OutlinedButton(
                                          onPressed: _testingHosts.contains(server.ip)
                                              ? null
                                              : () => _testServerLatency(server.ip, 443),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                              color: _testedPings.containsKey(server.ip)
                                                  ? QuantumVpnTheme.accentNeon
                                                  : QuantumVpnTheme.cardBorder,
                                            ),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: _testingHosts.contains(server.ip)
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: QuantumVpnTheme.primaryCyan),
                                                )
                                              : Text(
                                                  _testedPings.containsKey(server.ip) && _testedPings[server.ip] != null
                                                      ? '${_testedPings[server.ip]}ms'
                                                      : 'Тест',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: _testedPings.containsKey(server.ip)
                                                        ? QuantumVpnTheme.accentNeon
                                                        : Colors.white70,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 6),
                                        ElevatedButton(
                                          onPressed: () async {
                                            gateNotifier.selectServer(server);
                                            if (isConnected) {
                                              await connNotifier.disconnect();
                                            } else {
                                              await connNotifier.connect(server);
                                              widget.onConnectedNav();
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isConnected
                                                ? QuantumVpnTheme.dangerRed
                                                : QuantumVpnTheme.primaryCyan,
                                            foregroundColor: isConnected ? Colors.white : Colors.black,
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            isConnected
                                                ? 'Отключить'
                                                : isConnecting
                                                    ? 'Связь...'
                                                    : 'Подключить',
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildRiseupTab(
    RiseupVpnState riseupState,
    RiseupVpnNotifier riseupNotifier,
    VpnConnectionState connState,
    VpnConnectionNotifier connNotifier,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Riseup Networks Info Card ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: QuantumVpnTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: QuantumVpnTheme.accentNeon.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: QuantumVpnTheme.accentNeon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.shield_check, color: QuantumVpnTheme.accentNeon, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Riseup Networks · LEAP VPN',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: QuantumVpnTheme.accentNeon.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('150+ Мбит/с', style: TextStyle(fontSize: 9, color: QuantumVpnTheme.accentNeon, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Европа и США · Без логинов и паролей · Анонимный SSL',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: riseupState.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: QuantumVpnTheme.accentNeon),
                          )
                        : const Icon(LucideIcons.refresh_cw, size: 16, color: QuantumVpnTheme.accentNeon),
                    tooltip: 'Обновить сертификат и серверы',
                    onPressed: riseupState.isLoading ? null : () => riseupNotifier.fetchClientCertificate(forceRefresh: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: QuantumVpnTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: QuantumVpnTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      riseupState.hasCertificate ? LucideIcons.circle_check : LucideIcons.key_round,
                      size: 14,
                      color: riseupState.hasCertificate ? QuantumVpnTheme.successGreen : Colors.amberAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        riseupState.statusMessage ??
                            (riseupState.hasCertificate
                                ? 'Анонимный SSL-сертификат активен (Вход без пароля)'
                                : 'Сертификат создастся автоматически при подключении'),
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'ПРОТОКОЛ И ПОРТ',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _protocolChip('udp1194', '⚡ UDP 1194 (Макс. Скорость)', riseupState.selectedProtocol, (p) => riseupNotifier.setProtocol(p)),
                    const SizedBox(width: 6),
                    _protocolChip('udp53', '🛡 UDP 53 (DNS / Обход)', riseupState.selectedProtocol, (p) => riseupNotifier.setProtocol(p)),
                    const SizedBox(width: 6),
                    _protocolChip('tcp443', '🔒 TCP 443 (HTTPS)', riseupState.selectedProtocol, (p) => riseupNotifier.setProtocol(p)),
                    const SizedBox(width: 6),
                    _protocolChip('tcp80', '🌐 TCP 80 (HTTP)', riseupState.selectedProtocol, (p) => riseupNotifier.setProtocol(p)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Servers List ──────────────────────────────────────────────────────
        Text(
          'ДОСТУПНЫЕ СЕРВЕРЫ (${riseupState.servers.length})',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white54),
        ),
        const SizedBox(height: 8),

        ...riseupState.servers.map((server) {
          final isConnected = connState.isConnected && connState.activeServer?.hostName == server.hostname;
          final isConnecting = connState.isConnecting && connState.activeServer?.hostName == server.hostname;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: QuantumVpnTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isConnected
                    ? QuantumVpnTheme.successGreen
                    : isConnecting
                        ? QuantumVpnTheme.accentNeon
                        : QuantumVpnTheme.cardBorder,
                width: isConnected || isConnecting ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CountryFlagWidget(countryCode: server.countryShort, width: 34, height: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.countryLong,
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          server.hostname,
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white54),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _badge(LucideIcons.zap, '${server.speedMbps.toStringAsFixed(0)} Mbps', QuantumVpnTheme.accentNeon),
                            _badge(LucideIcons.activity, '${server.ping} ms', QuantumVpnTheme.successGreen),
                            _badge(LucideIcons.shield, 'Zero-Logs', Colors.white70),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Download button
                  IconButton(
                    icon: const Icon(LucideIcons.download, size: 16, color: Colors.white60),
                    tooltip: 'Скачать .ovpn файл',
                    onPressed: () => _downloadRiseupConfig(server, riseupState.selectedProtocol),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: _testingHosts.contains(server.hostname)
                        ? null
                        : () => _testServerLatency(server.hostname, 443),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _testedPings.containsKey(server.hostname)
                            ? QuantumVpnTheme.accentNeon
                            : QuantumVpnTheme.cardBorder,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _testingHosts.contains(server.hostname)
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: QuantumVpnTheme.accentNeon),
                          )
                        : Text(
                            _testedPings.containsKey(server.hostname) && _testedPings[server.hostname] != null
                                ? '${_testedPings[server.hostname]}ms'
                                : 'Тест',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _testedPings.containsKey(server.hostname)
                                  ? QuantumVpnTheme.accentNeon
                                  : Colors.white70,
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () async {
                      if (isConnected) {
                        await connNotifier.disconnect();
                      } else {
                        try {
                          final vpnServer = await riseupNotifier.getVpnServer(server);
                          await connNotifier.connect(vpnServer);
                          widget.onConnectedNav();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Ошибка подключения к Riseup: $e'),
                                backgroundColor: QuantumVpnTheme.dangerRed,
                              ),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? QuantumVpnTheme.dangerRed : QuantumVpnTheme.accentNeon,
                      foregroundColor: isConnected ? Colors.white : Colors.black,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isConnected
                          ? 'Отключить'
                          : isConnecting
                              ? 'Связь...'
                              : 'Подключить',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVpnBookTab(
    VpnBookState bookState,
    VpnBookNotifier bookNotifier,
    VpnConnectionState connState,
    VpnConnectionNotifier connNotifier,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── VPNBook Credentials Header Card ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: QuantumVpnTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.key, color: QuantumVpnTheme.primaryCyan, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Учетные данные VPNBook',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Единый логин и пароль для всех серверов VPNBook',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: bookState.isFetchingCredentials
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: QuantumVpnTheme.primaryCyan),
                          )
                        : const Icon(LucideIcons.refresh_cw, size: 16, color: QuantumVpnTheme.primaryCyan),
                    tooltip: 'Обновить пароль с vpnbook.com',
                    onPressed: bookState.isFetchingCredentials ? null : () => bookNotifier.fetchLatestCredentials(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: QuantumVpnTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: QuantumVpnTheme.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ЛОГИН', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
                              Text(bookState.username, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.copy, size: 14, color: Colors.white54),
                            onPressed: () => _copyToClipboard(bookState.username, 'Логин VPNBook'),
                            tooltip: 'Скопировать',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: QuantumVpnTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: QuantumVpnTheme.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ПАРОЛЬ', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
                              Text(bookState.password, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: QuantumVpnTheme.primaryCyan)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.copy, size: 14, color: Colors.white54),
                            onPressed: () => _copyToClipboard(bookState.password, 'Пароль VPNBook'),
                            tooltip: 'Скопировать',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Protocol Selection ───────────────────────────────────────────────
        Text(
          'ВЫБОР ПРОТОКОЛА И ПОРТА:',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.white38),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _protocolChip('tcp443', 'TCP 443 (HTTPS - Обход блоков)', bookState.selectedProtocol, (p) => bookNotifier.setProtocol(p)),
            _protocolChip('tcp80', 'TCP 80 (HTTP)', bookState.selectedProtocol, (p) => bookNotifier.setProtocol(p)),
            _protocolChip('udp53', 'UDP 53 (DNS)', bookState.selectedProtocol, (p) => bookNotifier.setProtocol(p)),
            _protocolChip('udp25000', 'UDP 25000 (Скоростной)', bookState.selectedProtocol, (p) => bookNotifier.setProtocol(p)),
          ],
        ),

        const SizedBox(height: 16),

        // ── VPNBook Server List ──────────────────────────────────────────────
        Text(
          'СЕРВЕРЫ VPNBOOK:',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.white38),
        ),
        const SizedBox(height: 8),

        ...bookState.servers.map((server) {
          final isCurrentlyActive = connState.activeServer?.ip == server.hostname;
          final isConnected = connState.isConnected && isCurrentlyActive;
          final isConnecting = connState.isConnecting && isCurrentlyActive;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: QuantumVpnTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isConnected
                    ? QuantumVpnTheme.successGreen
                    : isConnecting
                        ? QuantumVpnTheme.primaryCyan
                        : QuantumVpnTheme.cardBorder,
                width: (isConnected || isConnecting) ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CountryFlagWidget(countryCode: server.countryShort, width: 34, height: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${server.countryLong} · ${server.name}',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          server.hostname,
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white54),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _badge(LucideIcons.zap, '${server.speedMbps.toStringAsFixed(0)} Mbps', QuantumVpnTheme.primaryCyan),
                            _badge(LucideIcons.activity, '${server.ping} ms', QuantumVpnTheme.successGreen),
                            _badge(LucideIcons.shield_check, 'Безлимитный', Colors.white70),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Download button
                  IconButton(
                    icon: const Icon(LucideIcons.download, size: 16, color: Colors.white60),
                    tooltip: 'Скачать .ovpn файл',
                    onPressed: () => _downloadVpnBookConfig(server, bookState.selectedProtocol),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: _testingHosts.contains(server.hostname)
                        ? null
                        : () => _testServerLatency(server.hostname, 443),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _testedPings.containsKey(server.hostname)
                            ? QuantumVpnTheme.accentNeon
                            : QuantumVpnTheme.cardBorder,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _testingHosts.contains(server.hostname)
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: QuantumVpnTheme.primaryCyan),
                          )
                        : Text(
                            _testedPings.containsKey(server.hostname) && _testedPings[server.hostname] != null
                                ? '${_testedPings[server.hostname]}ms'
                                : 'Тест',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _testedPings.containsKey(server.hostname)
                                  ? QuantumVpnTheme.accentNeon
                                  : Colors.white70,
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () async {
                      if (isConnected) {
                        await connNotifier.disconnect();
                      } else {
                        final vpnServer = await bookNotifier.getVpnServer(server);
                        await connNotifier.connect(vpnServer);
                        widget.onConnectedNav();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? QuantumVpnTheme.dangerRed : QuantumVpnTheme.primaryCyan,
                      foregroundColor: isConnected ? Colors.white : Colors.black,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isConnected
                          ? 'Отключить'
                          : isConnecting
                              ? 'Связь...'
                              : 'Подключить',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _protocolChip(String code, String label, String current, ValueChanged<String> onSelected) {
    final isSel = code == current;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSel,
      selectedColor: QuantumVpnTheme.primaryCyan,
      labelStyle: TextStyle(color: isSel ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
      backgroundColor: QuantumVpnTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: isSel ? QuantumVpnTheme.primaryCyan : QuantumVpnTheme.cardBorder),
      onSelected: (_) => onSelected(code),
    );
  }

  Widget _badge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<VpnSortOrder> _popupItem(
      VpnSortOrder order, String title, VpnSortOrder current) {
    final isSelected = order == current;
    return PopupMenuItem<VpnSortOrder>(
      value: order,
      child: Row(
        children: [
          if (isSelected)
            const Icon(LucideIcons.check, size: 14, color: QuantumVpnTheme.primaryCyan)
          else
            const SizedBox(width: 14),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: isSelected ? QuantumVpnTheme.primaryCyan : Colors.white)),
        ],
      ),
    );
  }
}
