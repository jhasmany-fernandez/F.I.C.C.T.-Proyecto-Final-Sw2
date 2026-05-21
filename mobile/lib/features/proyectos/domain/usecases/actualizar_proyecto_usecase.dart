import '../entities/proyecto.dart';
import '../repositories/proyecto_repository.dart';

/// Caso de uso: actualizar nombre, cliente y/o descripción de un proyecto.
/// HU PB-01 — Sp-12
class ActualizarProyectoUseCase {
  final ProyectoRepository _repository;

  const ActualizarProyectoUseCase(this._repository);

  Future<Proyecto> call({
    required int id,
    required String nombre,
    int? clienteId,
    String? descripcion,
  }) {
    return _repository.actualizar(
      id: id,
      nombre: nombre,
      clienteId: clienteId,
      descripcion: descripcion,
    );
  }
}
