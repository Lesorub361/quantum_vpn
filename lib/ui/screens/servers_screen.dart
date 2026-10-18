import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/vpn_server.dart';
import '../../services/vpn_gate_service.dart';
import '../../services/vpn_connection_service.dart';
import '../theme.dart';

class ServersScreen extends ConsumerStatefulWidget {
  final VoidCallback onConnectedNav;

  const ServersScreen({super.key, required this.onConnectedNav});

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends ConsumerState<ServersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gateState = ref.watch(vpnGateProvider);
    final gateNotifier = ref.read(vpnGateProvider.notifier);
    final connState = ref.watch(vpnConnectionProvider);
    final connNotifier = ref.read(vpnConnectionProvider.notifier);

    final filteredServers = gateState.filteredServers;
    final countries = gateState.availableCountries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бесплатные VPN Серверы'),
        actions: [
          IconButton(
            icon: gateState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: QuantumVpnTheme.primaryCyan),
                  )
                : const Icon(LucideIcons.refresh_cw, size: 18, color: QuantumVpnTheme.primaryCyan),
            tooltip: 'Обновить список',
            onPressed: gateState.isLoading ? null : () => gateNotifier.refreshServers(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search & Filter Bar ────────────────────────────────────────────
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

          // ── Country Filter Chips ───────────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
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
                  final flag = VpnServer(
                    hostName: '',
                    ip: '',
                    score: 0,
                    ping: 0,
                    speedBps: 0,
                    countryLong: '',
                    countryShort: c['code']!,
                    numVpnSessions: 0,
                    uptime: 0,
                    totalUsers: 0,
                    totalTraffic: 0,
                    logType: '',
                    operator: '',
                    message: '',
                    ovpnConfigBase64: '',
                  ).flagEmoji;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('$flag ${c['name']}', style: const TextStyle(fontSize: 11)),
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

          // ── Servers List ───────────────────────────────────────────────────
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
                          final isCurrentlyActive =
                              connState.activeServer?.ip == server.ip;
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
                                  Text(
                                    server.flagEmoji,
                                    style: const TextStyle(fontSize: 28),
                                  ),
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
                                      foregroundColor: isConnected
                                          ? Colors.white
                                          : Colors.black,
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
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
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
      ),
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
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
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
