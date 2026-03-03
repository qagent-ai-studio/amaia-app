import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models.dart';

/// Card that shows the last button press and a toggle for notifications.
class ButtonPressCard extends StatelessWidget {
  const ButtonPressCard({
    super.key,
    required this.lastPress,
    required this.notifyEnabled,
    required this.onToggleNotify,
  });

  final ButtonPressEvent? lastPress;
  final bool notifyEnabled;
  final ValueChanged<bool> onToggleNotify;

  IconData _pressIcon(String type) {
    switch (type) {
      case 'double':
        return Icons.touch_app_rounded;
      case 'long':
        return Icons.pan_tool_rounded;
      default:
        return Icons.ads_click_rounded;
    }
  }

  Color _pressColor(String type) {
    switch (type) {
      case 'double':
        return const Color(0xFFA78BFA);
      case 'long':
        return const Color(0xFFFBBF24);
      default:
        return const Color(0xFF38BDF8);
    }
  }

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
            // Notify toggle
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded,
                      color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Escuchar presiones',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: notifyEnabled,
                    onChanged: onToggleNotify,
                    activeColor: const Color(0xFF38BDF8),
                    activeTrackColor: const Color(0xFF38BDF8).withOpacity(0.3),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFF0F172A)),

            // Last press display
            Padding(
              padding: const EdgeInsets.all(20),
              child: lastPress == null
                  ? Column(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 48,
                          color: Colors.white.withOpacity(0.15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notifyEnabled
                              ? 'Esperando presión...'
                              : 'Activa las notificaciones para capturar',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : _PressDisplay(press: lastPress!),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressDisplay extends StatelessWidget {
  const _PressDisplay({required this.press});

  final ButtonPressEvent press;

  IconData _pressIcon(String type) {
    switch (type) {
      case 'double':
        return Icons.touch_app_rounded;
      case 'long':
        return Icons.pan_tool_rounded;
      default:
        return Icons.ads_click_rounded;
    }
  }

  Color _pressColor(String type) {
    switch (type) {
      case 'double':
        return const Color(0xFFA78BFA);
      case 'long':
        return const Color(0xFFFBBF24);
      default:
        return const Color(0xFF38BDF8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _pressColor(press.pressType);
    final formatter = DateFormat('HH:mm:ss - dd/MM/yyyy');

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_pressIcon(press.pressType), color: color, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                press.label,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatter.format(press.timestamp),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
