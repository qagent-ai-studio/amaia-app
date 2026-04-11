import 'package:flutter/material.dart';

/// Confirmation dialog before factory reset.
class ResetConfirmDialog extends StatelessWidget {
  const ResetConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 22),
          SizedBox(width: 8),
          Text(
            'Restaurar fábrica',
            style: TextStyle(
              color: Color(0xFFF87171),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: const Text(
        'Esta acción restaurará todos los ajustes del dispositivo a los valores de fábrica. '
        'Esta operación no se puede deshacer.',
        style: TextStyle(color: Color(0xFF64748B), height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF87171),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Restaurar'),
        ),
      ],
    );
  }
}
