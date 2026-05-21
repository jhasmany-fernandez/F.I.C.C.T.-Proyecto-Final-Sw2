import 'package:dio/dio.dart';

import '../../domain/entities/nivel_senal.dart';
import '../../domain/entities/punto_medicion.dart';
import '../../domain/entities/resultado_escaneo.dart';
import '../../domain/repositories/captura_repository.dart';
import '../models/punto_medicion_model.dart';

/// Datasource remoto de captura. Consume la API REST del backend.
/// Sprint 3 — PB-03 (POST /mediciones) y PB-04 (puntos).
class MedicionRemoteDatasource {
  final Dio _dio;

  const MedicionRemoteDatasource(this._dio);

  /// Envía un lote de mediciones al backend. POST /api/mediciones.
  Future<PuntoMedicion> enviarLote({
    required int planoId,
    required double posX,
    required double posY,
    required List<ResultadoEscaneo> escaneos,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/mediciones',
        data: {
          'plano_id': planoId,
          'pos_x': posX,
          'pos_y': posY,
          'mediciones': escaneos
              .map((e) => {
                    'ssid': e.ssid,
                    'bssid': e.bssid,
                    'rssi': e.rssi,
                    if (e.canal != null) 'canal': e.canal,
                    if (e.frecuenciaMhz != null)
                      'frecuencia_mhz': e.frecuenciaMhz,
                  })
              .toList(),
        },
      );
      final body = response.data!;
      return PuntoMedicionModel(
        id: body['punto_id'] as int,
        planoId: planoId,
        posX: posX,
        posY: posY,
        nivel: NivelSenal.fromString(body['nivel'] as String),
      );
    } on DioException catch (e) {
      throw CapturaApiException(
        _mensajeDesdeError(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Lista los puntos de medición de un plano. GET /api/planos/{id}/puntos.
  Future<List<PuntoMedicion>> listarPuntos(int planoId) async {
    try {
      final response = await _dio.get<List<dynamic>>('/planos/$planoId/puntos');
      return (response.data ?? [])
          .map((e) => PuntoMedicionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw CapturaApiException(
        _mensajeDesdeError(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Detalle de un punto. GET /api/puntos/{id}.
  Future<PuntoMedicion> obtenerPunto(int puntoId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/puntos/$puntoId');
      return PuntoMedicionModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw CapturaApiException(
        _mensajeDesdeError(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Agrega mediciones a un punto existente. POST /api/puntos/{id}/mediciones.
  Future<PuntoMedicion> agregarMediciones({
    required int puntoId,
    required List<ResultadoEscaneo> escaneos,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/puntos/$puntoId/mediciones',
        data: {
          'mediciones': escaneos
              .map((e) => {
                    'ssid': e.ssid,
                    'bssid': e.bssid,
                    'rssi': e.rssi,
                    if (e.canal != null) 'canal': e.canal,
                    if (e.frecuenciaMhz != null)
                      'frecuencia_mhz': e.frecuenciaMhz,
                  })
              .toList(),
        },
      );
      return PuntoMedicionModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw CapturaApiException(
        _mensajeDesdeError(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Elimina un punto. DELETE /api/puntos/{id}.
  Future<void> eliminarPunto(int puntoId) async {
    try {
      await _dio.delete<void>('/puntos/$puntoId');
    } on DioException catch (e) {
      throw CapturaApiException(
        _mensajeDesdeError(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  static String _mensajeDesdeError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 422) {
      final detail = e.response?.data?['detail'];
      if (detail is String) return detail;
      return 'Datos inválidos en la solicitud.';
    }
    if (status == 404) return 'Recurso no encontrado.';
    if (status == 401) return 'Sesión expirada.';
    return 'Error de red. Reintenta.';
  }
}
