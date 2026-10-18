import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/vpn_gate_service.dart';
import '../../services/vpn_connection_service.dart';
import '../theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onSelectServerTap;

  const HomeScreen({super.key, required this.onSelectServerTap});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gateState = ref.watch(vpnGateProvider);
    final connState = ref.watch(vpnConnectionProvider);
    final activeServer = connState.activeServer ?? gateState.selectedServer;

    final isConnected = connState.isConnected;
    final isConnecting = connState.isConnecting;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // ── Status Banner ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isConnected
                  ? QuantumVpnTheme.successGreen.withValues(alpha: 0.12)
                  : isConnecting
                      ? QuantumVpnTheme.primaryCyan.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isConnected
                    ? QuantumVpnTheme.successGreen.withValues(alpha: 0.3)
                    : isConnecting
                        ? QuantumVpnTheme.primaryCyan.withValues(alpha: 0.3)
                        : Colors.white12,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected
                        ? QuantumVpnTheme.successGreen
                        : isConnecting
                            ? QuantumVpnTheme.primaryCyan
                            : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected
                      ? 'ПОДКЛЮЧЕНО · IP СКРЫТ'
                      : isConnecting
                          ? 'УСТАНОВКА СОЕДИНЕНИЯ...'
                          : 'НЕ ПОДКЛЮЧЕНО',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isConnected
                        ? QuantumVpnTheme.successGreen
                        : isConnecting
                            ? QuantumVpnTheme.primaryCyan
                            : Colors.white60,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Big Glowing Power Button ───────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = (isConnected || isConnecting) ? _pulseAnimation.value : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onTap: () async {
                      if (isConnected || isConnecting) {
                        await ref.read(vpnConnectionProvider.notifier).disconnect();
                      } else {
                        if (activeServer != null) {
                          await ref.read(vpnConnectionProvider.notifier).connect(activeServer);
                        } else {
                          widget.onSelectServerTap();
                        }
                      }
                    },
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: isConnected
                              ? [
                                  QuantumVpnTheme.successGreen.withValues(alpha: 0.3),
                                  QuantumVpnTheme.successGreen.withValues(alpha: 0.05),
                                ]
                              : isConnecting
                                  ? [
                                      QuantumVpnTheme.primaryCyan.withValues(alpha: 0.3),
                                      QuantumVpnTheme.primaryCyan.withValues(alpha: 0.05),
                                    ]
                                  : [
                                      Colors.white.withValues(alpha: 0.06),
                                      Colors.transparent,
                                    ],
                        ),
                        boxShadow: [
                          if (isConnected)
                            BoxShadow(
                              color: QuantumVpnTheme.successGreen.withValues(alpha: 0.35),
                              blurRadius: 36,
                              spreadRadius: 4,
                            )
                          else if (isConnecting)
                            BoxShadow(
                              color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.35),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF161A29),
                            border: Border.all(
                              color: isConnected
                                  ? QuantumVpnTheme.successGreen
                                  : isConnecting
                                      ? QuantumVpnTheme.primaryCyan
                                      : Colors.white24,
                              width: 2.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.power,
                                size: 44,
                                color: isConnected
                                    ? QuantumVpnTheme.successGreen
                                    : isConnecting
                                        ? QuantumVpnTheme.primaryCyan
                                        : Colors.white70,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isConnected
                                    ? 'ОТКЛЮЧИТЬ'
                                    : isConnecting
                                        ? 'ПОДКЛЮЧЕНИЕ'
                                        : 'СТАРТ',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: isConnected
                                      ? QuantumVpnTheme.successGreen
                                      : isConnecting
                                          ? QuantumVpnTheme.primaryCyan
                                          : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          // ── Live Traffic / Speed Display ───────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: QuantumVpnTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: QuantumVpnTheme.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _speedStat(
                  icon: LucideIcons.arrow_down,
                  title: 'СКАЧИВАНИЕ',
                  value: '${connState.currentDownloadSpeedMbps.toStringAsFixed(1)} Мбит/с',
                  color: QuantumVpnTheme.primaryCyan,
                ),
                Container(width: 1, height: 36, color: Colors.white10),
                _speedStat(
                  icon: LucideIcons.arrow_up,
                  title: 'ОТДАЧА',
                  value: '${connState.currentUploadSpeedMbps.toStringAsFixed(1)} Мбит/с',
                  color: QuantumVpnTheme.accentPurple,
                ),
                Container(width: 1, height: 36, color: Colors.white10),
                _speedStat(
                  icon: LucideIcons.timer,
                  title: 'ВРЕМЯ',
                  value: connState.durationFormatted,
                  color: Colors.white,
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Selected Server Card ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: QuantumVpnTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: QuantumVpnTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ВЫБРАННЫЙ СЕРВЕР',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.white54,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onSelectServerTap,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        'Сменить >',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: QuantumVpnTheme.primaryCyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (activeServer != null) ...[
                  Row(
                    children: [
                      Text(
                        activeServer.flagEmoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeServer.countryLong,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'IP: ${activeServer.ip} · ${activeServer.numVpnSessions} польз.',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.zap, size: 10, color: QuantumVpnTheme.primaryCyan),
                                const SizedBox(width: 4),
                                Text(
                                  activeServer.speedFormatted,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: QuantumVpnTheme.primaryCyan,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Пинг: ${activeServer.pingFormatted}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              color: activeServer.ping < 60
                                  ? QuantumVpnTheme.successGreen
                                  : activeServer.ping < 120
                                      ? QuantumVpnTheme.warningOrange
                                      : QuantumVpnTheme.dangerRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextButton.icon(
                        onPressed: widget.onSelectServerTap,
                        icon: const Icon(LucideIcons.globe, size: 16),
                        label: const Text('Выбрать бесплатный VPN сервер'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedStat({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
