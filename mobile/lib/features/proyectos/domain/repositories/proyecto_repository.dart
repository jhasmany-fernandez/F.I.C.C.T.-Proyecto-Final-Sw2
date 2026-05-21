import '../entities/proyecto.dart';

/// Contrato del repositorio de proyectos de survey.
/// La capa data provee la implementación concreta.
/// HU PB-01 — Sp-11
abstract class ProyectoRepository {
  /// Retorna los proyectos activos (no archivados) del técnico.
  Future<List<Proyecto>> obtenerActivos();

  /// Retorna los proyectos archivados.
  Future<List<Proyecto>> obtenerArchivados();

  /// Crea un nuevo proyecto. El estado inicial es [EstadoProyecto.nuevo].
  /// Lanza [ProyectoNombreVacioException] si [nombre] está vacío.
  Future<Proyecto> crear({
    required String nombre,
    int? clienteId,
    String? descripcion,
  });

  /// Actualiza nombre, cliente y/o descripción de un proyecto existente.
  /// Lanza [ProyectoNombreVacioException] si [nombre] queda vacío.
  /// Lanza [ProyectoNoEncontradoException] si el id no existe.
  Future<Proyecto> actualizar({
    required int id,
    required String nombre,
    int? clienteId,
    String? descripcion,
  });

  /// Cambia el estado del proyecto a [EstadoProyecto.archivado].
  /// Lanza [ProyectoNoEncontradoException] si el id no existe.
  Future<void> archivar(int id);

  /// Elimina el proyecto y todos sus datos asociados (cascada).
  /// Lanza [ProyectoConReportesException] si el proyecto tiene reportes exportados.
  /// Lanza [ProyectoNoEncontradoException] si el id no existe.
  Future<void> eliminar(int id);
}

/// Excepción: nombre de proyecto vacío.
class ProyectoNombreVacioException implements Exception {
  const ProyectoNombreVacioException();

  @override
  String toString() => 'El nombre del proyecto no puede estar vacío';
}

/// Excepción: proyecto no encontrado en la base de datos.
class ProyectoNoEncontradoException implements Exception {
  final int id;
  const ProyectoNoEncontradoException(this.id);

  @override
  String toString() => 'No se encontró el proyecto con id $id';
}

/// Excepción: intento de eliminar un proyecto con reportes exportados (CA-5).
class ProyectoConReportesException implements Exception {
  const ProyectoConReportesException();

  @override
  String toString() =>
      'No es posible eliminar un proyecto con reportes exportados';
}

/// Excepción genérica de acceso a almacenamiento.
class ProyectoStorageException implements Exception {
  final String mensaje;
  const ProyectoStorageException(this.mensaje);

  @override
  String toString() => 'Error de almacenamiento: $mensaje';
}
