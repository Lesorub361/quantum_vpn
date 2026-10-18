import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_server.dart';

enum VpnSortOrder {
  fastestSpeed,
  lowestPing,
  highestScore,
  country,
}

class VpnGateState {
  final List<VpnServer> servers;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String? selectedCountryFilter;
  final VpnSortOrder sortOrder;
  final VpnServer? selectedServer;

  const VpnGateState({
    this.servers = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedCountryFilter,
    this.sortOrder = VpnSortOrder.fastestSpeed,
    this.selectedServer,
  });

  VpnGateState copyWith({
    List<VpnServer>? servers,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? selectedCountryFilter,
    bool clearCountryFilter = false,
    VpnSortOrder? sortOrder,
    VpnServer? selectedServer,
  }) {
    return VpnGateState(
      servers: servers ?? this.servers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCountryFilter: clearCountryFilter
          ? null
          : (selectedCountryFilter ?? this.selectedCountryFilter),
      sortOrder: sortOrder ?? this.sortOrder,
      selectedServer: selectedServer ?? this.selectedServer,
    );
  }

  /// Get filtered and sorted servers
  List<VpnServer> get filteredServers {
    var list = servers.where((s) {
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final match = s.countryLong.toLowerCase().contains(q) ||
            s.countryShort.toLowerCase().contains(q) ||
            s.ip.contains(q) ||
            s.hostName.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (selectedCountryFilter != null && selectedCountryFilter!.isNotEmpty) {
        if (s.countryShort != selectedCountryFilter) return false;
      }
      return true;
    }).toList();

    switch (sortOrder) {
      case VpnSortOrder.fastestSpeed:
        list.sort((a, b) => b.speedBps.compareTo(a.speedBps));
        break;
      case VpnSortOrder.lowestPing:
        list.sort((a, b) => a.ping.compareTo(b.ping));
        break;
      case VpnSortOrder.highestScore:
        list.sort((a, b) => b.score.compareTo(a.score));
        break;
      case VpnSortOrder.country:
        list.sort((a, b) => a.countryLong.compareTo(b.countryLong));
        break;
    }

    return list;
  }

  /// Unique list of countries present in the loaded servers
  List<Map<String, String>> get availableCountries {
    final map = <String, String>{};
    for (final s in servers) {
      map[s.countryShort] = s.countryLong;
    }
    return map.entries
        .map((e) => {'code': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }
}

class VpnGateNotifier extends StateNotifier<VpnGateState> {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 25),
  ));

  VpnGateNotifier() : super(const VpnGateState()) {
    loadCachedServers();
    refreshServers();
  }

  /// Main VPN Gate API URL + Mirrored Endpoints
  static const List<String> _endpoints = [
    'http://www.vpngate.net/api/iphone/',
    'https://raw.githubusercontent.com/barry-far/V2ray-Configs/main/vpngate.csv',
  ];

  Future<void> loadCachedServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCsv = prefs.getString('cached_vpngate_csv');
      if (cachedCsv != null && cachedCsv.isNotEmpty) {
        final parsed = _parseCsv(cachedCsv);
        if (parsed.isNotEmpty) {
          state = state.copyWith(
            servers: parsed,
            selectedServer: state.selectedServer ?? parsed.first,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> refreshServers() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    for (final url in _endpoints) {
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(responseType: ResponseType.plain),
        );

        if (response.statusCode == 200 && response.data != null) {
          final parsed = _parseCsv(response.data!);
          if (parsed.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cached_vpngate_csv', response.data!);

            // Auto-select fastest server if none selected
            final best = parsed.reduce((curr, next) =>
                curr.speedBps > next.speedBps ? curr : next);

            state = state.copyWith(
              servers: parsed,
              isLoading: false,
              selectedServer: state.selectedServer ?? best,
              error: null,
            );
            return;
          }
        }
      } catch (e) {
        // Try next mirror
      }
    }

    if (state.servers.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Не удалось загрузить сервера. Проверьте интернет и нажмите «Обновить».',
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  List<VpnServer> _parseCsv(String csv) {
    final lines = csv.split('\n');
    final servers = <VpnServer>[];

    bool headerFound = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('*')) continue;

      if (!headerFound) {
        if (trimmed.startsWith('#HostName')) {
          headerFound = true;
        }
        continue;
      }

      final row = trimmed.split(',');
      final server = VpnServer.fromCsvRow(row);
      if (server != null && server.ovpnConfigBase64.isNotEmpty) {
        servers.add(server);
      }
    }

    return servers;
  }

  void selectServer(VpnServer server) {
    state = state.copyWith(selectedServer: server);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCountryFilter(String? countryCode) {
    if (countryCode == null) {
      state = state.copyWith(clearCountryFilter: true);
    } else {
      state = state.copyWith(selectedCountryFilter: countryCode);
    }
  }

  void setSortOrder(VpnSortOrder order) {
    state = state.copyWith(sortOrder: order);
  }
}

final vpnGateProvider =
    StateNotifierProvider<VpnGateNotifier, VpnGateState>((ref) {
  return VpnGateNotifier();
});
