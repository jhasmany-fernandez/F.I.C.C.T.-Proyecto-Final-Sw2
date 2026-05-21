import '../repositories/proyecto_repository.dart';

/// Caso de uso: eliminar un proyecto y todos sus datos asociados.
/// CA-4 y CA-5 PB-01: requiere confirmación previa en la UI; protege
/// proyectos con reportes exportados.
/// HU PB-01 — Sp-12
class EliminarProyectoUseCase {
  final ProyectoRepository _repository;

  const EliminarProyectoUseCase(this._repository);

  Future<void> call(int id) => _repository.eliminar(id);
}
