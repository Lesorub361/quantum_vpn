import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_server.dart';

class RiseupServerItem {
  final String id;
  final String name;
  final String hostname;
  final String ip;
  final String countryLong;
  final String countryShort;
  final String city;
  final int ping;
  final double speedMbps;
  final List<String> protocols;

  const RiseupServerItem({
    required this.id,
    required this.name,
    required this.hostname,
    required this.ip,
    required this.countryLong,
    required this.countryShort,
    required this.city,
    this.ping = 35,
    this.speedMbps = 150.0,
    this.protocols = const ['udp1194', 'udp53', 'tcp443', 'tcp80'],
  });

  String get flagEmoji {
    if (countryShort.length != 2) return '🌐';
    final code = countryShort.toUpperCase();
    final first = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}

class RiseupVpnState {
  final List<RiseupServerItem> servers;
  final String selectedProtocol;
  final bool isLoading;
  final String? statusMessage;
  final bool hasCertificate;

  const RiseupVpnState({
    required this.servers,
    this.selectedProtocol = 'udp1194',
    this.isLoading = false,
    this.statusMessage,
    this.hasCertificate = false,
  });

  RiseupVpnState copyWith({
    List<RiseupServerItem>? servers,
    String? selectedProtocol,
    bool? isLoading,
    String? statusMessage,
    bool? hasCertificate,
    bool clearStatus = false,
  }) {
    return RiseupVpnState(
      servers: servers ?? this.servers,
      selectedProtocol: selectedProtocol ?? this.selectedProtocol,
      isLoading: isLoading ?? this.isLoading,
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
      hasCertificate: hasCertificate ?? this.hasCertificate,
    );
  }
}

class RiseupVpnNotifier extends StateNotifier<RiseupVpnState> {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'QuantumVPN/1.0.15 (Linux; Android)',
        'Accept': 'application/json, text/plain, */*',
      },
    ),
  );

  static const String _riseupCaPem = '''-----BEGIN CERTIFICATE-----
MIIBYjCCAQigAwIBAgIBATAKBggqhkjOPQQDAjAXMRUwEwYDVQQDEwxMRUFQIFJv
b3QgQ0EwHhcNMjExMTAyMTkwNTM3WhcNMjYxMTAyMTkxMDM3WjAXMRUwEwYDVQQD
EwxMRUFQIFJvb3QgQ0EwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQxOXBGu+gf
pjHzVteGTWL6XnFxtEnKMFpKaJkA/VOHmESzoLsZRQxt88GssxaqC01J17idQiqv
zgNpedmtvFtyo0UwQzAOBgNVHQ8BAf8EBAMCAqQwEgYDVR0TAQH/BAgwBgEB/wIB
ATAdBgNVHQ4EFgQUZdoUlJrCIUNFrpffAq+LQjnwEz4wCgYIKoZIzj0EAwIDSAAw
RQIgfr3w4tnRG+NdI3LsGPlsRktGK20xHTzsB3orB0yC6cICIQCB+/9y8nmSStfN
VUMUyk2hNd7/kC8nL222TTD7VZUtsg==
-----END CERTIFICATE-----''';

  static final List<RiseupServerItem> _defaultServers = [
    const RiseupServerItem(
      id: 'riseup_ams_1',
      name: 'Riseup Amsterdam #1',
      hostname: 'vpn06-ams.riseup.net',
      ip: '51.158.144.32',
      countryLong: 'Нидерланды (Амстердам)',
      countryShort: 'NL',
      city: 'Amsterdam',
      ping: 32,
      speedMbps: 200.0,
    ),
    const RiseupServerItem(
      id: 'riseup_ams_2',
      name: 'Riseup Amsterdam #2',
      hostname: 'vpn13-ams.riseup.net',
      ip: '51.158.144.31',
      countryLong: 'Нидерланды (Амстердам)',
      countryShort: 'NL',
      city: 'Amsterdam',
      ping: 34,
      speedMbps: 180.0,
    ),
    const RiseupServerItem(
      id: 'riseup_par_1',
      name: 'Riseup Paris #1',
      hostname: 'vpn05-par.riseup.net',
      ip: '195.154.119.165',
      countryLong: 'Франция (Париж)',
      countryShort: 'FR',
      city: 'Paris',
      ping: 42,
      speedMbps: 175.0,
    ),
    const RiseupServerItem(
      id: 'riseup_par_2',
      name: 'Riseup Paris #2',
      hostname: 'vpn08-par.riseup.net',
      ip: '51.15.187.53',
      countryLong: 'Франция (Париж)',
      countryShort: 'FR',
      city: 'Paris',
      ping: 44,
      speedMbps: 160.0,
    ),
    const RiseupServerItem(
      id: 'riseup_nyc',
      name: 'Riseup New York',
      hostname: 'vpn12-nyc.riseup.net',
      ip: '185.220.103.11',
      countryLong: 'США (Нью-Йорк)',
      countryShort: 'US',
      city: 'New York',
      ping: 95,
      speedMbps: 150.0,
    ),
    const RiseupServerItem(
      id: 'riseup_mia',
      name: 'Riseup Miami',
      hostname: 'vpn22-mia.riseup.net',
      ip: '89.187.173.169',
      countryLong: 'США (Майами)',
      countryShort: 'US',
      city: 'Miami',
      ping: 110,
      speedMbps: 140.0,
    ),
    const RiseupServerItem(
      id: 'riseup_sea',
      name: 'Riseup Seattle',
      hostname: 'vpn15-sea.riseup.net',
      ip: '199.254.238.55',
      countryLong: 'США (Сиэтл)',
      countryShort: 'US',
      city: 'Seattle',
      ping: 130,
      speedMbps: 135.0,
    ),
    const RiseupServerItem(
      id: 'riseup_mtl',
      name: 'Riseup Montreal',
      hostname: 'vpn10-mtl.riseup.net',
      ip: '199.58.83.11',
      countryLong: 'Канада (Монреаль)',
      countryShort: 'CA',
      city: 'Montreal',
      ping: 105,
      speedMbps: 140.0,
    ),
  ];

  RiseupVpnNotifier() : super(RiseupVpnState(servers: _defaultServers)) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedCert = prefs.getString('riseup_client_pem');
    if (cachedCert != null && cachedCert.isNotEmpty) {
      state = state.copyWith(hasCertificate: true);
    }
    // Fetch live servers in background
    fetchLiveGateways();
  }

  void setProtocol(String protocol) {
    state = state.copyWith(selectedProtocol: protocol);
  }

  Future<void> fetchLiveGateways() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _dio.get('https://api.black.riseup.net/3/config/eip-service.json');
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final gateways = data['gateways'] as List<dynamic>? ?? [];
        final locations = data['locations'] as Map<String, dynamic>? ?? {};

        final List<RiseupServerItem> parsed = [];
        for (final gw in gateways) {
          if (gw is! Map<String, dynamic>) continue;
          final host = gw['host'] as String? ?? '';
          final ip = gw['ip_address'] as String? ?? '';
          final locKey = gw['location'] as String? ?? '';

          if (host.isEmpty || ip.isEmpty) continue;

          final locInfo = locations[locKey] as Map<String, dynamic>? ?? {};
          final countryCode = locInfo['country_code'] as String? ?? 'NL';
          final locName = locInfo['name'] as String? ?? locKey;

          String countryLong;
          switch (countryCode.toUpperCase()) {
            case 'NL':
              countryLong = 'Нидерланды ($locName)';
              break;
            case 'FR':
              countryLong = 'Франция ($locName)';
              break;
            case 'US':
              countryLong = 'США ($locName)';
              break;
            case 'CA':
              countryLong = 'Канада ($locName)';
              break;
            default:
              countryLong = '$countryCode ($locName)';
          }

          parsed.add(
            RiseupServerItem(
              id: 'riseup_$host',
              name: 'Riseup $locName (${host.split('-').first.replaceAll('vpn', '#')})',
              hostname: host,
              ip: ip,
              countryLong: countryLong,
              countryShort: countryCode,
              city: locName,
              ping: countryCode == 'NL'
                  ? 35
                  : countryCode == 'FR'
                      ? 45
                      : 100,
              speedMbps: 150.0,
            ),
          );
        }

        if (parsed.isNotEmpty) {
          state = state.copyWith(servers: parsed, isLoading: false);
          return;
        }
      }
    } catch (_) {
      // Fallback to default fast servers if API is unreachable
    }
    state = state.copyWith(isLoading: false);
  }

  /// Fetches an anonymous client certificate from Riseup API
  Future<String> fetchClientCertificate({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = prefs.getString('riseup_client_pem');
      final cachedTimestamp = prefs.getInt('riseup_cert_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      // Certificates are valid for 90 days; refresh if older than 60 days
      if (cached != null && cached.isNotEmpty && (now - cachedTimestamp) < 60 * 24 * 3600 * 1000) {
        state = state.copyWith(hasCertificate: true);
        return cached;
      }
    }

    try {
      state = state.copyWith(statusMessage: 'Генерация анонимного SSL-сертификата Riseup...');
      final res = await _dio.get<String>(
        'https://api.black.riseup.net/3/cert',
        options: Options(responseType: ResponseType.plain),
      );

      final pem = res.data;
      if (pem != null && pem.contains('BEGIN CERTIFICATE') && pem.contains('BEGIN')) {
        await prefs.setString('riseup_client_pem', pem);
        await prefs.setInt('riseup_cert_time', DateTime.now().millisecondsSinceEpoch);
        state = state.copyWith(hasCertificate: true, clearStatus: true);
        return pem;
      } else {
        throw Exception('Неверный формат сертификата от Riseup API');
      }
    } catch (e) {
      state = state.copyWith(clearStatus: true);
      // If we have cached certificate, use it as fallback
      final cached = prefs.getString('riseup_client_pem');
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      throw Exception('Не удалось получить SSL-сертификат Riseup: $e');
    }
  }

  /// Generates complete standalone .ovpn configuration profile
  Future<String> fetchOvpnConfig(RiseupServerItem server, {String? protocol}) async {
    final proto = protocol ?? state.selectedProtocol;
    final pem = await fetchClientCertificate();

    final isUdp = proto.startsWith('udp');
    final String protoDirective = isUdp ? 'udp' : 'tcp';
    
    int port = 1194;
    if (proto == 'udp53') port = 53;
    if (proto == 'udp1194') port = 1194;
    if (proto == 'tcp443') port = 443;
    if (proto == 'tcp80') port = 80;

    final certBlock = _extractBlock(pem, '-----BEGIN CERTIFICATE-----', '-----END CERTIFICATE-----');
    final keyBlock = _extractKeyBlock(pem);

    final sb = StringBuffer();
    sb.writeln('client');
    sb.writeln('dev tun');
    sb.writeln('proto $protoDirective');
    sb.writeln('remote ${server.hostname} $port');
    sb.writeln('resolv-retry infinite');
    sb.writeln('nobind');
    sb.writeln('persist-key');
    sb.writeln('persist-tun');
    sb.writeln('remote-cert-tls server');
    sb.writeln('cipher AES-256-GCM');
    sb.writeln('data-ciphers AES-256-GCM');
    sb.writeln('auth SHA512');
    sb.writeln('verb 3');
    sb.writeln('sndbuf 524288');
    sb.writeln('rcvbuf 524288');
    sb.writeln('connect-retry-max 3');
    sb.writeln('connect-timeout 20');
    sb.writeln();
    sb.writeln('<ca>');
    sb.writeln(_riseupCaPem.trim());
    sb.writeln('</ca>');
    sb.writeln();
    sb.writeln('<cert>');
    sb.writeln(certBlock.trim());
    sb.writeln('</cert>');
    sb.writeln();
    sb.writeln('<key>');
    sb.writeln(keyBlock.trim());
    sb.writeln('</key>');

    return sb.toString();
  }

  /// Constructs a [VpnServer] model ready for [VpnConnectionNotifier.connect]
  Future<VpnServer> getVpnServer(RiseupServerItem server, {String? protocol}) async {
    final ovpnConfig = await fetchOvpnConfig(server, protocol: protocol);
    final base64Config = base64.encode(utf8.encode(ovpnConfig));

    return VpnServer(
      hostName: server.hostname,
      ip: server.ip,
      score: 1000,
      ping: server.ping,
      speedBps: (server.speedMbps * 1000000).toInt(),
      countryLong: server.countryLong,
      countryShort: server.countryShort,
      numVpnSessions: 50,
      uptime: 99999,
      totalUsers: 5000,
      totalTraffic: 999999999,
      logType: 'Zero-Logs',
      operator: 'Riseup Networks (LEAP)',
      message: 'Riseup Free Gigabit VPN · Без логирования · Без рекламы',
      ovpnConfigBase64: base64Config,
      username: null,
      password: null,
    );
  }

  static String _extractBlock(String text, String startMarker, String endMarker) {
    final start = text.indexOf(startMarker);
    if (start == -1) return '';
    final end = text.indexOf(endMarker, start);
    if (end == -1) return '';
    return text.substring(start, end + endMarker.length);
  }

  static String _extractKeyBlock(String text) {
    // Check for RSA PRIVATE KEY first
    var key = _extractBlock(text, '-----BEGIN RSA PRIVATE KEY-----', '-----END RSA PRIVATE KEY-----');
    if (key.isNotEmpty) return key;
    // Check for standard PRIVATE KEY
    key = _extractBlock(text, '-----BEGIN PRIVATE KEY-----', '-----END PRIVATE KEY-----');
    if (key.isNotEmpty) return key;
    // Check for EC PRIVATE KEY
    key = _extractBlock(text, '-----BEGIN EC PRIVATE KEY-----', '-----END EC PRIVATE KEY-----');
    return key;
  }
}

final riseupVpnProvider = StateNotifierProvider<RiseupVpnNotifier, RiseupVpnState>((ref) {
  return RiseupVpnNotifier();
});
