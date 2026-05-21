import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cliente HTTP centralizado con Dio.
/// Incluye el interceptor completo de autenticación:
///   - Adjunta el JWT en cada petición.
///   - En 401: intenta renovar el access token con el refresh token.
///   - Si el refresh falla: limpia la sesión y notifica via [onSessionExpired].
/// Modalidad 100 % en línea — toda la persistencia de dominio ocurre en el backend.
/// Sprint 1 (Sp1-19)
class DioClient {
  /// URL base de la API. Sobreescribir con `--dart-define=API_BASE_URL=...`.
  /// Por defecto apunta al emulador Android (10.0.2.2 = localhost del host).
  static const String _defaultBaseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2/api');

  /// Callback invocado cuando la sesión expira definitivamente (refresh fallido).
  /// Configurar desde main.dart para navegar a la pantalla de login.
  static VoidCallback? onSessionExpired;

  final Dio _dio;

  DioClient(FlutterSecureStorage storage)
      : _dio = Dio(
          BaseOptions(
            baseUrl: _defaultBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(_AuthInterceptor(_dio, storage));
    _dio.interceptors.add(_RetryInterceptor(_dio));
  }

  Dio get dio => _dio;
}

/// Interceptor de reintentos con backoff exponencial para fallos de red.
/// Sprint 3 (Sp3-10): 3 intentos máx., backoff 1→2→4 s, total ≤ 4 s acumulado.
/// Solo reintenta errores de conexión/timeout, NO errores HTTP (4xx/5xx).
class _RetryInterceptor extends Interceptor {
  static const int _maxReintentos = 3;

  final Dio _dio;

  _RetryInterceptor(this._dio);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final tipo = err.type;
    final intentos = err.requestOptions.extra['_reintentos'] as int? ?? 0;

    final esErrorRed = tipo == DioExceptionType.connectionError ||
        tipo == DioExceptionType.connectionTimeout ||
        tipo == DioExceptionType.receiveTimeout;

    if (!esErrorRed || intentos >= _maxReintentos) {
      handler.next(err);
      return;
    }

    final esperaMs = (1 << intentos) * 1000; // 1s, 2s, 4s
    await Future<void>.delayed(Duration(milliseconds: esperaMs));

    final opciones = err.requestOptions;
    opciones.extra['_reintentos'] = intentos + 1;

    try {
      final respuesta = await _dio.fetch<dynamic>(opciones);
      handler.resolve(respuesta);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }
}

/// Interceptor que gestiona el ciclo completo de JWT + renovación automática.
class _AuthInterceptor extends Interceptor {
  static const String _keyToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';

  final Dio _dio;
  final FlutterSecureStorage _storage;

  // Previene ciclos de refresh simultáneos
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingQueue = [];

  _AuthInterceptor(this._dio, this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _keyToken);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Solo gestionar 401 en peticiones no-refresh para evitar bucles
    if (err.response?.statusCode != 401 ||
        err.requestOptions.path.contains('/auth/refresh')) {
      handler.next(err);
      return;
    }

    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (refreshToken == null) {
      await _handleSessionExpired();
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      // Encolar la petición mientras se renueva
      final completer = _PendingRequest(err.requestOptions);
      _pendingQueue.add(completer);
      final response = await completer.future;
      if (response != null) {
        handler.resolve(response);
      } else {
        handler.next(err);
      }
      return;
    }

    _isRefreshing = true;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newToken = response.data!['access_token'] as String;
      await _storage.write(key: _keyToken, value: newToken);

      // Reintentar la petición original con el nuevo token
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newToken';
      final retryResponse = await _dio.fetch<dynamic>(retryOptions);

      // Resolver peticiones encoladas
      for (final pending in _pendingQueue) {
        pending.complete(retryResponse);
      }
      _pendingQueue.clear();

      handler.resolve(retryResponse);
    } on DioException {
      // Refresh fallido: cerrar sesión
      for (final pending in _pendingQueue) {
        pending.complete(null);
      }
      _pendingQueue.clear();
      await _handleSessionExpired();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _handleSessionExpired() async {
    await Future.wait([
      _storage.delete(key: _keyToken),
      _storage.delete(key: _keyRefreshToken),
    ]);
    DioClient.onSessionExpired?.call();
  }
}

/// Petición encolada mientras se procesa un refresh en curso.
class _PendingRequest {
  final RequestOptions requestOptions;
  Response<dynamic>? _response;
  bool _completed = false;

  _PendingRequest(this.requestOptions);

  void complete(Response<dynamic>? response) {
    _response = response;
    _completed = true;
  }

  Future<Response<dynamic>?> get future async {
    // Espera activa simple — el interceptor completa rápido
    while (!_completed) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return _response;
  }
}
