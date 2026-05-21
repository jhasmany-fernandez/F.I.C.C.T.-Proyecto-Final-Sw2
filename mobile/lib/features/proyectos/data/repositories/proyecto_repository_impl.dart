import 'package:dio/dio.dart';

import '../../domain/entities/proyecto.dart';
import '../../domain/repositories/proyecto_repository.dart';
import '../datasources/proyecto_remote_datasource.dart';

/// Implementación concreta del contrato [ProyectoRepository].
/// Orquesta [ProyectoRemoteDatasource] (API REST) y aplica las reglas de negocio.
/// Modalidad 100 % en línea — HU PB-01
class ProyectoRepositoryImpl implements ProyectoRepository {
  final ProyectoRemoteDatasource _remoteDatasource;

  const ProyectoRepositoryImpl(this._remoteDatasource);

  @override
  Future<List<Proyecto>> obtenerActivos() async {
    try {
      final models = await _remoteDatasource.obtenerActivos();
      return models.map((m) => m.toDomain()).toList();
    } catch (e) {
      throw ProyectoStorageException(e.toString());
    }
  }

  @override
  Future<List<Proyecto>> obtenerArchivados() async {
    try {
      final models = await _remoteDatasource.obtenerArchivados();
      return models.map((m) => m.toDomain()).toList();
    } catch (e) {
      throw ProyectoStorageException(e.toString());
    }
  }

  @override
  Future<Proyecto> crear({
    required String nombre,
    int? clienteId,
    String? descripcion,
  }) async {
    final nombreTrimmed = nombre.trim();
    if (nombreTrimmed.isEmpty) throw const ProyectoNombreVacioException();

    try {
      final model = await _remoteDatasource.crear(
        nombre: nombreTrimmed,
        clienteId: clienteId,
        descripcion: descripcion?.trim(),
      );
      return model.toDomain();
    } on ProyectoNombreVacioException {
      rethrow;
    } on DioException {
      rethrow;
    } catch (e) {
      throw ProyectoStorageException(e.toString());
    }
  }

  @override
  Future<Proyecto> actualizar({
    required int id,
    required String nombre,
    int? clienteId,
    String? descripcion,
  }) async {
    final nombreTrimmed = nombre.trim();
    if (nombreTrimmed.isEmpty) throw const ProyectoNombreVacioException();

    try {
      final model = await _remoteDatasource.actualizar(
        id: id,
        nombre: nombreTrimmed,
        clienteId: clienteId,
        descripcion: descripcion?.trim(),
      );
      return model.toDomain();
    } on ProyectoNombreVacioException {
      rethrow;
    } on ProyectoNoEncontradoException {
      rethrow;
    } on DioException {
      rethrow;
    } catch (e) {
      throw ProyectoStorageException(e.toString());
    }
  }

  @override
  Future<void> archivar(int id) async {
    try {
      await _remoteDatasource.archivar(id);
    } on ProyectoNoEncontradoException {
      rethrow;
    } on DioException {
      rethrow;
    } catch (e) {
      throw ProyectoStorageException(e.toString());
    }
  }

  @override
  Future<void> eliminar(int id) async {
    try {
      // CA-5: el backend retorna 409 si el proyecto tiene reportes exportados;
      // el datasource remoto lo mapea a ProyectoConReportesException.
      await _remoteDatasource.eliminar(id);
    } on ProyectoNoEncontradoException {
      rethrow;
    } on ProyectoConReportesException {
      rethrow;
    } catch (e) {
      throw ProyectoStorageException(e.toString());
    }
  }
}
