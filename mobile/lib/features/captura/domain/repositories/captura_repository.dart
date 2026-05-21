import '../entities/punto_medicion.dart';
import '../entities/resultado_escaneo.dart';

/// Contrato del repositorio de captura WiFi.
/// Sprint 3 — PB-03, PB-04.
abstract class CapturaRepository {
  /// Envía un lote de escaneos al backend y retorna el punto creado.
  /// Lanza [CapturaApiException] si el servidor rechaza la petición.
  Future<PuntoMedicion> enviarLote({
    required int planoId,
    required double posX,
    required double posY,
    required List<ResultadoEscaneo> escaneos,
  });

  /// Lista los puntos de medición de un plano.
  Future<List<PuntoMedicion>> listarPuntos(int planoId);

  /// Obtiene el detalle de un punto con todas sus mediciones.
  Future<PuntoMedicion> obtenerPunto(int puntoId);

  /// Agrega mediciones a un punto existente (modo continuo).
  /// El backend recalcula el nivel del punto.
  Future<PuntoMedicion> agregarMediciones({
    required int puntoId,
    required List<ResultadoEscaneo> escaneos,
  });

  /// Elimina un punto y sus mediciones en cascada.
  Future<void> eliminarPunto(int puntoId);
}

/// Excepción lanzada cuando el backend rechaza la petición.
class CapturaApiException implements Exception {
  final String mensaje;
  final int? statusCode;
  const CapturaApiException(this.mensaje, {this.statusCode});

  @override
  String toString() => 'CapturaApiException: $mensaje (HTTP $statusCode)';
}
