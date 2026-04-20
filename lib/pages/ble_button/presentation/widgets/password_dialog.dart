import 'package:flutter/material.dart';

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key});

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _oldVisible = false;
  bool _newVisible = false;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Cambiar contraseña',
        style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PasswordField(
              controller: _oldController,
              label: 'Contraseña actual',
              visible: _oldVisible,
              onToggle: () => setState(() => _oldVisible = !_oldVisible),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _newController,
              label: 'Nueva contraseña',
              visible: _newVisible,
              onToggle: () => setState(() => _newVisible = !_newVisible),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                if (v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _confirmController,
              label: 'Confirmar nueva contraseña',
              visible: _newVisible,
              onToggle: () => setState(() => _newVisible = !_newVisible),
              validator: (v) => v != _newController.text
                  ? 'Las contraseñas no coinciden'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0EA5E9),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'old': _oldController.text,
                'new': _newController.text,
              });
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      validator: validator,
      style: const TextStyle(color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF0F2FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(color: Color(0xFFF87171)),
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: const Color(0xFF94A3B8),
            size: 18,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
