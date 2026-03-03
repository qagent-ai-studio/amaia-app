import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/ble_button_bloc.dart';
import '../domain/models.dart';
import 'widgets/adv_interval_dialog.dart';
import 'widgets/battery_card.dart';
import 'widgets/button_press_card.dart';
import 'widgets/device_info_card.dart';
import 'widgets/password_dialog.dart';
import 'widgets/reset_confirm_dialog.dart';
import 'widgets/section_header.dart';
import 'widgets/settings_card.dart';
import 'widgets/tx_power_dialog.dart';

/// Main page shown when connected to an MK Button device.
/// Displays device info, battery, button events, and all configurable settings.
class DevicePage extends StatefulWidget {
  const DevicePage({super.key, required this.mac});

  final String mac;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  bool _notifyEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleButtonBloc>().add(const DeviceInfoReadRequested());
    });
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
          context.read<BleButtonBloc>().add(const DeviceInfoReadRequested());
        }
      },
      builder: (context, state) {
        if (state is! BleButtonConnected) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final info = state.deviceInfo;
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: _buildAppBar(context, state, info),
          body: RefreshIndicator(
            color: const Color(0xFF38BDF8),
            backgroundColor: const Color(0xFF1E293B),
            onRefresh: () async {
              context
                  .read<BleButtonBloc>()
                  .add(const DeviceInfoReadRequested());
              await Future<void>.delayed(const Duration(seconds: 1));
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (state.isLoading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Color(0xFF1E293B),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                  ),

                // Button press events
                const SizedBox(height: 16),
                const SectionHeader(
                  icon: Icons.touch_app_rounded,
                  title: 'Estado del Botón',
                ),
                ButtonPressCard(
                  lastPress: state.lastButtonPress,
                  notifyEnabled: _notifyEnabled,
                  onToggleNotify: (val) {
                    setState(() => _notifyEnabled = val);
                    context
                        .read<BleButtonBloc>()
                        .add(ButtonNotifyToggled(enable: val));
                  },
                ),

                // Battery
                const SizedBox(height: 8),
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

                // Device Info
                if (info != null) ...[
                  const SizedBox(height: 8),
                  const SectionHeader(
                    icon: Icons.info_outline_rounded,
                    title: 'Información del Dispositivo',
                  ),
                  DeviceInfoCard(info: info, mac: widget.mac),
                ],

                // Settings
                const SizedBox(height: 8),
                const SectionHeader(
                  icon: Icons.tune_rounded,
                  title: 'Configuración',
                ),
                SettingsCard(
                  info: info,
                  onEditDeviceName: () => _showDeviceNameDialog(context, info),
                  onEditAdvInterval: () =>
                      _showAdvIntervalDialog(context, info),
                  onEditTxPower: () => _showTxPowerDialog(context, info),
                  onChangePassword: () => _showPasswordDialog(context),
                  onResetDevice: () => _showResetDialog(context),
                ),

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
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () {
          context.read<BleButtonBloc>().add(const DeviceDisconnectRequested());
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info?.deviceName ?? 'MK Button',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          Text(
            widget.mac,
            style: const TextStyle(
              color: Colors.white38,
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

  void _showDeviceNameDialog(BuildContext context, DeviceInfo? info) {
    showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: 'Nombre del dispositivo',
        initialValue: info?.deviceName ?? '',
        maxLength: 18,
        hint: 'Ingresa el nuevo nombre',
      ),
    ).then((value) {
      if (value != null && value.isNotEmpty && context.mounted) {
        context
            .read<BleButtonBloc>()
            .add(DeviceNameUpdateRequested(name: value));
      }
    });
  }

  void _showAdvIntervalDialog(BuildContext context, DeviceInfo? info) {
    showDialog<int>(
      context: context,
      builder: (_) => AdvIntervalDialog(
        currentIntervalMs: info?.advIntervalMs ?? 1000,
      ),
    ).then((value) {
      if (value != null && context.mounted) {
        context
            .read<BleButtonBloc>()
            .add(AdvIntervalUpdateRequested(intervalMs: value));
      }
    });
  }

  void _showTxPowerDialog(BuildContext context, DeviceInfo? info) {
    showDialog<int>(
      context: context,
      builder: (_) => TxPowerDialog(currentTxPower: info?.txPower ?? 0),
    ).then((value) {
      if (value != null && context.mounted) {
        context
            .read<BleButtonBloc>()
            .add(TxPowerUpdateRequested(txPower: value));
      }
    });
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
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        maxLength: widget.maxLength,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          counterStyle: const TextStyle(color: Colors.white38),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancelar', style: TextStyle(color: Colors.white54)),
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
