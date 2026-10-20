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
      expect(server.isStealthProtocol, isFalse);
      expect(server.protocolBadge, 'OpenVPN');
    });

    test('Correctly identifies stealth protocols (VLESS Reality & Shadowsocks)', () {
      const vlessServer = VpnServer(
        hostName: 'vless-de',
        ip: '150.241.101.80',
        score: 10000,
        ping: 45,
        speedBps: 150000000,
        countryLong: 'Germany',
        countryShort: 'DE',
        numVpnSessions: 1,
        uptime: 86400,
        totalUsers: 1,
        totalTraffic: 1000,
        logType: 'stealth',
        operator: 'QuantumStealth',
        message: 'Xray Core',
        ovpnConfigBase64: '',
        protocolType: 'vless',
        port: 8443,
        sni: 'yandex.net',
      );

      expect(vlessServer.isStealthProtocol, isTrue);
      expect(vlessServer.protocolBadge, 'VLESS Reality');
      expect(vlessServer.flagEmoji, '🇩🇪');

      const ssServer = VpnServer(
        hostName: 'ss-no',
        ip: '185.213.23.63',
        score: 10000,
        ping: 60,
        speedBps: 200000000,
        countryLong: 'Norway',
        countryShort: 'NO',
        numVpnSessions: 1,
        uptime: 86400,
        totalUsers: 1,
        totalTraffic: 1000,
        logType: 'stealth',
        operator: 'QuantumStealth',
        message: 'Shadowsocks',
        ovpnConfigBase64: '',
        protocolType: 'shadowsocks',
        port: 990,
      );

      expect(ssServer.isStealthProtocol, isTrue);
      expect(ssServer.protocolBadge, 'Shadowsocks');
      expect(ssServer.flagEmoji, '🇳🇴');
    });
  });
}
