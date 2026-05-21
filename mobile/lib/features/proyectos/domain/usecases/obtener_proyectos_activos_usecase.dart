import '../entities/proyecto.dart';
import '../repositories/proyecto_repository.dart';

/// Caso de uso: obtener la lista de proyectos activos del técnico.
/// HU PB-01 — Sp-12
class ObtenerProyectosActivosUseCase {
  final ProyectoRepository _repository;

  const ObtenerProyectosActivosUseCase(this._repository);

  Future<List<Proyecto>> call() => _repository.obtenerActivos();
}
