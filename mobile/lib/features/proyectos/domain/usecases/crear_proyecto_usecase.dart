import '../entities/proyecto.dart';
import '../repositories/proyecto_repository.dart';

/// Caso de uso: crear un nuevo proyecto de survey.
/// Valida que el nombre no esté vacío (regla de negocio PB-01).
/// HU PB-01 — Sp-12
class CrearProyectoUseCase {
  final ProyectoRepository _repository;

  const CrearProyectoUseCase(this._repository);

  Future<Proyecto> call({
    required String nombre,
    int? clienteId,
    String? descripcion,
  }) {
    return _repository.crear(
      nombre: nombre,
      clienteId: clienteId,
      descripcion: descripcion,
    );
  }
}
