import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class AntigravityToolItem {
  final String id;
  final String title;
  final String description;
  final String downloadUrl;
  final String defaultExe;
  String? detectedPath;
  bool isInstalled;
  bool isRunning;

  AntigravityToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.downloadUrl,
    required this.defaultExe,
    this.detectedPath,
    this.isInstalled = false,
    this.isRunning = false,
  });
}

class AntigravityScreen extends StatefulWidget {
  const AntigravityScreen({super.key});

  @override
  State<AntigravityScreen> createState() => _AntigravityScreenState();
}

class _AntigravityScreenState extends State<AntigravityScreen> {
  bool _isScanning = false;
  bool _isOperating = false;
  String _operationLogs = '';

  late final List<AntigravityToolItem> _tools;

  @override
  void initState() {
    super.initState();
    _tools = [
      AntigravityToolItem(
        id: 'ide',
        title: 'Antigravity IDE',
        description: 'Среда разработки на базе VS Code со встроенными парными AI-агентами и умным Tab-дополнением.',
        downloadUrl: 'https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz',
        defaultExe: 'antigravity-ide',
      ),
      AntigravityToolItem(
        id: 'hub',
        title: 'Antigravity 2.0 (Desktop Hub)',
        description: 'Отдельное настольное приложение Electron для управления проектами, параллельными агентами и cron-задачами.',
        downloadUrl: 'https://storage.googleapis.com/antigravity-public/antigravity-hub/2.24.0-5780333019398144/linux-x64/Antigravity.tar.gz',
        defaultExe: 'antigravity',
      ),
      AntigravityToolItem(
        id: 'cli',
        title: 'Antigravity CLI (agy)',
        description: 'Автономный консольный терминальный агент командной строки Google Antigravity.',
        downloadUrl: 'https://antigravity.google/cli/install.sh',
        defaultExe: 'agy',
      ),
    ];

    _scanTools();
  }

  void _appendLog(String text) {
    setState(() {
      _operationLogs += text;
      final lines = _operationLogs.split('\n');
      if (lines.length > 100) {
        _operationLogs = lines.sublist(lines.length - 100).join('\n');
      }
    });
  }

  Future<void> _scanTools() async {
    setState(() => _isScanning = true);
    final home = Platform.environment['HOME'] ?? '/root';

    try {
      // 1. Antigravity IDE candidates
      final ideCandidates = [
        '/opt/Antigravity IDE/antigravity',
        '/opt/Antigravity IDE/Antigravity',
        '/opt/antigravity-ide/antigravity',
        '/usr/share/antigravity-ide/antigravity',
        '$home/Applications/Antigravity/antigravity',
        '$home/Applications/Antigravity-x64/antigravity',
        '$home/.local/share/antigravity/antigravity',
        '$home/antigravity/antigravity',
      ];
      String? foundIde;
      for (final p in ideCandidates) {
        if (await File(p).exists()) {
          foundIde = p;
          break;
        }
      }
      if (foundIde == null) {
        final whichRes = await Process.run('which', ['antigravity-ide']);
        if (whichRes.exitCode == 0 && whichRes.stdout.toString().trim().isNotEmpty) {
          foundIde = whichRes.stdout.toString().trim();
        }
      }
      _tools[0].detectedPath = foundIde;
      _tools[0].isInstalled = foundIde != null;

      // 2. Antigravity 2.0 Hub candidates
      final hubCandidates = [
        '/opt/antigravity/antigravity',
        '/opt/Antigravity/antigravity',
        '/opt/Antigravity/Antigravity',
        '$home/Applications/antigravity/antigravity',
        '$home/.local/share/antigravity-app/antigravity',
        '$home/Applications/Antigravity.AppImage',
      ];
      String? foundHub;
      for (final p in hubCandidates) {
        if (await File(p).exists()) {
          foundHub = p;
          break;
        }
      }
      if (foundHub == null) {
        final whichRes = await Process.run('which', ['antigravity']);
        if (whichRes.exitCode == 0 && whichRes.stdout.toString().trim().isNotEmpty) {
          final resPath = whichRes.stdout.toString().trim();
          if (!resPath.endsWith('agy')) {
            foundHub = resPath;
          }
        }
      }
      _tools[1].detectedPath = foundHub;
      _tools[1].isInstalled = foundHub != null;

      // 3. Antigravity CLI candidates
      final cliCandidates = [
        '/usr/local/bin/agy',
        '$home/.local/bin/agy',
        '$home/.gemini/bin/agy',
        '/usr/bin/agy',
        '$home/bin/agy',
        '/usr/local/bin/antigravity',
      ];
      String? foundCli;
      for (final p in cliCandidates) {
        if (await File(p).exists()) {
          foundCli = p;
          break;
        }
      }
      if (foundCli == null) {
        final whichRes = await Process.run('which', ['agy']);
        if (whichRes.exitCode == 0 && whichRes.stdout.toString().trim().isNotEmpty) {
          foundCli = whichRes.stdout.toString().trim();
        }
      }
      _tools[2].detectedPath = foundCli;
      _tools[2].isInstalled = foundCli != null;
    } catch (_) {}

    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  Future<String?> _ensureCleanerInstalled() async {
    final home = Platform.environment['HOME'] ?? '/root';
    final candidatePaths = [
      '/usr/local/bin/ag-cleaner',
      '$home/.local/bin/ag-cleaner',
      '/usr/bin/ag-cleaner',
      '/tmp/ag-cleaner',
    ];

    for (final p in candidatePaths) {
      final f = File(p);
      if (await f.exists()) {
        return p;
      }
    }

    // Check which ag-cleaner in PATH
    try {
      final whichRes = await Process.run('which', ['ag-cleaner']);
      if (whichRes.exitCode == 0 && whichRes.stdout.toString().trim().isNotEmpty) {
        final found = whichRes.stdout.toString().trim();
        if (await File(found).exists()) return found;
      }
    } catch (_) {}

    // Not found -> Auto-download official release
    _appendLog('⚙️ Движок ag-cleaner не обнаружен на устройстве.\n');
    _appendLog('📥 Автоматическая загрузка официального релиза ag-cleaner с GitHub...\n');

    try {
      String archTag = 'linux-amd64';
      try {
        final unameRes = await Process.run('uname', ['-m']);
        final arch = unameRes.stdout.toString().trim();
        if (arch == 'aarch64' || arch == 'arm64') {
          archTag = 'linux-arm64';
        }
      } catch (_) {}

      final downloadUrl = 'https://github.com/tawroot/antigravity-cleaner/releases/latest/download/antigravity-cleaner-$archTag';

      String targetPath = '$home/.local/bin/ag-cleaner';
      try {
        final binDir = Directory('$home/.local/bin');
        if (!await binDir.exists()) {
          await binDir.create(recursive: true);
        }
      } catch (_) {
        targetPath = '/tmp/ag-cleaner';
      }

      _appendLog('🌐 Скачивание $downloadUrl -> $targetPath ...\n');

      bool downloaded = false;
      try {
        final curlRes = await Process.run('curl', [
          '-sSL',
          downloadUrl,
          '-o',
          targetPath,
        ]);
        if (curlRes.exitCode == 0) {
          final f = File(targetPath);
          if (await f.exists() && await f.length() > 50000) {
            downloaded = true;
          }
        }
      } catch (_) {}

      if (!downloaded) {
        try {
          final wgetRes = await Process.run('wget', [
            '-q',
            '-O',
            targetPath,
            downloadUrl,
          ]);
          if (wgetRes.exitCode == 0) {
            final f = File(targetPath);
            if (await f.exists() && await f.length() > 50000) {
              downloaded = true;
            }
          }
        } catch (_) {}
      }

      if (!downloaded) {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 25);
          final request = await client.getUrl(Uri.parse(downloadUrl));
          request.followRedirects = true;
          request.maxRedirects = 5;
          final response = await request.close();
          if (response.statusCode >= 200 && response.statusCode < 400) {
            final sink = File(targetPath).openWrite();
            await response.pipe(sink);
            await sink.close();
            downloaded = true;
          }
        } catch (_) {}
      }

      if (downloaded) {
        await Process.run('chmod', ['+x', targetPath]);
        _appendLog('✅ ag-cleaner успешно установлен и готов к работе!\n\n');
        return targetPath;
      }
    } catch (e) {
      _appendLog('⚠️ Ошибка при автоматической загрузке: $e\n');
    }

    return null;
  }

  Future<void> _runCleanerCommand(String command, List<String> args) async {
    setState(() {
      _isOperating = true;
      _operationLogs = '⚡ Запуск команды: ag-cleaner $command ${args.join(" ")}\n';
    });

    try {
      final cleanerExe = await _ensureCleanerInstalled();
      if (cleanerExe == null) {
        _appendLog('❌ Не удалось автоматически загрузить ag-cleaner.\n');
        _appendLog('💡 Установите его вручную одной командой в терминале:\n');
        _appendLog('   mkdir -p ~/.local/bin && curl -sSL https://github.com/tawroot/antigravity-cleaner/releases/latest/download/antigravity-cleaner-linux-amd64 -o ~/.local/bin/ag-cleaner && chmod +x ~/.local/bin/ag-cleaner\n');
        return;
      }

      if (command == 'patch') {
        _appendLog('🧹 Завершение активных процессов Antigravity для освобождения файлов...\n');
        try {
          await Process.run(cleanerExe, ['kill']);
          await Process.run('pkill', ['-f', 'language_server']);
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final proc = await Process.start(cleanerExe, [command, ...args]);
      
      // Auto-confirm in case cleaner prompts interactively
      try {
        proc.stdin.writeln('y');
        await proc.stdin.flush();
      } catch (_) {}

      proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        _appendLog('$line\n');
      });
      proc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        _appendLog('[ERR] $line\n');
      });

      final code = await proc.exitCode;
      _appendLog('🏁 Процесс завершился с кодом $code.\n');
      await _scanTools();
    } catch (e) {
      _appendLog('❌ Ошибка: $e\n');
    } finally {
      if (mounted) {
        setState(() => _isOperating = false);
      }
    }
  }

  Future<void> _launchTool(AntigravityToolItem tool) async {
    if (tool.detectedPath == null) return;

    _appendLog('🚀 Запуск ${tool.title} (${tool.detectedPath})...\n');
    try {
      // 1. First ensure patch is applied
      await _runCleanerCommand('patch', ['all']);

      // 2. Launch with environment
      final env = Map<String, String>.from(Platform.environment);
      env['ANTIGRAVITY_DISABLE_TELEMETRY'] = 'true';
      env['NO_PROXY'] = '127.0.0.1,localhost';

      await Process.start(
        tool.detectedPath!,
        [],
        environment: env,
        mode: ProcessStartMode.detached,
      );

      _appendLog('✅ ${tool.title} успешно запущен в фоновом режиме без региональных ограничений!\n');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tool.title} запущен! Ограничения региона нейтрализованы.'),
            backgroundColor: QuantumVpnTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      _appendLog('❌ Ошибка запуска: $e\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antigravity AI Freedom'),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: QuantumVpnTheme.primaryCyan),
                  )
                : const Icon(LucideIcons.refresh_cw, size: 18, color: QuantumVpnTheme.primaryCyan),
            tooltip: 'Повторить сканирование системы',
            onPressed: _isScanning ? null : _scanTools,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header Banner ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  QuantumVpnTheme.primaryCyan.withValues(alpha: 0.15),
                  QuantumVpnTheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.sparkles, color: QuantumVpnTheme.primaryCyan, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Antigravity Bypass & Tools',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Автопоиск путей, снятие региональных ограничений Google (РФ/РБ) и запуск пропатченных инструментов.',
                        style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Quick Action Buttons Bar ───────────────────────────────────────
          _sectionTitle('УПРАВЛЕНИЕ ПАТЧАМИ И ДИАГНОСТИКА'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isOperating ? null : () => _runCleanerCommand('patch', ['all']),
                  icon: const Icon(LucideIcons.shield_check, size: 15),
                  label: const Text('Патч всех инструментов', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QuantumVpnTheme.primaryCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isOperating ? null : () => _runCleanerCommand('doctor', []),
                  icon: const Icon(LucideIcons.stethoscope, size: 15, color: QuantumVpnTheme.primaryCyan),
                  label: const Text('Диагностика', style: TextStyle(fontSize: 11, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: QuantumVpnTheme.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isOperating ? null : () => _runCleanerCommand('kill', []),
                icon: const Icon(LucideIcons.power, size: 15, color: Colors.redAccent),
                label: const Text('Закрыть процессы', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── 3 Tools List ───────────────────────────────────────────────────
          _sectionTitle('3 ИНСТРУМЕНТА ANTIGRAVITY (OFFICIAL LINUX)'),
          const SizedBox(height: 8),

          ..._tools.map((tool) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: QuantumVpnTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tool.isInstalled
                      ? QuantumVpnTheme.successGreen.withValues(alpha: 0.5)
                      : QuantumVpnTheme.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (tool.isInstalled ? QuantumVpnTheme.successGreen : Colors.white24)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          tool.id == 'ide'
                              ? LucideIcons.code
                              : tool.id == 'hub'
                                  ? LucideIcons.layout_dashboard
                                  : LucideIcons.terminal,
                          color: tool.isInstalled ? QuantumVpnTheme.successGreen : Colors.white60,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tool.title,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tool.description,
                              style: const TextStyle(fontSize: 11, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (tool.isInstalled ? QuantumVpnTheme.successGreen : QuantumVpnTheme.warningOrange)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: tool.isInstalled ? QuantumVpnTheme.successGreen : QuantumVpnTheme.warningOrange,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          tool.isInstalled ? 'Установлено' : 'Не найдено',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: tool.isInstalled ? QuantumVpnTheme.successGreen : QuantumVpnTheme.warningOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (tool.detectedPath != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: QuantumVpnTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: QuantumVpnTheme.cardBorder),
                      ),
                      child: Text(
                        'Путь: ${tool.detectedPath}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: QuantumVpnTheme.primaryCyan),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      if (tool.isInstalled)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isOperating ? null : () => _launchTool(tool),
                            icon: const Icon(LucideIcons.play, size: 14),
                            label: Text('Запустить пропатченный ${tool.title}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QuantumVpnTheme.primaryCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        )
                      else ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _appendLog('🌐 Ссылка для скачивания: ${tool.downloadUrl}\n');
                            },
                            icon: const Icon(LucideIcons.download, size: 14, color: QuantumVpnTheme.primaryCyan),
                            label: const Text('Скачать с antigravity.google', style: TextStyle(fontSize: 11, color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: QuantumVpnTheme.cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),

          // ── Operation Terminal Log Card ────────────────────────────────────
          if (_operationLogs.isNotEmpty) ...[
            const SizedBox(height: 10),
            _sectionTitle('КОНСОЛЬ ОПЕРАЦИЙ И ПАТЧЕРА'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: QuantumVpnTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.terminal, size: 14, color: QuantumVpnTheme.primaryCyan),
                          const SizedBox(width: 6),
                          Text('Журнал Antigravity Cleaner', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.trash, size: 14, color: Colors.white38),
                        onPressed: () => setState(() => _operationLogs = ''),
                        tooltip: 'Очистить журнал',
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  SelectableText(
                    _operationLogs,
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.greenAccent, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
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
}
