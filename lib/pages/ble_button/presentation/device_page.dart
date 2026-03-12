import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/ble_button_bloc.dart';
import '../data/ble_button_repository.dart';
import '../data/device_storage.dart';
import '../domain/models.dart';
import 'permissions_page.dart';
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
    // NOTE: NO llamamos a DeviceInfoReadRequested automáticamente porque
    // el MK Button NO tolera comandos adicionales después de la inicialización.
    // La información del dispositivo se lee durante la secuencia de init (0x2C).
    // El usuario puede hacer refresh manualmente si necesita actualizar datos.
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
          // NO llamar DeviceInfoReadRequested - el dispositivo no acepta comandos
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
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (state.isLoading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Color(0xFF1E293B),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
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
                onEditAdvInterval: () => _showAdvIntervalDialog(context, info),
                onEditTxPower: () => _showTxPowerDialog(context, info),
                onChangePassword: () => _showPasswordDialog(context),
                onResetDevice: () => _showResetDialog(context),
              ),

              // Configuración de apertura automática
              const SizedBox(height: 8),
              const SectionHeader(
                icon: Icons.launch_rounded,
                title: 'Apertura Automática',
              ),
              _AutoOpenConfigCard(mac: state.mac),

              // Botón de permisos
              const SizedBox(height: 8),
              _PermissionsButton(),

              const SizedBox(height: 16),
            ],
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

/// Widget para configurar la apertura automática de la app
class _AutoOpenConfigCard extends StatefulWidget {
  const _AutoOpenConfigCard({required this.mac});

  final String mac;

  @override
  State<_AutoOpenConfigCard> createState() => _AutoOpenConfigCardState();
}

class _AutoOpenConfigCardState extends State<_AutoOpenConfigCard> {
  String _selectedType = 'single';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    final device = await DeviceStorage.instance.getDeviceByMac(widget.mac);
    print('[AutoOpenConfig] Loading config for MAC: ${widget.mac}');
    print('[AutoOpenConfig] Device found: ${device != null}');
    if (device != null) {
      print('[AutoOpenConfig] clickToOpenApp: ${device.clickToOpenApp}');
    }
    if (device != null && mounted) {
      setState(() {
        _selectedType = device.clickToOpenApp;
        _isLoading = false;
      });
    } else if (mounted) {
      // Si no hay dispositivo, usar valor por defecto
      setState(() {
        _selectedType = 'single';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateConfiguration(String clickType) async {
    setState(() => _isLoading = true);

    try {
      await DeviceStorage.instance.updateClickToOpenApp(widget.mac, clickType);

      // Actualizar el servicio en segundo plano usando el repositorio del contexto
      final device = await DeviceStorage.instance.getDeviceByMac(widget.mac);
      if (device != null && mounted) {
        final repo = BleButtonRepositoryImpl();

        if (clickType == 'disabled') {
          // Detener servicio
          await repo.stopBackgroundService();
        } else {
          // Reiniciar servicio con nueva configuración
          await repo.stopBackgroundService();
          await Future.delayed(const Duration(
              milliseconds: 500)); // Delay para asegurar que se detuvo
          await repo.startBackgroundService(
            device.mac,
            device.password,
            clickType,
          );
        }
      }

      if (mounted) {
        setState(() {
          _selectedType = clickType;
          _isLoading = false;
        });

        // Mostrar confirmación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              clickType == 'disabled'
                  ? 'Apertura automática desactivada'
                  : 'Configurado para abrir con ${clickType == "single" ? "1 click" : "2 clicks"}',
            ),
            backgroundColor: const Color(0xFF0EA5E9),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar configuración: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Abrir app con botón BLE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configura qué tipo de presión del botón abrirá la app cuando esté cerrada',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  _buildOptionTile(
                    'single',
                    '1 Click',
                    'Abrir con una presión simple',
                    Icons.touch_app_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildOptionTile(
                    'double',
                    '2 Clicks',
                    'Abrir con doble presión',
                    Icons.touch_app_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildOptionTile(
                    'disabled',
                    'Desactivado',
                    'No abrir automáticamente',
                    Icons.block_rounded,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
      String type, String title, String subtitle, IconData icon) {
    final isSelected = _selectedType == type;

    return Material(
      color: isSelected
          ? const Color(0xFF0EA5E9).withOpacity(0.1)
          : const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _updateConfiguration(type),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? const Color(0xFF0EA5E9) : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF0EA5E9) : Colors.white54,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color:
                            isSelected ? const Color(0xFF0EA5E9) : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF0EA5E9),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
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
        color: const Color(0xFF1E293B),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Necesarios para abrir la app en segundo plano',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white24,
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
