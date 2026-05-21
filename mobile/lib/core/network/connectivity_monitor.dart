import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitor proactivo de conectividad de red.
/// Detecta cambios de conexión antes de que el usuario intente iniciar sesión.
/// Modalidad 100 % en línea — Sp1-20 / PB-09 / CA-5
class ConnectivityMonitor {
  final Connectivity _connectivity;

  const ConnectivityMonitor(this._connectivity);

  /// Stream que emite `true` cuando hay conexión disponible, `false` si no.
  /// Usado por [AuthCubit] para deshabilitar el login de forma proactiva.
  Stream<bool> get cambios => _connectivity.onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));

  /// Verificación inmediata del estado de conectividad.
  /// Retorna `true` si hay al menos una interfaz de red disponible.
  Future<bool> estaConectado() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
