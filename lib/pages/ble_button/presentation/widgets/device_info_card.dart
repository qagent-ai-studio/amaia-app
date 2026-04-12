import 'package:flutter/material.dart';

import '../../domain/models.dart';

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [_InfoRow(label: 'MAC Address', value: mac, mono: true)],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 16, endIndent: 16, color: Color(0xFFE2E8F0));
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
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ),
          Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF1E293B),
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
