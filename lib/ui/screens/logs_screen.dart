import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/vpn_connection_service.dart';
import '../theme.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(vpnConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Логи соединения'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.copy, size: 18, color: QuantumVpnTheme.primaryCyan),
            tooltip: 'Скопировать логи',
            onPressed: () {
              if (connState.logs.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: connState.logs));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 Логи скопированы в буфер обмена!'),
                    backgroundColor: QuantumVpnTheme.successGreen,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (connState.activeConfigFile != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: QuantumVpnTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: QuantumVpnTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.file_text, size: 16, color: QuantumVpnTheme.primaryCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Файл .ovpn: ${connState.activeConfigFile}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D101A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: QuantumVpnTheme.cardBorder),
                ),
                child: connState.logs.isEmpty
                    ? Center(
                        child: Text(
                          'Логи появятся здесь после запуска подключения...',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white30),
                        ),
                      )
                    : SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          connState.logs,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: Colors.greenAccent.shade100,
                            height: 1.4,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
