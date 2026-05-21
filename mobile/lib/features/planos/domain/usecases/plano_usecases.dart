import '../entities/plano.dart';
import '../repositories/plano_repository.dart';

/// Caso de uso: lista los planos de un proyecto.
class ListarPlanosUseCase {
  final PlanoRepository _repository;
  const ListarPlanosUseCase(this._repository);

  Future<List<Plano>> call(int proyectoId) => _repository.listar(proyectoId);
}

/// Caso de uso: importa un plano desde el dispositivo. PB-02.
class ImportarPlanoUseCase {
  final PlanoRepository _repository;
  const ImportarPlanoUseCase(this._repository);

  Future<Plano> call({
    required int proyectoId,
    required String rutaArchivo,
    String? nombre,
  }) {
    return _repository.importar(
      proyectoId: proyectoId,
      rutaArchivo: rutaArchivo,
      nombre: nombre,
    );
  }
}

/// Caso de uso: calibra la escala del plano. PB-11.
class CalibrarPlanoUseCase {
  final PlanoRepository _repository;
  const CalibrarPlanoUseCase(this._repository);

  Future<Plano> call({
    required int planoId,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required double distanciaRealM,
  }) {
    return _repository.calibrar(
      planoId: planoId,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      distanciaRealM: distanciaRealM,
    );
  }
}

/// Caso de uso: elimina un plano.
class EliminarPlanoUseCase {
  final PlanoRepository _repository;
  const EliminarPlanoUseCase(this._repository);

  Future<void> call(int planoId) => _repository.eliminar(planoId);
}

/// Caso de uso: renueva la URL firmada de descarga.
class RenovarUrlFirmadaUseCase {
  final PlanoRepository _repository;
  const RenovarUrlFirmadaUseCase(this._repository);

  Future<String> call(int planoId) => _repository.renovarUrlFirmada(planoId);
}
