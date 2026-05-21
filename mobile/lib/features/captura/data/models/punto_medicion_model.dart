import '../../domain/entities/nivel_senal.dart';
import '../../domain/entities/punto_medicion.dart';
import 'medicion_wifi_model.dart';

class PuntoMedicionModel extends PuntoMedicion {
  const PuntoMedicionModel({
    required super.id,
    required super.planoId,
    required super.posX,
    required super.posY,
    required super.nivel,
    super.mediciones,
  });

  factory PuntoMedicionModel.fromJson(Map<String, dynamic> json) {
    final medicionesJson = json['mediciones'] as List<dynamic>?;
    return PuntoMedicionModel(
      id: json['id'] as int,
      planoId: json['plano_id'] as int,
      posX: (json['pos_x'] as num).toDouble(),
      posY: (json['pos_y'] as num).toDouble(),
      nivel: NivelSenal.fromString(json['nivel'] as String),
      mediciones: medicionesJson
              ?.map(
                  (e) => MedicionWifiModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
