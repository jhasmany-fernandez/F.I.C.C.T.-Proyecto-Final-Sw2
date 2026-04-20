import 'dart:io';

import 'package:ficct_final_app/src/core/utils/frequency_channel.dart';
import 'package:ficct_final_app/src/data/models/wifi_reading.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

class WifiScanService {
  Future<WifiScanResponse> scan() async {
    return _scanReadings();
  }

  Future<WifiReading?> scanCurrentNetwork({
    required String ssid,
    String? bssid,
  }) async {
    final response = await _scanReadings();
    if (!response.isSuccess) {
      return null;
    }

    WifiReading? exactMatch;
    if (bssid != null && bssid.isNotEmpty) {
      for (final reading in response.readings) {
        if (reading.bssid.toLowerCase() == bssid.toLowerCase()) {
          exactMatch = reading;
          break;
        }
      }
    }

    if (exactMatch != null) {
      return exactMatch;
    }

    for (final reading in response.readings) {
      if (reading.ssid == ssid) {
        return reading;
      }
    }

    return null;
  }

  Future<WifiScanResponse> _scanReadings() async {
    if (!Platform.isAndroid) {
      return const WifiScanResponse.failure(
        'El escaneo WiFi real de este sprint esta implementado solo para Android.',
      );
    }

    final permissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ];

    final statuses = await permissions.request();
    final deniedPermissions = statuses.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => entry.key)
        .toList();

    if (deniedPermissions.isNotEmpty) {
      return const WifiScanResponse.failure(
        'La app necesita permisos de ubicacion y WiFi cercano para escanear redes.',
      );
    }

    final locationServiceEnabled =
        await Permission.locationWhenInUse.serviceStatus.isEnabled;
    if (!locationServiceEnabled) {
      return const WifiScanResponse.failure(
        'Activa la ubicacion del dispositivo para obtener resultados de escaneo WiFi.',
      );
    }

    final canStart = await WiFiScan.instance.canStartScan(
      askPermissions: false,
    );
    if (canStart == CanStartScan.notSupported) {
      return const WifiScanResponse.failure(
        'Este dispositivo no soporta el escaneo WiFi requerido por la app.',
      );
    }

    if (canStart == CanStartScan.yes) {
      await WiFiScan.instance.startScan();
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    final canGetResults = await WiFiScan.instance.canGetScannedResults(
      askPermissions: false,
    );
    if (canGetResults != CanGetScannedResults.yes) {
      return const WifiScanResponse.failure(
        'No fue posible leer los resultados del escaneo WiFi en este momento.',
      );
    }

    final accessPoints = await WiFiScan.instance.getScannedResults();
    if (accessPoints.isEmpty) {
      return const WifiScanResponse.failure(
        'No se detectaron redes WiFi visibles. Verifica que el WiFi del dispositivo este activo.',
      );
    }

    final capturedAt = DateTime.now();
    final readings =
        accessPoints
            .map(
              (accessPoint) => WifiReading(
                ssid: accessPoint.ssid,
                bssid: accessPoint.bssid,
                rssi: accessPoint.level,
                frequency: accessPoint.frequency,
                channel: wifiChannelFromFrequency(accessPoint.frequency),
                timestamp: capturedAt,
              ),
            )
            .toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return WifiScanResponse.success(readings);
  }
}

class WifiScanResponse {
  const WifiScanResponse._({
    required this.readings,
    required this.errorMessage,
  });

  const WifiScanResponse.success(List<WifiReading> readings)
    : this._(readings: readings, errorMessage: null);

  const WifiScanResponse.failure(String message)
    : this._(readings: const [], errorMessage: message);

  final List<WifiReading> readings;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}
