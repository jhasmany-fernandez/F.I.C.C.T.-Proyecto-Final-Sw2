import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/repositories/plano_repository.dart';
import '../models/plano_model.dart';

/// Datasource remoto del feature Planos. Consume la API REST del backend.
/// HU PB-02 (importar) y PB-11 (calibrar) — Sprint 2.
class PlanoRemoteDatasource {
  final Dio _dio;

  /// Tamaño máximo permitido — PB-02 CA-3.
  static const int kMaxBytes = 20 * 1024 * 1024;

  /// Extensiones aceptadas — PB-02 CA-2.
  static const Set<String> kFormatosPermitidos = {'png', 'jpg', 'jpeg', 'pdf'};

  const PlanoRemoteDatasource(this._dio);

  /// Lista los planos de un proyecto.
  Future<List<PlanoModel>> listar(int proyectoId) async {
    final response = await _dio.get<List<dynamic>>(
      '/proyectos/$proyectoId/planos',
    );
    return (response.data ?? [])
        .map((e) => PlanoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Importa un plano. Valida tamaño y formato antes de enviar.
  Future<PlanoModel> importar({
    required int proyectoId,
    required String rutaArchivo,
    String? nombre,
  }) async {
    final file = File(rutaArchivo);
    if (!await file.exists()) {
      throw const PlanoStorageException('El archivo no existe.');
    }

    final tamano = await file.length();
    if (tamano > kMaxBytes) {
      throw PlanoArchivoMuyGrandeException(tamano);
    }

    final ext = _extension(rutaArchivo);
    if (!kFormatosPermitidos.contains(ext)) {
      throw PlanoFormatoNoSoportadoException(ext);
    }

    final filename = _basename(rutaArchivo);
    final formData = FormData.fromMap({
      if (nombre != null && nombre.isNotEmpty) 'nombre': nombre,
      'archivo': await MultipartFile.fromFile(
        rutaArchivo,
        filename: filename,
      ),
    });

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/proyectos/$proyectoId/planos',
        data: formData,
      );
      return PlanoModel.fromJson(response.data!);
    } on DioException catch (e) {
      _mapearError(e);
      rethrow;
    }
  }

  /// Renueva la URL firmada (cuando expiró). Devuelve sólo la URL.
  Future<String> renovarUrlFirmada(int planoId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/planos/$planoId/url-firmada',
    );
    return response.data!['url_firmada'] as String;
  }

  /// Calibra la escala del plano (PB-11 CA-2).
  Future<PlanoModel> calibrar({
    required int planoId,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required double distanciaRealM,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/planos/$planoId/calibracion',
        data: {
          'x1': x1,
          'y1': y1,
          'x2': x2,
          'y2': y2,
          'distancia_real_m': distanciaRealM,
        },
      );
      return PlanoModel.fromJson(response.data!);
    } on DioException catch (e) {
      _mapearError(e, planoId: planoId);
      rethrow;
    }
  }

  /// Elimina un plano.
  Future<void> eliminar(int planoId) async {
    try {
      await _dio.delete<void>('/planos/$planoId');
    } on DioException catch (e) {
      _mapearError(e, planoId: planoId);
      rethrow;
    }
  }

  /// Traduce errores HTTP a excepciones de dominio.
  void _mapearError(DioException e, {int? planoId}) {
    final status = e.response?.statusCode;
    final detail = e.response?.data is Map
        ? (e.response!.data['detail']?.toString() ?? '')
        : '';

    if (status == 404 && planoId != null) {
      throw PlanoNoEncontradoException(planoId);
    }
    if (status == 413) {
      throw PlanoArchivoMuyGrandeException(0);
    }
    if (status == 415) {
      throw PlanoFormatoNoSoportadoException(detail);
    }
    if (status == 409 && detail.toLowerCase().contains('punto')) {
      throw const PlanoRecalibracionBloqueadaException();
    }
    if (status == 422) {
      if (detail.toLowerCase().contains('distancia')) {
        throw const PlanoDistanciaInvalidaException();
      }
      if (detail.toLowerCase().contains('punto')) {
        throw const PlanoPuntosInvalidosException();
      }
    }
  }

  /// Devuelve la extensión sin punto y en minúsculas (vacío si no tiene).
  static String _extension(String ruta) {
    final base = _basename(ruta);
    final i = base.lastIndexOf('.');
    if (i < 0 || i == base.length - 1) return '';
    return base.substring(i + 1).toLowerCase();
  }

  /// Devuelve el nombre del archivo (sin path).
  static String _basename(String ruta) {
    final i = ruta.lastIndexOf(RegExp(r'[\\/]'));
    return i < 0 ? ruta : ruta.substring(i + 1);
  }
}
