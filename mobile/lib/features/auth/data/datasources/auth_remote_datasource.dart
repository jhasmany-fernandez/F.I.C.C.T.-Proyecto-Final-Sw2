import 'package:dio/dio.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/login_response_model.dart';

/// Datasource remoto de autenticación. Consume los endpoints /auth/*.
/// Modalidad 100 % en línea — PB-09 / Sprint 1 (Sp1-14, Sp1-17)
class AuthRemoteDatasource {
  final Dio _dio;

  const AuthRemoteDatasource(this._dio);

  /// Envía credenciales al backend y retorna tokens + perfil del usuario.
  /// Lanza [CredencialesInvalidasException] en respuesta 401.
  /// Lanza [CuentaDesactivadaException] en respuesta 403.
  /// Lanza [DioException] para errores de red o del servidor.
  Future<LoginResponseModel> login(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return LoginResponseModel.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const CredencialesInvalidasException();
      }
      if (e.response?.statusCode == 403) {
        throw const CuentaDesactivadaException();
      }
      rethrow;
    }
  }

  /// Solicita un nuevo access token usando el [refreshToken].
  /// Retorna el nuevo access token.
  /// Lanza [DioException] con 401 si el refresh token es inválido o expiró.
  Future<String> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return response.data!['access_token'] as String;
  }

  /// Revoca el [refreshToken] en el backend (logout).
  /// Si el backend retorna error, se ignora para no bloquear el flujo local.
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>(
        '/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    } on DioException {
      // Logout idempotente: ignorar errores de red/token inválido
    }
  }
}
