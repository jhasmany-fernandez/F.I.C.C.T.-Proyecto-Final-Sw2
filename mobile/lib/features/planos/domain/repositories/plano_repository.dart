import '../entities/plano.dart';

/// Contrato del repositorio de planos.
/// HU PB-02 (importar) y PB-11 (calibrar) — Sprint 2.
abstract class PlanoRepository {
  /// Lista los planos de un proyecto.
  Future<List<Plano>> listar(int proyectoId);

  /// Importa un plano desde un archivo local.
  /// [rutaArchivo] es la ruta absoluta en el filesystem del dispositivo.
  /// [nombre] es opcional; si es null se usa el nombre del archivo.
  Future<Plano> importar({
    required int proyectoId,
    required String rutaArchivo,
    String? nombre,
  });

  /// Renueva la URL firmada de descarga.
  Future<String> renovarUrlFirmada(int planoId);

  /// Calibra la escala del plano. PB-11 CA-2.
  Future<Plano> calibrar({
    required int planoId,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required double distanciaRealM,
  });

  /// Elimina el plano. Lanza [PlanoNoEncontradoException] en 404.
  Future<void> eliminar(int planoId);
}

/// Excepciones de dominio.

class PlanoNoEncontradoException implements Exception {
  final int id;
  const PlanoNoEncontradoException(this.id);
  @override
  String toString() => 'No se encontró el plano con id $id';
}

/// Tamaño máximo de archivo excedido (PB-02 CA-3 — 20 MB).
class PlanoArchivoMuyGrandeException implements Exception {
  final int tamanoBytes;
  const PlanoArchivoMuyGrandeException(this.tamanoBytes);
  @override
  String toString() =>
      'El archivo excede el tamaño máximo permitido (20 MB).';
}

/// Formato de archivo no soportado (PB-02 CA-2).
class PlanoFormatoNoSoportadoException implements Exception {
  final String extension;
  const PlanoFormatoNoSoportadoException(this.extension);
  @override
  String toString() =>
      'Formato no soportado ($extension). Use PNG, JPG o PDF.';
}

/// Distancia real fuera de rango (PB-11 CA-3 — debe ser ≥ 1 metro).
class PlanoDistanciaInvalidaException implements Exception {
  const PlanoDistanciaInvalidaException();
  @override
  String toString() =>
      'La distancia real debe ser mayor o igual a 1 metro.';
}

/// Puntos de calibración coincidentes o demasiado próximos (PB-11 CA-2).
class PlanoPuntosInvalidosException implements Exception {
  const PlanoPuntosInvalidosException();
  @override
  String toString() =>
      'Los puntos seleccionados deben ser distintos.';
}

/// Recalibración bloqueada porque ya existen puntos asociados (PB-11 CA-4).
class PlanoRecalibracionBloqueadaException implements Exception {
  const PlanoRecalibracionBloqueadaException();
  @override
  String toString() =>
      'No se puede recalibrar: el plano ya tiene puntos de medición.';
}

/// Error genérico de almacenamiento o red.
class PlanoStorageException implements Exception {
  final String mensaje;
  const PlanoStorageException(this.mensaje);
  @override
  String toString() => 'Error: $mensaje';
}
