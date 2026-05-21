import 'package:equatable/equatable.dart';

import 'medicion_wifi.dart';
import 'nivel_senal.dart';

/// Punto de medición sobre el plano.
/// Contiene su posición en píxeles y el nivel agregado (peor RSSI del lote).
class PuntoMedicion extends Equatable {
  final int id;
  final int planoId;
  final double posX;
  final double posY;
  final NivelSenal nivel;
  final List<MedicionWifi> mediciones;

  const PuntoMedicion({
    required this.id,
    required this.planoId,
    required this.posX,
    required this.posY,
    required this.nivel,
    this.mediciones = const [],
  });

  @override
  List<Object?> get props => [id, planoId, posX, posY, nivel, mediciones];
}
