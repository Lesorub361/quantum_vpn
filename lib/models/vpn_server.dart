import 'dart:convert';

class VpnServer {
  final String hostName;
  final String ip;
  final int score;
  final int ping; // ms
  final int speedBps; // bits per second
  final String countryLong;
  final String countryShort;
  final int numVpnSessions;
  final int uptime;
  final int totalUsers;
  final int totalTraffic;
  final String logType;
  final String operator;
  final String message;
  final String ovpnConfigBase64;
  final String? username;
  final String? password;

  const VpnServer({
    required this.hostName,
    required this.ip,
    required this.score,
    required this.ping,
    required this.speedBps,
    required this.countryLong,
    required this.countryShort,
    required this.numVpnSessions,
    required this.uptime,
    required this.totalUsers,
    required this.totalTraffic,
    required this.logType,
    required this.operator,
    required this.message,
    required this.ovpnConfigBase64,
    this.username,
    this.password,
  });

  /// Decodes base64 OpenVPN configuration into plain string
  String get ovpnConfigRaw {
    try {
      if (ovpnConfigBase64.isEmpty) return '';
      return utf8.decode(base64.decode(ovpnConfigBase64.replaceAll('\n', '').replaceAll('\r', '')));
    } catch (_) {
      return '';
    }
  }

  /// Formatted Speed (e.g. "145.2 Mbps")
  String get speedFormatted {
    if (speedBps <= 0) return '0 Mbps';
    final mbps = speedBps / 1000000;
    if (mbps >= 1000) {
      return '${(mbps / 1000).toStringAsFixed(2)} Gbps';
    }
    return '${mbps.toStringAsFixed(1)} Mbps';
  }

  /// Formatted Ping (e.g. "18 ms")
  String get pingFormatted => ping <= 0 ? '-- ms' : '$ping ms';

  /// Flag Emoji from 2-letter ISO code (e.g. JP -> 🇯🇵, US -> 🇺🇸)
  String get flagEmoji {
    if (countryShort.length != 2) return '🌐';
    final code = countryShort.toUpperCase();
    final first = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  /// Parse single line from VPN Gate CSV API
  static VpnServer? fromCsvRow(List<String> row) {
    if (row.length < 15) return null;
    try {
      return VpnServer(
        hostName: row[0].trim(),
        ip: row[1].trim(),
        score: int.tryParse(row[2].trim()) ?? 0,
        ping: int.tryParse(row[3].trim()) ?? 999,
        speedBps: int.tryParse(row[4].trim()) ?? 0,
        countryLong: row[5].trim(),
        countryShort: row[6].trim().toUpperCase(),
        numVpnSessions: int.tryParse(row[7].trim()) ?? 0,
        uptime: int.tryParse(row[8].trim()) ?? 0,
        totalUsers: int.tryParse(row[9].trim()) ?? 0,
        totalTraffic: int.tryParse(row[10].trim()) ?? 0,
        logType: row[11].trim(),
        operator: row[12].trim(),
        message: row[13].trim(),
        ovpnConfigBase64: row[14].trim(),
      );
    } catch (_) {
      return null;
    }
  }
}
