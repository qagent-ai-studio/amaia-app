import 'package:flutter/material.dart';

/// Dialog for selecting advertising interval.
/// Range: 100ms – 10000ms (100ms steps)
class AdvIntervalDialog extends StatefulWidget {
  const AdvIntervalDialog({super.key, required this.currentIntervalMs});

  final int currentIntervalMs;

  @override
  State<AdvIntervalDialog> createState() => _AdvIntervalDialogState();
}

class _AdvIntervalDialogState extends State<AdvIntervalDialog> {
  static const _min = 100.0;
  static const _max = 10000.0;
  static const _divisions = 99;

  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentIntervalMs
        .clamp(_min.toInt(), _max.toInt())
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Intervalo de publicidad',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_value.toInt()} ms',
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _value,
            min: _min,
            max: _max,
            divisions: _divisions,
            activeColor: const Color(0xFF38BDF8),
            inactiveColor: const Color(0xFF0F172A),
            onChanged: (v) => setState(() => _value = (v / 100).round() * 100.0),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('100ms', style: TextStyle(color: Colors.white38, fontSize: 11)),
              Text('10000ms', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
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
          onPressed: () => Navigator.pop(context, _value.toInt()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
