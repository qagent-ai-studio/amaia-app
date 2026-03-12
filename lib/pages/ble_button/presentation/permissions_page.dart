import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pantalla para solicitar permisos necesarios para el servicio en segundo plano
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  static const platform = MethodChannel('com.example.app/mk_button');

  bool _isBatteryOptimizationDisabled = false;
  bool _hasNotificationPermission = false;
  bool _hasOverlayPermission = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);

    try {
      final results = await platform.invokeMethod<Map>('checkPermissions');
      if (results != null && mounted) {
        setState(() {
          _isBatteryOptimizationDisabled =
              results['batteryOptimizationDisabled'] as bool? ?? false;
          _hasNotificationPermission =
              results['notificationPermission'] as bool? ?? false;
          _hasOverlayPermission =
              results['overlayPermission'] as bool? ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestBatteryOptimization() async {
    try {
      await platform.invokeMethod('requestBatteryOptimization');
      await Future.delayed(const Duration(seconds: 1));
      _checkPermissions();
    } catch (e) {
      _showError('Error al solicitar permiso de batería');
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await platform.invokeMethod('requestNotificationPermission');
      await Future.delayed(const Duration(seconds: 1));
      _checkPermissions();
    } catch (e) {
      _showError('Error al solicitar permiso de notificaciones');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _requestOverlayPermission() async {
    try {
      await platform.invokeMethod('requestOverlayPermission');
      await Future.delayed(const Duration(seconds: 1));
      _checkPermissions();
    } catch (e) {
      _showError('Error al solicitar permiso de overlay');
    }
  }

  bool get _allPermissionsGranted =>
      _isBatteryOptimizationDisabled &&
      _hasNotificationPermission &&
      _hasOverlayPermission;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Permisos Requeridos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Explicación
                _buildInfoCard(),
                const SizedBox(height: 24),

                // Lista de permisos
                _buildPermissionTile(
                  icon: Icons.battery_charging_full_rounded,
                  title: 'Optimización de Batería',
                  description:
                      'Permite que el servicio funcione en segundo plano sin ser detenido',
                  isGranted: _isBatteryOptimizationDisabled,
                  onTap: _requestBatteryOptimization,
                ),
                const SizedBox(height: 12),
                _buildPermissionTile(
                  icon: Icons.notifications_rounded,
                  title: 'Notificaciones',
                  description:
                      'Muestra el estado de conexión del botón en la barra de notificaciones',
                  isGranted: _hasNotificationPermission,
                  onTap: _requestNotificationPermission,
                ),

                const SizedBox(height: 12),

                // Permiso de overlay (mostrar sobre otras apps)
                _buildPermissionTile(
                  icon: Icons.web_asset_rounded,
                  title: 'Mostrar sobre otras apps',
                  description:
                      'Permite mostrar una ventana flotante cuando se presiona el botón',
                  isGranted: _hasOverlayPermission,
                  onTap: _requestOverlayPermission,
                ),

                const SizedBox(height: 32),

                // Botón de continuar
                if (_allPermissionsGranted) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4ADE80),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4ADE80),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '¡Todos los permisos concedidos!\nEl servicio funcionará correctamente.',
                            style: const TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF0EA5E9),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  '¿Por qué son necesarios?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Para que el botón BLE pueda abrir la app cuando está cerrada, necesitamos estos permisos especiales de Android.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isGranted
          ? const Color(0xFF4ADE80).withOpacity(0.1)
          : const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isGranted ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
              color: isGranted ? const Color(0xFF4ADE80) : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isGranted
                      ? const Color(0xFF4ADE80).withOpacity(0.2)
                      : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isGranted ? const Color(0xFF4ADE80) : Colors.white54,
                  size: 24,
                ),
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
                            isGranted ? const Color(0xFF4ADE80) : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isGranted
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: isGranted ? const Color(0xFF4ADE80) : Colors.white38,
                size: isGranted ? 28 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
