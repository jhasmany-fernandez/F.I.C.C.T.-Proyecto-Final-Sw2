import 'package:wifi_scan/wifi_scan.dart';

import '../../features/captura/domain/entities/resultado_escaneo.dart';

/// Wrapper sobre el plugin ``wifi_scan`` para Android.
///
/// Encapsula:
///   - Solicitud de permiso ACCESS_FINE_LOCATION.
///   - Disparo de un escaneo y lectura de resultados.
///   - Conversión a [ResultadoEscaneo] del domain.
///
/// Sprint 3 — PB-03 (Sp3-08). Throttling Android ≥ 8.0: la plataforma
/// limita a 4 scans / 2 min en background; en foreground el límite
/// no aplica mientras el usuario esté activo.
class WifiScanner {
  const WifiScanner();

  /// Verifica si el escaneo WiFi está disponible y si tenemos el permiso.
  /// Retorna `true` si todo está listo para llamar a [escanear].
  Future<bool> disponible() async {
    final canStart = await WiFiScan.instance.canStartScan(askPermissions: true);
    return canStart == CanStartScan.yes;
  }

  /// Dispara un escaneo WiFi y devuelve los resultados como [ResultadoEscaneo].
  ///
  /// Lanza [WifiScanException] si no se tiene permiso o si el escaneo falla.
  Future<List<ResultadoEscaneo>> escanear() async {
    final canStart = await WiFiScan.instance.canStartScan(askPermissions: true);
    if (canStart != CanStartScan.yes) {
      throw WifiScanException(
        'No se puede iniciar el escaneo WiFi: $canStart. '
        'Verifica que se otorgó el permiso ACCESS_FINE_LOCATION.',
      );
    }

    final started = await WiFiScan.instance.startScan();
    if (!started) {
      throw const WifiScanException('El escaneo WiFi no pudo iniciarse.');
    }

    final canGet =
        await WiFiScan.instance.canGetScannedResults(askPermissions: true);
    if (canGet != CanGetScannedResults.yes) {
      throw WifiScanException(
        'No se pueden leer los resultados del escaneo: $canGet.',
      );
    }

    final results = await WiFiScan.instance.getScannedResults();
    return results
        .map(
          (r) => ResultadoEscaneo(
            ssid: r.ssid,
            bssid: r.bssid,
            rssi: r.level,
            canal: _frecuenciaACanal(r.frequency),
            frecuenciaMhz: r.frequency > 0 ? r.frequency : null,
          ),
        )
        .toList();
  }

  /// Convierte frecuencia en MHz al canal WiFi correspondiente.
  static int? _frecuenciaACanal(int frecuenciaMhz) {
    if (frecuenciaMhz <= 0) return null;
    // Banda 2.4 GHz (canales 1-14)
    if (frecuenciaMhz >= 2412 && frecuenciaMhz <= 2484) {
      if (frecuenciaMhz == 2484) return 14;
      return (frecuenciaMhz - 2407) ~/ 5;
    }
    // Banda 5 GHz (canales 36-165)
    if (frecuenciaMhz >= 5170 && frecuenciaMhz <= 5825) {
      return (frecuenciaMhz - 5000) ~/ 5;
    }
    // Banda 6 GHz
    if (frecuenciaMhz >= 5955 && frecuenciaMhz <= 7115) {
      return (frecuenciaMhz - 5950) ~/ 5;
    }
    return null;
  }
}

/// Excepción de escaneo WiFi (permiso denegado o fallo del sistema).
class WifiScanException implements Exception {
  final String mensaje;
  const WifiScanException(this.mensaje);

  @override
  String toString() => 'WifiScanException: $mensaje';
}
