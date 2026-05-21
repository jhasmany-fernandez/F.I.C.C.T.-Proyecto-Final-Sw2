import 'package:equatable/equatable.dart';

import '../../domain/entities/punto_medicion.dart';

/// Estados del ciclo de vida de una sesión de captura WiFi.
/// Sprint 3 — PB-03, PB-04 (Sp3-11).
sealed class CapturaState extends Equatable {
  const CapturaState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial: sesión no iniciada.
class CapturaInactiva extends CapturaState {
  const CapturaInactiva();
}

/// Cargando puntos previos del plano.
class CapturaLoading extends CapturaState {
  const CapturaLoading();
}

/// Sesión activa: técnico puede marcar puntos.
/// Lleva la lista de puntos ya persistidos en el plano.
class CapturaActiva extends CapturaState {
  final int planoId;
  final List<PuntoMedicion> puntos;
  final bool modosContinuo;
  final int intervaloSegundos;

  const CapturaActiva({
    required this.planoId,
    this.puntos = const [],
    this.modosContinuo = false,
    this.intervaloSegundos = 30,
  });

  CapturaActiva copyWith({
    List<PuntoMedicion>? puntos,
    bool? modosContinuo,
    int? intervaloSegundos,
  }) =>
      CapturaActiva(
        planoId: planoId,
        puntos: puntos ?? this.puntos,
        modosContinuo: modosContinuo ?? this.modosContinuo,
        intervaloSegundos: intervaloSegundos ?? this.intervaloSegundos,
      );

  @override
  List<Object?> get props =>
      [planoId, puntos, modosContinuo, intervaloSegundos];
}

/// Procesando un escaneo + envío al backend.
class CapturaEnviando extends CapturaState {
  final int planoId;
  final List<PuntoMedicion> puntos;

  const CapturaEnviando({required this.planoId, required this.puntos});

  @override
  List<Object?> get props => [planoId, puntos];
}

/// Throttling activo: se alcanzó el límite de 4 escaneos / 2 min.
class CapturaThrottling extends CapturaState {
  final int planoId;
  final List<PuntoMedicion> puntos;

  /// Segundos restantes hasta que se libere el siguiente slot.
  final int segundosRestantes;

  const CapturaThrottling({
    required this.planoId,
    required this.puntos,
    required this.segundosRestantes,
  });

  @override
  List<Object?> get props => [planoId, puntos, segundosRestantes];
}

/// Red caída: la app no puede enviar el lote.
class CapturaPausada extends CapturaState {
  final int planoId;
  final List<PuntoMedicion> puntos;

  const CapturaPausada({required this.planoId, required this.puntos});

  @override
  List<Object?> get props => [planoId, puntos];
}

/// Detalle de un punto abierto en el bottom sheet.
class CapturaPuntoDetalle extends CapturaState {
  final int planoId;
  final List<PuntoMedicion> puntos;
  final PuntoMedicion puntoSeleccionado;
  final bool modosContinuo;
  final int intervaloSegundos;

  const CapturaPuntoDetalle({
    required this.planoId,
    required this.puntos,
    required this.puntoSeleccionado,
    this.modosContinuo = false,
    this.intervaloSegundos = 30,
  });

  @override
  List<Object?> get props =>
      [planoId, puntos, puntoSeleccionado, modosContinuo, intervaloSegundos];
}

/// Error de operación (escaneo, envío o eliminación).
class CapturaError extends CapturaState {
  final int planoId;
  final List<PuntoMedicion> puntos;
  final String mensaje;

  const CapturaError({
    required this.planoId,
    required this.puntos,
    required this.mensaje,
  });

  @override
  List<Object?> get props => [planoId, puntos, mensaje];
}
