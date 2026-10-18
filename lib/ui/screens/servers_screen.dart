import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/vpn_server.dart';
import '../../services/vpn_gate_service.dart';
import '../../services/vpn_connection_service.dart';
import '../../services/vpnbook_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final gateState = ref.watch(vpnGateProvider);
    final gateNotifier = ref.read(vpnGateProvider.notifier);
    final vpnBookState = ref.watch(vpnBookProvider);
    final vpnBookNotifier = ref.read(vpnBookProvider.notifier);
    final connState = ref.watch(vpnConnectionProvider);
    final connNotifier = ref.read(vpnConnectionProvider.notifier);

    return DefaultTabController(
      length: 2,
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
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.4)),
                ),
                labelColor: QuantumVpnTheme.primaryCyan,
                unselectedLabelColor: Colors.white60,
                labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(
                    icon: const Icon(LucideIcons.globe, size: 16),
                    text: 'VPN Gate (${gateState.servers.length})',
                  ),
                  Tab(
                    icon: const Icon(LucideIcons.book_open, size: 16),
                    text: 'VPNBook (${vpnBookState.servers.length})',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: gateState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: QuantumVpnTheme.primaryCyan),
                    )
                  : const Icon(LucideIcons.refresh_cw, size: 18, color: QuantumVpnTheme.primaryCyan),
              tooltip: 'Обновить',
              onPressed: () {
                gateNotifier.refreshServers();
                vpnBookNotifier.fetchLatestCredentials();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // ── Tab 1: VPN Gate ──────────────────────────────────────────────
            _buildVpnGateTab(gateState, gateNotifier, connState, connNotifier),

            // ── Tab 2: VPNBook ───────────────────────────────────────────────
            _buildVpnBookTab(vpnBookState, vpnBookNotifier, connState, connNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildVpnGateTab(
    VpnGateState gateState,
    VpnGateNotifier gateNotifier,
    VpnConnectionState connState,
    VpnConnectionNotifier connNotifier,
  ) {
    final filteredServers = gateState.filteredServers;
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

        // Country Filter Chips
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
                                Text(server.flagEmoji, style: const TextStyle(fontSize: 28)),
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
                          ),
                        );
                      },
                    ),
        ),
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
                  Text(server.flagEmoji, style: const TextStyle(fontSize: 28)),
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
