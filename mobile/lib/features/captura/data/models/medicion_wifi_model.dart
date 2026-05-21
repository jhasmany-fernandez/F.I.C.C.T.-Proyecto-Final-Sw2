import '../../domain/entities/medicion_wifi.dart';
import '../../domain/entities/nivel_senal.dart';

class MedicionWifiModel extends MedicionWifi {
  const MedicionWifiModel({
    required super.id,
    required super.puntoId,
    required super.ssid,
    required super.bssid,
    required super.rssi,
    super.canal,
    super.frecuenciaMhz,
    required super.nivel,
    super.numeroLectura = 1,
  });

  factory MedicionWifiModel.fromJson(Map<String, dynamic> json) {
    return MedicionWifiModel(
      id: json['id'] as int,
      puntoId: json['punto_id'] as int,
      ssid: json['ssid'] as String,
      bssid: json['bssid'] as String,
      rssi: json['rssi'] as int,
      canal: json['canal'] as int?,
      frecuenciaMhz: json['frecuencia_mhz'] as int?,
      nivel: NivelSenal.fromString(json['nivel'] as String),
      numeroLectura: json['numero_lectura'] as int? ?? 1,
    );
  }
}
