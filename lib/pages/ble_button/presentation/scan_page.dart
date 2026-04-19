import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ble_button_bloc.dart';
import '../data/device_storage.dart';
import '../domain/models.dart';
import '../domain/saved_device.dart';
import 'device_page.dart';

/// Screen that scans for MK Button BLE devices and lists them.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  List<SavedDevice> _savedDevices = [];

  @override
  void initState() {
    super.initState();
    _loadSavedDevices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleButtonBloc>().add(const AutoReconnectRequested());
    });
  }

  Future<void> _loadSavedDevices() async {
    final devices = await DeviceStorage.instance.getAllDevices();
    if (mounted) setState(() => _savedDevices = devices);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'MK Button BLE',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          BlocBuilder<BleButtonBloc, BleButtonState>(
            builder: (context, state) {
              final isActivelyScan = state is BleButtonScanning &&
                  state.savedDevices.isEmpty;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: isActivelyScan
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF6951C1),
                          ),
                        )
                      : const Icon(Icons.radar_rounded,
                          color: Color(0xFF6951C1)),
                  onPressed: () => isActivelyScan
                      ? context.read<BleButtonBloc>().add(const ScanStopped())
                      : context.read<BleButtonBloc>().add(const ScanStarted()),
                  tooltip: isActivelyScan ? 'Detener escaneo' : 'Iniciar escaneo',
                ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<BleButtonBloc, BleButtonState>(
        listenWhen: (previous, current) =>
            current is BleButtonConnected && previous is! BleButtonConnected,
        listener: (context, state) {
          if (state is BleButtonConnected && state.mac.isNotEmpty) {
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) => BlocProvider.value(
                  value: context.read<BleButtonBloc>(),
                  child: DevicePage(mac: state.mac),
                ),
              ),
            );
          }
          if (state is BleButtonDisconnected) {
            _loadSavedDevices();
          }
          if (state is BleButtonError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is BleButtonInitial) {
            return const SizedBox.shrink();
          }
          if (state is BleButtonDisconnected) {
            if (_savedDevices.isNotEmpty) {
              return _DeviceList(
                savedDevices: _savedDevices,
                scannedDevices: const [],
              );
            }
            return _EmptyState(
              onScan: () =>
                  context.read<BleButtonBloc>().add(const ScanStarted()),
            );
          }
          if (state is BleButtonScanning) {
            // Mostrar dispositivos guardados y escaneados
            return _DeviceList(
              savedDevices: state.savedDevices,
              scannedDevices: state.devices,
            );
          }
          if (state is BleButtonConnecting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6951C1)),
                  const SizedBox(height: 16),
                  Text(
                    'Conectando a ${state.mac}...',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: BlocBuilder<BleButtonBloc, BleButtonState>(
        builder: (context, state) {
          final isActivelyScan = state is BleButtonScanning &&
              state.savedDevices.isEmpty;
          return FloatingActionButton.extended(
            onPressed: () => isActivelyScan
                ? context.read<BleButtonBloc>().add(const ScanStopped())
                : context.read<BleButtonBloc>().add(const ScanStarted()),
            backgroundColor: isActivelyScan
                ? Colors.red.shade700
                : const Color(0xFF0EA5E9),
            foregroundColor: Colors.white,
            icon: Icon(
                isActivelyScan ? Icons.stop_rounded : Icons.search_rounded),
            label: Text(isActivelyScan ? 'Detener' : 'Escanear'),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEBFA),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Icon(
              Icons.bluetooth_rounded,
              size: 64,
              color: Color(0xFF6951C1),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Buscar dispositivos',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Presiona Escanear para encontrar\ndispositivos MK Button cercanos',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SearchingIndicator extends StatelessWidget {
  const _SearchingIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              color: Color(0xFF6951C1),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Buscando dispositivos...',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.savedDevices,
    required this.scannedDevices,
  });

  final List<SavedDevice> savedDevices;
  final List<ScannedDevice> scannedDevices;

  @override
  Widget build(BuildContext context) {
    // Si no hay dispositivos guardados ni escaneados, mostrar indicador de búsqueda
    if (savedDevices.isEmpty && scannedDevices.isEmpty) {
      return const _SearchingIndicator();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sección de dispositivos guardados
        if (savedDevices.isNotEmpty) ...[
          const _SectionTitle(title: 'Mis Dispositivos'),
          const SizedBox(height: 8),
          ...savedDevices.map((device) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SavedDeviceTile(device: device),
              )),
          const SizedBox(height: 16),
        ],

        // Sección de dispositivos escaneados
        if (scannedDevices.isNotEmpty) ...[
          const _SectionTitle(title: 'Dispositivos Cercanos'),
          const SizedBox(height: 8),
          ...scannedDevices.map((device) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ScannedDeviceTile(device: device),
              )),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF6951C1),
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

// Widget para dispositivos guardados (con opción de eliminar)
class _SavedDeviceTile extends StatelessWidget {
  const _SavedDeviceTile({required this.device});

  final SavedDevice device;

  void _connectToDevice(BuildContext context) {
    context.read<BleButtonBloc>().add(DeviceConnectRequested(
          mac: device.mac,
          password: device.password,
        ));
  }

  void _deleteDevice(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Eliminar dispositivo?',
          style:
              TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
        ),
        content: Text(
          '¿Deseas eliminar "${device.name}" de tus dispositivos guardados?',
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
              context
                  .read<BleButtonBloc>()
                  .add(SavedDeviceDeleteRequested(mac: device.mac));
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(
                color: Color.fromARGB(255, 255, 255, 255),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _connectToDevice(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEBFA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bluetooth_connected_rounded,
                  color: Color(0xFF4ADE80),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      device.mac,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (device.lastConnectedAt != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Última conexión: ${_formatDate(device.lastConnectedAt!)}',
                        style: const TextStyle(
                          color: Color(0xFFB0BEC5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 20),
                onPressed: () => _deleteDevice(context),
                tooltip: 'Eliminar dispositivo',
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB0BEC5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Widget para dispositivos escaneados (dispositivos cercanos)
class _ScannedDeviceTile extends StatelessWidget {
  const _ScannedDeviceTile({required this.device});

  final ScannedDevice device;

  Color _rssiColor(int rssi) {
    if (rssi > -60) return const Color(0xFF4ADE80);
    if (rssi > -80) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  /// Muestra el diálogo de contraseña.
  /// El BLoC se captura aquí — dentro del árbol de widgets — antes de abrir
  /// el diálogo, así no hay problema de contexto desactivado.
  void _showPasswordPrompt(BuildContext context) {
    // Capturar el bloc ANTES de abrir el diálogo
    final bloc = context.read<BleButtonBloc>();
    final controller = TextEditingController(text: 'Moko4321');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: bloc,
          child: BlocListener<BleButtonBloc, BleButtonState>(
            listener: (_, state) {
              // Cerrar el diálogo en cuanto empiece a conectar
              if (state is BleButtonConnecting || state is BleButtonConnected) {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
              }
            },
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Contraseña del dispositivo',
                style: TextStyle(
                    color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
              ),
              content: TextField(
                controller: controller,
                style: const TextStyle(color: Color(0xFF1E293B)),
                //obscureText: true,
                autofocus: true,
                // decoration: InputDecoration(
                //   hintText: 'Dejar vacío si no tiene contraseña',
                //   hintStyle: const TextStyle(color: Colors.white38),
                //   filled: true,
                //   fillColor: const Color(0xFF0F172A),
                //   border: OutlineInputBorder(
                //     borderRadius: BorderRadius.circular(10),
                //     borderSide: BorderSide.none,
                //   ),
                // ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final password =
                        controller.text.isEmpty ? '123456' : controller.text;
                    bloc.add(DeviceConnectRequested(
                      mac: device.mac,
                      password: password,
                    ));
                  },
                  child: const Text('Conectar',
                      style:
                          TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPasswordPrompt(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEBFA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.devices_rounded,
                  color: Color(0xFF6951C1),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      device.mac,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${device.rssi} dBm',
                    style: TextStyle(
                      color: _rssiColor(device.rssi),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.signal_wifi_4_bar_rounded,
                    color: _rssiColor(device.rssi),
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB0BEC5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
