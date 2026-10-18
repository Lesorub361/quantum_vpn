import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_vpn/models/vpn_server.dart';

void main() {
  group('VpnServer Model Tests', () {
    test('Correctly parses VPN Gate CSV row', () {
      final row = [
        'public-vpn-1',
        '127.0.0.1',
        '100',
        '5',
        '50000000',
        'United States',
        'US',
        '10',
        '20',
        '500',
        '3000',
        '2wk',
        'Admin',
        'Welcome',
        'AQIDBA==',
      ];
      final server = VpnServer.fromCsvRow(row);

      expect(server, isNotNull);
      expect(server!.hostName, 'public-vpn-1');
      expect(server.ip, '127.0.0.1');
      expect(server.score, 100);
      expect(server.ping, 5);
      expect(server.speedBps, 50000000);
      expect(server.countryLong, 'United States');
      expect(server.countryShort, 'US');
      expect(server.flagEmoji, '🇺🇸');
      expect(server.speedFormatted, contains('50.0 Mbps'));
    });

    test('Skips short row gracefully', () {
      expect(VpnServer.fromCsvRow(['*vpn_servers']), isNull);
      expect(VpnServer.fromCsvRow([]), isNull);
    });

    test('Formats ping and speed correctly', () {
      const server = VpnServer(
        hostName: 'node-jp',
        ip: '1.2.3.4',
        score: 1000,
        ping: 15,
        speedBps: 1000000000, // 1 Gbps
        countryLong: 'Japan',
        countryShort: 'JP',
        numVpnSessions: 5,
        uptime: 3600,
        totalUsers: 100,
        totalTraffic: 100000,
        logType: '2wk',
        operator: 'OpenVPN',
        message: 'Welcome',
        ovpnConfigBase64: '',
      );

      expect(server.pingFormatted, '15 ms');
      expect(server.flagEmoji, '🇯🇵');
      expect(server.speedFormatted, '1.00 Gbps');
    });
  });
}
