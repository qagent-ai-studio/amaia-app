import 'package:flutter/material.dart';

import '../../domain/models.dart';

/// Shows read-only device information: firmware, hardware, MAC address.
class DeviceInfoCard extends StatelessWidget {
  const DeviceInfoCard({super.key, required this.info, required this.mac});

  final DeviceInfo info;
  final String mac;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _InfoRow(label: 'MAC Address', value: mac, mono: true),
            _divider(),
            _InfoRow(label: 'Firmware', value: info.firmwareVersion),
            _divider(),
            _InfoRow(label: 'Hardware', value: info.hardwareVersion),
            _divider(),
            _InfoRow(
              label: 'Contraseña',
              value: info.isPasswordEnabled ? 'Activada' : 'Desactivada',
              valueColor: info.isPasswordEnabled
                  ? const Color(0xFFFBBF24)
                  : Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFF0F172A));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool mono;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}
