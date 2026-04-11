import 'package:flutter/material.dart';

import '../../domain/models.dart';

/// Card with all configurable settings for the connected device.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.info,
    required this.onEditDeviceName,
    required this.onChangePassword,
    required this.onResetDevice,
  });

  final DeviceInfo? info;
  final VoidCallback onEditDeviceName;
  final VoidCallback onChangePassword;
  final VoidCallback onResetDevice;

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
          children: [
            _SettingsTile(
              icon: Icons.badge_rounded,
              label: 'Nombre del dispositivo',
              value: info?.deviceName,
              onTap: onEditDeviceName,
            ),
            _divider(),
            _SettingsTile(
              icon: Icons.lock_rounded,
              label: 'Cambiar contraseña',
              value: info?.isPasswordEnabled == true ? 'Protegida' : 'Sin protección',
              onTap: onChangePassword,
            ),
            _divider(),
            _SettingsTile(
              icon: Icons.restart_alt_rounded,
              label: 'Restaurar valores de fábrica',
              value: 'Irreversible',
              valueColor: const Color(0xFFF87171),
              onTap: onResetDevice,
              iconColor: const Color(0xFFF87171),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFE2E8F0));
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.valueColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? const Color(0xFF6951C1),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: TextStyle(
                  color: valueColor ?? const Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB0BEC5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
