import 'package:flutter/material.dart';
import '../theme.dart';

class CountryFlagWidget extends StatelessWidget {
  final String countryCode;
  final double width;
  final double height;
  final double borderRadius;
  final String fallbackEmoji;

  const CountryFlagWidget({
    super.key,
    required this.countryCode,
    this.width = 30,
    this.height = 20,
    this.borderRadius = 4,
    this.fallbackEmoji = '🌐',
  });

  @override
  Widget build(BuildContext context) {
    final cleanCode = countryCode.trim().toLowerCase();
    if (cleanCode.length != 2) {
      return Text(fallbackEmoji, style: TextStyle(fontSize: height * 0.9));
    }

    final flagUrl = 'https://flagcdn.com/w80/$cleanCode.png';

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Image.network(
          flagUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: QuantumVpnTheme.card,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: QuantumVpnTheme.primaryCyan.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Text(
                cleanCode.toUpperCase(),
                style: TextStyle(
                  fontSize: height * 0.45,
                  fontWeight: FontWeight.bold,
                  color: QuantumVpnTheme.primaryCyan,
                  letterSpacing: 0.5,
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              alignment: Alignment.center,
              child: Text(
                cleanCode.toUpperCase(),
                style: TextStyle(
                  fontSize: height * 0.45,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
