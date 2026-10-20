import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/vpn_server.dart';

class QuantumStealthState {
  final List<VpnServer> servers;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final String selectedProtocol; // 'all', 'vless', 'shadowsocks'
  final String selectedCountry; // 'all' or country code

  const QuantumStealthState({
    this.servers = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedProtocol = 'all',
    this.selectedCountry = 'all',
  });

  QuantumStealthState copyWith({
    List<VpnServer>? servers,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    String? selectedProtocol,
    String? selectedCountry,
  }) {
    return QuantumStealthState(
      servers: servers ?? this.servers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedProtocol: selectedProtocol ?? this.selectedProtocol,
      selectedCountry: selectedCountry ?? this.selectedCountry,
    );
  }

  List<VpnServer> get filteredServers {
    return servers.where((server) {
      if (selectedProtocol != 'all' && server.protocolType.toLowerCase() != selectedProtocol.toLowerCase()) {
        return false;
      }
      if (selectedCountry != 'all' && server.countryShort.toUpperCase() != selectedCountry.toUpperCase()) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchesCountry = server.countryLong.toLowerCase().contains(q) ||
            server.countryShort.toLowerCase().contains(q);
        final matchesIp = server.ip.contains(q);
        final matchesHost = server.hostName.toLowerCase().contains(q);
        final matchesProto = server.protocolBadge.toLowerCase().contains(q);
        if (!matchesCountry && !matchesIp && !matchesHost && !matchesProto) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<String> get availableCountries {
    final set = <String>{};
    for (final s in servers) {
      if (s.countryShort.isNotEmpty) {
        set.add(s.countryShort.toUpperCase());
      }
    }
    final list = set.toList()..sort();
    return ['all', ...list];
  }
}

class QuantumStealthNotifier extends StateNotifier<QuantumStealthState> {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) QuantumVPN/1.0',
    },
  ));

  QuantumStealthNotifier() : super(const QuantumStealthState()) {
    _initServers();
  }

  Future<void> _initServers() async {
    state = state.copyWith(isLoading: true);
    // 1. Try local disk cache
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File(p.join(cacheDir.path, 'quantum_stealth_cache.json'));
      if (await cacheFile.exists()) {
        final content = await cacheFile.readAsString();
        final parsed = _parseCachedJson(content);
        if (parsed.isNotEmpty) {
          state = state.copyWith(servers: parsed, isLoading: false);
          // Refresh in background
          fetchLiveServers();
          return;
        }
      }
    } catch (_) {}

    // 2. Load bundled asset nodes
    try {
      final bundled = await rootBundle.loadString('assets/stealth_nodes.json');
      final parsed = _parseCachedJson(bundled);
      if (parsed.isNotEmpty) {
        state = state.copyWith(servers: parsed, isLoading: false);
        // Refresh in background
        fetchLiveServers();
        return;
      }
    } catch (_) {}

    // 3. Fallback to live fetch
    await fetchLiveServers();
  }

  Future<void> fetchLiveServers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final candidates = [
        'https://raw.githubusercontent.com/Au1rxx/free-vpn-subscriptions/main/output/stable/singbox-0001.json',
        'https://raw.githubusercontent.com/Au1rxx/free-vpn-subscriptions/main/output/all-verified/singbox-0001.json',
      ];

      Response? response;
      for (final url in candidates) {
        try {
          response = await _dio.get<String>(
            url,
            options: Options(responseType: ResponseType.plain),
          );
          if (response.statusCode == 200 && response.data != null) {
            break;
          }
        } catch (_) {}
      }

      if (response == null || response.data == null) {
        throw Exception('Не удалось загрузить обновленный список серверов из облака');
      }

      final jsonData = json.decode(response.data as String) as Map<String, dynamic>;
      final outbounds = jsonData['outbounds'] as List? ?? [];

      final List<VpnServer> fetched = [];
      for (final item in outbounds) {
        if (item is! Map<String, dynamic>) continue;
        final type = (item['type'] as String?)?.toLowerCase();
        if (type != 'shadowsocks' && type != 'vless' && type != 'trojan') {
          continue;
        }

        final serverHost = item['server']?.toString() ?? '';
        final serverPort = int.tryParse(item['server_port']?.toString() ?? '') ?? 443;
        if (serverHost.isEmpty) continue;

        String countryCode = 'NL';
        String countryName = 'Нидерланды';
        final tag = item['tag']?.toString() ?? '';

        // Attempt country detection from tag or known server patterns
        final countryGuess = _guessCountry(tag, serverHost);
        countryCode = countryGuess.code;
        countryName = countryGuess.name;

        // Build outbound config for Xray
        final Map<String, dynamic> xrayOutbound;
        String? sni;

        if (type == 'shadowsocks') {
          xrayOutbound = {
            'protocol': 'shadowsocks',
            'tag': 'proxy',
            'settings': {
              'servers': [
                {
                  'address': serverHost,
                  'port': serverPort,
                  'method': item['method'],
                  'password': item['password'],
                }
              ]
            }
          };
        } else if (type == 'vless') {
          final reality = item['tls']?['reality'] as Map<String, dynamic>?;
          sni = item['tls']?['server_name']?.toString();
          if (reality != null && reality['enabled'] == true) {
            xrayOutbound = {
              'protocol': 'vless',
              'tag': 'proxy',
              'settings': {
                'vnext': [
                  {
                    'address': serverHost,
                    'port': serverPort,
                    'users': [
                      {
                        'id': item['uuid'],
                        'encryption': 'none',
                        'flow': item['flow'] ?? 'xtls-rprx-vision',
                      }
                    ]
                  }
                ]
              },
              'streamSettings': {
                'network': 'tcp',
                'security': 'reality',
                'realitySettings': {
                  'serverName': sni ?? 'www.cloudflare.com',
                  'publicKey': reality['public_key'] ?? '',
                  'fingerprint': item['tls']?['utls']?['fingerprint'] ?? 'chrome',
                  'shortId': reality['short_id'] ?? '',
                  'spiderX': '',
                }
              }
            };
          } else {
            xrayOutbound = {
              'protocol': 'vless',
              'tag': 'proxy',
              'settings': {
                'vnext': [
                  {
                    'address': serverHost,
                    'port': serverPort,
                    'users': [
                      {
                        'id': item['uuid'],
                        'encryption': 'none',
                      }
                    ]
                  }
                ]
              },
              'streamSettings': {
                'network': 'tcp',
                'security': 'tls',
                'tlsSettings': {
                  'serverName': sni ?? serverHost,
                  'allowInsecure': true,
                }
              }
            };
          }
        } else {
          // Trojan
          sni = item['tls']?['server_name']?.toString() ?? serverHost;
          xrayOutbound = {
            'protocol': 'trojan',
            'tag': 'proxy',
            'settings': {
              'servers': [
                {
                  'address': serverHost,
                  'port': serverPort,
                  'password': item['password'],
                }
              ]
            },
            'streamSettings': {
              'network': 'tcp',
              'security': 'tls',
              'tlsSettings': {
                'serverName': sni,
                'allowInsecure': true,
              }
            }
          };
        }

        fetched.add(VpnServer(
          hostName: serverHost,
          ip: serverHost,
          score: 10000,
          ping: 350,
          speedBps: 150000000, // 150 Mbps
          countryLong: countryName,
          countryShort: countryCode,
          numVpnSessions: 1,
          uptime: 86400,
          totalUsers: 1,
          totalTraffic: 1000000,
          logType: 'stealth',
          operator: 'QuantumStealth',
          message: '⚡ Высокоскоростное ядро Xray-Core (DPI Bypass)',
          ovpnConfigBase64: '',
          protocolType: type ?? 'shadowsocks',
          rawConfig: json.encode(xrayOutbound),
          port: serverPort,
          sni: sni,
        ));

        if (fetched.length >= 100) break;
      }

      if (fetched.isNotEmpty) {
        state = state.copyWith(servers: fetched, isLoading: false);
        _saveToCache(fetched);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      if (state.servers.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Ошибка загрузки серверов: $e',
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  ({String code, String name}) _guessCountry(String tag, String host) {
    final lower = (tag + host).toLowerCase();
    if (lower.contains('de') || lower.contains('germany') || lower.contains('frankfurt')) {
      return (code: 'DE', name: 'Германия');
    }
    if (lower.contains('us') || lower.contains('united states') || lower.contains('america')) {
      return (code: 'US', name: 'США');
    }
    if (lower.contains('nl') || lower.contains('netherlands') || lower.contains('amsterdam')) {
      return (code: 'NL', name: 'Нидерланды');
    }
    if (lower.contains('fr') || lower.contains('france') || lower.contains('paris')) {
      return (code: 'FR', name: 'Франция');
    }
    if (lower.contains('gb') || lower.contains('uk') || lower.contains('london')) {
      return (code: 'GB', name: 'Великобритания');
    }
    if (lower.contains('fi') || lower.contains('finland') || lower.contains('helsinki')) {
      return (code: 'FI', name: 'Финляндия');
    }
    if (lower.contains('no') || lower.contains('norway') || lower.contains('oslo')) {
      return (code: 'NO', name: 'Норвегия');
    }
    if (lower.contains('jp') || lower.contains('japan') || lower.contains('tokyo')) {
      return (code: 'JP', name: 'Япония');
    }
    if (lower.contains('sg') || lower.contains('singapore')) {
      return (code: 'SG', name: 'Сингапур');
    }
    if (lower.contains('ca') || lower.contains('canada')) {
      return (code: 'CA', name: 'Канада');
    }
    if (lower.contains('pl') || lower.contains('poland') || lower.contains('warsaw')) {
      return (code: 'PL', name: 'Польша');
    }
    return (code: 'NL', name: 'Нидерланды');
  }

  List<VpnServer> _parseCachedJson(String content) {
    try {
      final list = json.decode(content) as List;
      final List<VpnServer> servers = [];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final proto = item['protocol']?.toString() ?? 'shadowsocks';
        final serverHost = item['server']?.toString() ?? '';
        final port = int.tryParse(item['port']?.toString() ?? '') ?? 443;
        final ip = item['ip']?.toString() ?? serverHost;
        final ping = int.tryParse(item['ping']?.toString() ?? '') ?? 300;
        final cc = item['countryShort']?.toString() ?? 'NL';
        final cname = item['countryLong']?.toString() ?? 'Нидерланды';
        final outbound = item['outbound'] != null ? json.encode(item['outbound']) : '';
        final sni = item['sni']?.toString();

        servers.add(VpnServer(
          hostName: serverHost,
          ip: ip,
          score: 10000,
          ping: ping,
          speedBps: 200000000, // 200 Mbps
          countryLong: cname,
          countryShort: cc,
          numVpnSessions: 1,
          uptime: 86400,
          totalUsers: 1,
          totalTraffic: 1000000,
          logType: 'stealth',
          operator: 'QuantumStealth',
          message: '⚡ Высокоскоростное ядро Xray-Core (DPI Bypass)',
          ovpnConfigBase64: '',
          protocolType: proto,
          rawConfig: outbound,
          port: port,
          sni: sni,
        ));
      }
      return servers;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveToCache(List<VpnServer> servers) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File(p.join(cacheDir.path, 'quantum_stealth_cache.json'));
      final exportList = servers.map((s) => {
        'protocol': s.protocolType,
        'server': s.hostName,
        'port': s.port,
        'ip': s.ip,
        'ping': s.ping,
        'countryShort': s.countryShort,
        'countryLong': s.countryLong,
        'sni': s.sni,
        'outbound': s.rawConfig != null && s.rawConfig!.isNotEmpty
            ? json.decode(s.rawConfig!)
            : null,
      }).toList();
      await cacheFile.writeAsString(json.encode(exportList));
    } catch (_) {}
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setProtocolFilter(String proto) {
    state = state.copyWith(selectedProtocol: proto);
  }

  void setCountryFilter(String country) {
    state = state.copyWith(selectedCountry: country);
  }
}

final quantumStealthProvider =
    StateNotifierProvider<QuantumStealthNotifier, QuantumStealthState>((ref) {
  return QuantumStealthNotifier();
});
