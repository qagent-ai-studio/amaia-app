import 'package:flutter/material.dart';

import '../../domain/models.dart';

class TxPowerDialog extends StatefulWidget {
  const TxPowerDialog({super.key, required this.currentTxPower});

  final int currentTxPower;

  @override
  State<TxPowerDialog> createState() => _TxPowerDialogState();
}

class _TxPowerDialogState extends State<TxPowerDialog> {
  late TxPowerLevel _selected;

  @override
  void initState() {
    super.initState();
    _selected = TxPowerLevel.fromValue(widget.currentTxPower);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Potencia de transmisión',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: TxPowerLevel.values
            .map(
              (level) => RadioListTile<TxPowerLevel>(
                title: Text(
                  level.label,
                  style: const TextStyle(color: Colors.white),
                ),
                value: level,
                groupValue: _selected,
                activeColor: const Color(0xFF38BDF8),
                onChanged: (v) => setState(() => _selected = v!),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0EA5E9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, _selected.value),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
