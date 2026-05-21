import 'package:dio/dio.dart';
import '../models/proyecto_model.dart';
import '../../domain/repositories/proyecto_repository.dart';

/// Datasource remoto para la entidad Proyecto. Consume la API REST del backend.
/// Modalidad 100 % en línea — HU PB-01
class ProyectoRemoteDatasource {
  final Dio _dio;

  const ProyectoRemoteDatasource(this._dio);

  /// Retorna los proyectos activos del técnico autenticado.
  Future<List<ProyectoModel>> obtenerActivos() async {
    final response = await _dio.get<List<dynamic>>('/proyectos');
    return (response.data ?? [])
        .map((e) => ProyectoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Retorna los proyectos archivados del técnico autenticado.
  Future<List<ProyectoModel>> obtenerArchivados() async {
    final response =
        await _dio.get<List<dynamic>>('/proyectos', queryParameters: {
      'estado': 'ARCHIVADO',
    });
    return (response.data ?? [])
        .map((e) => ProyectoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Busca un proyecto por [id]. Lanza [ProyectoNoEncontradoException] en 404.
  Future<ProyectoModel> obtenerPorId(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/proyectos/$id');
      return ProyectoModel.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw ProyectoNoEncontradoException(id);
      }
      rethrow;
    }
  }

  /// Crea un proyecto nuevo en el backend.
  Future<ProyectoModel> crear({
    required String nombre,
    required int? clienteId,
    String? descripcion,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/proyectos',
      data: {
        'nombre': nombre,
        if (clienteId != null) 'cliente_id': clienteId,
        if (descripcion != null) 'descripcion': descripcion,
      },
    );
    return ProyectoModel.fromJson(response.data!);
  }

  /// Actualiza nombre, cliente y/o descripción de un proyecto.
  /// Lanza [ProyectoNoEncontradoException] en 404.
  Future<ProyectoModel> actualizar({
    required int id,
    required String nombre,
    required int? clienteId,
    String? descripcion,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/proyectos/$id',
        data: {
          'nombre': nombre,
          if (clienteId != null) 'cliente_id': clienteId,
          if (descripcion != null) 'descripcion': descripcion,
        },
      );
      return ProyectoModel.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw ProyectoNoEncontradoException(id);
      }
      rethrow;
    }
  }

  /// Archiva el proyecto. Lanza [ProyectoNoEncontradoException] en 404.
  Future<void> archivar(int id) async {
    try {
      await _dio.patch<void>('/proyectos/$id/archivar');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw ProyectoNoEncontradoException(id);
      }
      rethrow;
    }
  }

  /// Elimina el proyecto. Lanza [ProyectoConReportesException] en 409.
  /// Lanza [ProyectoNoEncontradoException] en 404.
  Future<void> eliminar(int id) async {
    try {
      await _dio.delete<void>('/proyectos/$id');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const ProyectoConReportesException();
      }
      if (e.response?.statusCode == 404) {
        throw ProyectoNoEncontradoException(id);
      }
      rethrow;
    }
  }
}
