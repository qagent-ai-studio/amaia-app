import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ble_button_bloc.dart';
import '../domain/models.dart';
import 'permissions_page.dart';
import 'widgets/battery_card.dart';
import 'widgets/device_info_card.dart';
import 'widgets/password_dialog.dart';
import 'widgets/reset_confirm_dialog.dart';
import 'widgets/section_header.dart';
import 'widgets/settings_card.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key, required this.mac});

  final String mac;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BleButtonBloc, BleButtonState>(
      listener: (context, state) {
        if (state is BleButtonDisconnected) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dispositivo desconectado'),
              backgroundColor: Color(0xFF475569),
            ),
          );
        }
        if (state is BleButtonConnected && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is! BleButtonConnected) {
          return const Scaffold(
            backgroundColor: Color.fromARGB(255, 10, 53, 225),
            body: Center(
                child: CircularProgressIndicator(color: Color(0xFF6951C1))),
          );
        }

        final info = state.deviceInfo;
        return Scaffold(
          appBar: _buildAppBar(context, state, info),
          body: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                  Color.fromRGBO(244, 245, 252, 0.992),
                  Color.fromRGBO(219, 220, 243, 2.0)
                ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    tileMode: TileMode.clamp)),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (state.isLoading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Color(0xFFE2E8F0),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF6951C1)),
                  ),
                const SizedBox(height: 16),
                const SectionHeader(
                  icon: Icons.battery_charging_full_rounded,
                  title: 'Batería',
                ),
                BatteryCard(
                  percent: info?.batteryPercent,
                  onRefresh: () => context
                      .read<BleButtonBloc>()
                      .add(const BatteryReadRequested()),
                ),
                if (info != null) ...[
                  const SizedBox(height: 8),
                  const SectionHeader(
                    icon: Icons.info_outline_rounded,
                    title: 'Información del Dispositivo',
                  ),
                  DeviceInfoCard(info: info, mac: widget.mac),
                ],
                const SizedBox(height: 8),
                const SectionHeader(
                  icon: Icons.tune_rounded,
                  title: 'Configuración',
                ),
                SettingsCard(
                  info: info,
                  onChangePassword: () => _showPasswordDialog(context),
                  onResetDevice: () => _showResetDialog(context),
                ),
                const SizedBox(height: 8),
                _PermissionsButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    BleButtonConnected state,
    DeviceInfo? info,
  ) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon:
            const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1E293B)),
        onPressed: () {
          context.read<BleButtonBloc>().add(const DeviceDisconnectRequested());
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (info?.deviceName.isNotEmpty == true)
                ? info!.deviceName
                : 'MK Button',
            style: const TextStyle(
              color: Color.fromARGB(255, 93, 93, 93),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          Text(
            widget.mac,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4ADE80).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
              SizedBox(width: 6),
              Text(
                'Conectado',
                style: TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPasswordDialog(BuildContext context) {
    showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const PasswordDialog(),
    ).then((value) {
      if (value != null && context.mounted) {
        context.read<BleButtonBloc>().add(PasswordUpdateRequested(
              oldPassword: value['old']!,
              newPassword: value['new']!,
            ));
      }
    });
  }

  void _showResetDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (_) => const ResetConfirmDialog(),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        context.read<BleButtonBloc>().add(const DeviceResetRequested());
      }
    });
  }
}

/// Generic text input dialog used for device name editing
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.hint,
    this.initialValue = '',
    this.maxLength = 100,
  });

  final String title;
  final String hint;
  final String initialValue;
  final int maxLength;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: const TextStyle(
            color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        maxLength: widget.maxLength,
        style: const TextStyle(color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          filled: true,
          fillColor: const Color(0xFFF0F2FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          counterStyle: const TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0EA5E9),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Botón para ir a la pantalla de permisos
class _PermissionsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PermissionsPage(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFFFBBF24),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configurar Permisos',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Necesarios para abrir la app en segundo plano',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFB0BEC5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
