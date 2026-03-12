import 'package:flutter/material.dart';

/// Displays battery level with a visual gauge.
class BatteryCard extends StatelessWidget {
  const BatteryCard({
    super.key,
    required this.percent,
    required this.onRefresh,
  });

  final int? percent;
  final VoidCallback onRefresh;

  Color _batteryColor(int pct) {
    if (pct > 60) return const Color(0xFF4ADE80);
    if (pct > 25) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  IconData _batteryIcon(int pct) {
    if (pct > 90) return Icons.battery_full_rounded;
    if (pct > 70) return Icons.battery_6_bar_rounded;
    if (pct > 50) return Icons.battery_5_bar_rounded;
    if (pct > 30) return Icons.battery_4_bar_rounded;
    if (pct > 15) return Icons.battery_2_bar_rounded;
    return Icons.battery_1_bar_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (percent == null)
              const Text(
                'Sin datos de batería',
                style: TextStyle(color: Colors.white54),
              )
            else ...[
              Icon(
                _batteryIcon(percent!),
                color: _batteryColor(percent!),
                size: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: _batteryColor(percent!),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent! / 100,
                        minHeight: 8,
                        backgroundColor: const Color(0xFF0F172A),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _batteryColor(percent!)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white38, size: 20),
              onPressed: onRefresh,
              tooltip: 'Leer batería (puede causar desconexión)',
            ),
          ],
        ),
      ),
    );
  }
}
