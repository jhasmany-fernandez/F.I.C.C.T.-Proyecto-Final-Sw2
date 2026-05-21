import '../../domain/entities/plano.dart';
import '../../domain/repositories/plano_repository.dart';
import '../datasources/plano_remote_datasource.dart';

/// Implementación del repositorio de planos. Modalidad 100 % en línea.
/// HU PB-02 / PB-11 — Sprint 2.
class PlanoRepositoryImpl implements PlanoRepository {
  final PlanoRemoteDatasource _remote;

  const PlanoRepositoryImpl(this._remote);

  @override
  Future<List<Plano>> listar(int proyectoId) {
    return _remote.listar(proyectoId);
  }

  @override
  Future<Plano> importar({
    required int proyectoId,
    required String rutaArchivo,
    String? nombre,
  }) {
    return _remote.importar(
      proyectoId: proyectoId,
      rutaArchivo: rutaArchivo,
      nombre: nombre,
    );
  }

  @override
  Future<String> renovarUrlFirmada(int planoId) {
    return _remote.renovarUrlFirmada(planoId);
  }

  @override
  Future<Plano> calibrar({
    required int planoId,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required double distanciaRealM,
  }) {
    if (distanciaRealM < 1) {
      throw const PlanoDistanciaInvalidaException();
    }
    if (x1 == x2 && y1 == y2) {
      throw const PlanoPuntosInvalidosException();
    }
    return _remote.calibrar(
      planoId: planoId,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      distanciaRealM: distanciaRealM,
    );
  }

  @override
  Future<void> eliminar(int planoId) {
    return _remote.eliminar(planoId);
  }
}
