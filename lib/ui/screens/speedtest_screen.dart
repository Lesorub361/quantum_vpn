import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/speedtest_service.dart';
import '../../services/vpn_connection_service.dart';
import '../theme.dart';
import '../widgets/country_flag_widget.dart';

class SpeedtestScreen extends ConsumerWidget {
  const SpeedtestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speedState = ref.watch(speedtestProvider);
    final speedNotifier = ref.read(speedtestProvider.notifier);
    final vpnState = ref.watch(vpnConnectionProvider);
    final isVpnConnected = vpnState.status == VpnConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест скорости и IP'),
        actions: [
          IconButton(
            icon: speedState.isFetchingIp
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: QuantumVpnTheme.primaryCyan),
                  )
                : const Icon(LucideIcons.refresh_cw, size: 18),
            tooltip: 'Обновить данные IP',
            onPressed: speedState.isTesting ? null : () => speedNotifier.refreshIpInfo(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── IP & Location Status Card ──────────────────────────────────────
          _buildIpCard(speedState, isVpnConnected),

          const SizedBox(height: 24),

          // ── Speedometer / Live Gauge ───────────────────────────────────────
          _buildSpeedGauge(speedState),

          const SizedBox(height: 24),

          // ── Metrics Triad (Ping, Download, Upload) ─────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'ПИНГ',
                  value: speedState.pingMs != null ? '${speedState.pingMs} ms' : '--',
                  icon: LucideIcons.activity,
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: 'СКАЧИВАНИЕ',
                  value: speedState.finalDownloadMbps != null
                      ? '${speedState.finalDownloadMbps} Мб/с'
                      : speedState.isTesting
                          ? '${speedState.currentSpeedMbps} Мб/с'
                          : '--',
                  icon: LucideIcons.arrow_down,
                  color: QuantumVpnTheme.primaryCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: 'ОТДАЧА',
                  value: speedState.finalUploadMbps != null ? '${speedState.finalUploadMbps} Мб/с' : '--',
                  icon: LucideIcons.arrow_up,
                  color: QuantumVpnTheme.successGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Big Action Button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: speedState.isTesting ? null : () => speedNotifier.runSpeedTest(),
              icon: speedState.isTesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(LucideIcons.gauge, size: 20),
              label: Text(
                speedState.isTesting ? 'ТЕСТИРОВАНИЕ...' : 'НАЧАТЬ ТЕСТ СКОРОСТИ',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuantumVpnTheme.primaryCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
            ),
          ),

          if (speedState.isTesting) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: speedState.progress,
              backgroundColor: Colors.white10,
              color: QuantumVpnTheme.primaryCyan,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                speedState.currentStep,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIpCard(SpeedtestState state, bool isVpnConnected) {
    final ipInfo = state.currentIp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QuantumVpnTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVpnConnected ? QuantumVpnTheme.successGreen.withValues(alpha: 0.4) : QuantumVpnTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isVpnConnected
                          ? QuantumVpnTheme.successGreen.withValues(alpha: 0.15)
                          : Colors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isVpnConnected ? QuantumVpnTheme.successGreen : Colors.amberAccent,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isVpnConnected ? LucideIcons.shield_check : LucideIcons.shield_alert,
                          size: 13,
                          color: isVpnConnected ? QuantumVpnTheme.successGreen : Colors.amberAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isVpnConnected ? 'VPN ЗАЩИЩЕН' : 'ПРЯМОЕ СОЕДИНЕНИЕ (РЕАЛЬНЫЙ IP)',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isVpnConnected ? QuantumVpnTheme.successGreen : Colors.amberAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (ipInfo != null)
                CountryFlagWidget(countryCode: ipInfo.countryCode, width: 28, height: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ipInfo != null ? ipInfo.ip : 'Определение IP адреса...',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(LucideIcons.map_pin, size: 13, color: Colors.white38),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  ipInfo != null
                      ? '${ipInfo.city.isNotEmpty ? "${ipInfo.city}, " : ""}${ipInfo.country}'
                      : 'Загрузка геоданных...',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
          if (ipInfo != null && ipInfo.isp.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(LucideIcons.network, size: 13, color: Colors.white38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Провайдер: ${ipInfo.isp}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpeedGauge(SpeedtestState state) {
    final speed = state.isTesting ? state.currentSpeedMbps : (state.finalDownloadMbps ?? 0.0);

    return Center(
      child: Container(
        width: 190,
        height: 190,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: QuantumVpnTheme.surface,
          border: Border.all(color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.25), width: 2),
          boxShadow: [
            BoxShadow(
              color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.08),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.gauge, color: QuantumVpnTheme.primaryCyan, size: 24),
            const SizedBox(height: 6),
            Text(
              speed > 0 ? speed.toStringAsFixed(1) : '0.0',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'МБИТ / СЕК',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: QuantumVpnTheme.primaryCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: QuantumVpnTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QuantumVpnTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
