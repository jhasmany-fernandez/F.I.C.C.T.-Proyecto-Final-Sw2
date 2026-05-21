import 'package:equatable/equatable.dart';

import 'nivel_senal.dart';

/// Resultado de un BSSID individual en un escaneo WiFi.
class MedicionWifi extends Equatable {
  final int id;
  final int puntoId;
  final String ssid;
  final String bssid;
  final int rssi;
  final int? canal;
  final int? frecuenciaMhz;
  final NivelSenal nivel;
  final int numeroLectura;

  const MedicionWifi({
    required this.id,
    required this.puntoId,
    required this.ssid,
    required this.bssid,
    required this.rssi,
    this.canal,
    this.frecuenciaMhz,
    required this.nivel,
    this.numeroLectura = 1,
  });

  @override
  List<Object?> get props => [
        id,
        puntoId,
        ssid,
        bssid,
        rssi,
        canal,
        frecuenciaMhz,
        nivel,
        numeroLectura
      ];
}
