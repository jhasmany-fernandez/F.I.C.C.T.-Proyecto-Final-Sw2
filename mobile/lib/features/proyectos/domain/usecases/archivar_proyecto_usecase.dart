import '../repositories/proyecto_repository.dart';

/// Caso de uso: archivar un proyecto (cambia estado a ARCHIVADO).
/// CA-3 PB-01: el proyecto desaparece de la lista principal.
/// HU PB-01 — Sp-12
class ArchivarProyectoUseCase {
  final ProyectoRepository _repository;

  const ArchivarProyectoUseCase(this._repository);

  Future<void> call(int id) => _repository.archivar(id);
}
