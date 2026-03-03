import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ble_button_bloc.dart';
import '../domain/models.dart';
import 'device_page.dart';

/// Screen that scans for MK Button BLE devices and lists them.
class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'MK Button BLE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          BlocBuilder<BleButtonBloc, BleButtonState>(
            builder: (context, state) {
              final isScanning = state is BleButtonScanning;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF38BDF8),
                          ),
                        )
                      : const Icon(Icons.radar_rounded,
                          color: Color(0xFF38BDF8)),
                  onPressed: () => isScanning
                      ? context.read<BleButtonBloc>().add(const ScanStopped())
                      : context.read<BleButtonBloc>().add(const ScanStarted()),
                  tooltip: isScanning ? 'Detener escaneo' : 'Iniciar escaneo',
                ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<BleButtonBloc, BleButtonState>(
        listener: (context, state) {
          if (state is BleButtonConnected) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: context.read<BleButtonBloc>(),
                  child: DevicePage(mac: state.mac),
                ),
              ),
            );
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
          if (state is BleButtonInitial || state is BleButtonDisconnected) {
            return _EmptyState(
              onScan: () =>
                  context.read<BleButtonBloc>().add(const ScanStarted()),
            );
          }
          if (state is BleButtonScanning) {
            if (state.devices.isEmpty) {
              return const _SearchingIndicator();
            }
            return _DeviceList(devices: state.devices);
          }
          if (state is BleButtonConnecting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF38BDF8)),
                  const SizedBox(height: 16),
                  Text(
                    'Conectando a ${state.mac}...',
                    style: const TextStyle(color: Colors.white70),
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
          final isScanning = state is BleButtonScanning;
          return FloatingActionButton.extended(
            onPressed: () => isScanning
                ? context.read<BleButtonBloc>().add(const ScanStopped())
                : context.read<BleButtonBloc>().add(const ScanStarted()),
            backgroundColor:
                isScanning ? Colors.red.shade700 : const Color(0xFF0EA5E9),
            icon: Icon(isScanning ? Icons.stop_rounded : Icons.search_rounded),
            label: Text(isScanning ? 'Detener' : 'Escanear'),
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
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Icon(
              Icons.bluetooth_rounded,
              size: 64,
              color: Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Buscar dispositivos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Presiona Escanear para encontrar\ndispositivos MK Button cercanos',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
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
              color: Color(0xFF38BDF8),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Buscando dispositivos...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices});

  final List<ScannedDevice> devices;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _DeviceTile(device: devices[index]),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

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
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Contraseña del dispositivo',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              content: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
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
                      style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final password = controller.text.isEmpty
                        ? '123456'
                        : controller.text;
                    // Usar el bloc capturado antes del diálogo — seguro
                    bloc.add(DeviceConnectRequested(
                      mac: device.mac,
                      password: password,
                    ));
                    // El BlocListener cerrará el diálogo cuando el estado cambie
                  },
                  child: const Text('Conectar'),
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
      color: const Color(0xFF1E293B),
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
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.devices_rounded,
                  color: Color(0xFF38BDF8),
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
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      device.mac,
                      style: const TextStyle(
                        color: Colors.white38,
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
                color: Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}