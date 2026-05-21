import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/get_usuario_activo_usecase.dart';
import '../../../../core/network/connectivity_monitor.dart';
import 'auth_state.dart';

/// Cubit de autenticación. Gestiona el ciclo de vida de la sesión.
/// Sp-04 — PB-09 / Sprint 1 (Sp1-20, Sp1-21)
class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetUsuarioActivoUseCase _getUsuarioActivoUseCase;
  final ConnectivityMonitor _connectivityMonitor;

  StreamSubscription<bool>? _conectividadSub;

  AuthCubit({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetUsuarioActivoUseCase getUsuarioActivoUseCase,
    required ConnectivityMonitor connectivityMonitor,
  })  : _loginUseCase = loginUseCase,
        _logoutUseCase = logoutUseCase,
        _getUsuarioActivoUseCase = getUsuarioActivoUseCase,
        _connectivityMonitor = connectivityMonitor,
        super(const AuthInitial());

  /// Verifica al iniciar la app si ya existe una sesión persistida (CA-3).
  /// Si no hay sesión, inicia el monitoreo proactivo de conectividad (Sp1-20).
  Future<void> checkSesionActiva() async {
    emit(const AuthLoading());
    final usuario = await _getUsuarioActivoUseCase();
    if (usuario != null) {
      emit(AuthAuthenticated(usuario));
    } else {
      final conectado = await _connectivityMonitor.estaConectado();
      emit(conectado ? const AuthUnauthenticated() : const AuthSinConexion());
      _iniciarMonitoreoConectividad();
    }
  }

  /// Inicia el monitoreo proactivo de red (Sp1-20 / CA-5).
  /// Deshabilita el botón de login antes de que el usuario intente enviar el formulario.
  void _iniciarMonitoreoConectividad() {
    _conectividadSub?.cancel();
    _conectividadSub = _connectivityMonitor.cambios.listen((conectado) {
      if (!conectado &&
          (state is AuthUnauthenticated || state is AuthSinConexion)) {
        emit(const AuthSinConexion());
      } else if (conectado && state is AuthSinConexion) {
        emit(const AuthUnauthenticated());
      }
    });
  }

  /// Autentica al usuario con [email] y [password].
  /// CA-1: navega a proyectos en éxito.
  /// CA-2: error genérico en fallo de credenciales.
  /// CA-5 (Sp1-20): verifica conectividad antes de intentar el login; si no hay
  ///   red emite [AuthSinConexion] sin llamar al backend.
  Future<void> login(String email, String password) async {
    final conectado = await _connectivityMonitor.estaConectado();
    if (!conectado) {
      emit(const AuthSinConexion());
      return;
    }
    emit(const AuthLoading());
    try {
      final usuario = await _loginUseCase(email, password);
      emit(AuthAuthenticated(usuario));
    } on CredencialesInvalidasException {
      emit(const AuthError('Credenciales inválidas'));
    } on CuentaDesactivadaException {
      emit(const AuthError('Cuenta desactivada. Contacte al administrador.'));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        emit(const AuthSinConexion());
      } else {
        emit(const AuthError('Error al iniciar sesión. Intente nuevamente.'));
      }
    } catch (_) {
      emit(const AuthError('Error al iniciar sesión. Intente nuevamente.'));
    }
  }

  /// Vuelve al estado [AuthUnauthenticated] para permitir un reintento.
  /// Llamado desde el botón "Reintentar" cuando hay [AuthSinConexion].
  void resetearParaReintentar() {
    emit(const AuthUnauthenticated());
  }

  /// Cierra la sesión activa (CA-4).
  Future<void> logout() async {
    _conectividadSub?.cancel();
    emit(const AuthLoading());
    try {
      await _logoutUseCase();
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthError('Error al cerrar sesión. Intente nuevamente.'));
    }
  }

  @override
  Future<void> close() {
    _conectividadSub?.cancel();
    return super.close();
  }
}
