import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:heatmapper/core/network/connectivity_monitor.dart';
import 'package:heatmapper/features/auth/domain/entities/usuario.dart';
import 'package:heatmapper/features/auth/domain/repositories/auth_repository.dart';
import 'package:heatmapper/features/auth/domain/usecases/login_usecase.dart';
import 'package:heatmapper/features/auth/domain/usecases/logout_usecase.dart';
import 'package:heatmapper/features/auth/domain/usecases/get_usuario_activo_usecase.dart';
import 'package:heatmapper/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:heatmapper/features/auth/presentation/bloc/auth_state.dart';

// Mocks ──────────────────────────────────────────────────────────────────────
class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockGetUsuarioActivoUseCase extends Mock
    implements GetUsuarioActivoUseCase {}

class MockConnectivityMonitor extends Mock implements ConnectivityMonitor {}

// Helpers ────────────────────────────────────────────────────────────────────
const _usuario = Usuario(
  id: 1,
  nombre: 'Técnico Prueba',
  email: 'tecnico@bulldogtech.bo',
);

AuthCubit _buildCubit({
  required MockLoginUseCase login,
  required MockLogoutUseCase logout,
  required MockGetUsuarioActivoUseCase getActivo,
  required MockConnectivityMonitor connectivity,
}) {
  return AuthCubit(
    loginUseCase: login,
    logoutUseCase: logout,
    getUsuarioActivoUseCase: getActivo,
    connectivityMonitor: connectivity,
  );
}

void main() {
  late MockLoginUseCase mockLogin;
  late MockLogoutUseCase mockLogout;
  late MockGetUsuarioActivoUseCase mockGetActivo;
  late MockConnectivityMonitor mockConnectivity;

  setUp(() {
    mockLogin = MockLoginUseCase();
    mockLogout = MockLogoutUseCase();
    mockGetActivo = MockGetUsuarioActivoUseCase();
    mockConnectivity = MockConnectivityMonitor();
    // Valor por defecto: con conexión, stream vacío
    when(() => mockConnectivity.estaConectado()).thenAnswer((_) async => true);
    when(() => mockConnectivity.cambios)
        .thenAnswer((_) => const Stream.empty());
  });

  // ── checkSesionActiva ────────────────────────────────────────────────────
  group('checkSesionActiva', () {
    blocTest<AuthCubit, AuthState>(
      'emite [AuthLoading, AuthAuthenticated] cuando hay sesión activa',
      build: () {
        when(() => mockGetActivo()).thenAnswer((_) async => _usuario);
        return _buildCubit(
          login: mockLogin,
          logout: mockLogout,
          getActivo: mockGetActivo,
          connectivity: mockConnectivity,
        );
      },
      act: (cubit) => cubit.checkSesionActiva(),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(_usuario),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emite [AuthLoading, AuthUnauthenticated] cuando no hay sesión y hay conexión',
      build: () {
        when(() => mockGetActivo()).thenAnswer((_) async => null);
        return _buildCubit(
          login: mockLogin,
          logout: mockLogout,
          getActivo: mockGetActivo,
          connectivity: mockConnectivity,
        );
      },
      act: (cubit) => cubit.checkSesionActiva(),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emite [AuthLoading, AuthSinConexion] cuando no hay sesión y no hay conexión (CA-5)',
      build: () {
        when(() => mockGetActivo()).thenAnswer((_) async => null);
        when(() => mockConnectivity.estaConectado())
            .thenAnswer((_) async => false);
        return _buildCubit(
          login: mockLogin,
          logout: mockLogout,
          getActivo: mockGetActivo,
          connectivity: mockConnectivity,
        );
      },
      act: (cubit) => cubit.checkSesionActiva(),
      expect: () => [
        const AuthLoading(),
        const AuthSinConexion(),
      ],
    );
  });

  // ── login ────────────────────────────────────────────────────────────────
  group('login', () {
    blocTest<AuthCubit, AuthState>(
      'emite [AuthLoading, AuthAuthenticated] con credenciales correctas (CA-1)',
      build: () {
        when(() => mockLogin(any(), any())).thenAnswer((_) async => _usuario);
        return _buildCubit(
          login: mockLogin,
          logout: mockLogout,
          getActivo: mockGetActivo,
          connectivity: mockConnectivity,
        );
      },
      act: (cubit) => cubit.login('tecnico@bulldogtech.bo', 'pass123'),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(_usuario),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emite [AuthLoading, AuthError] con credenciales incorrectas (CA-2)',
      build: () {
        when(() => mockLogin(any(), any()))
            .thenThrow(const CredencialesInvalidasException());
        return _buildCubit(
          login: mockLogin,
          logout: mockLogout,
          getActivo: mockGetActivo,
          connectivity: mockConnectivity,
        );
      },
      act: (cubit) => cubit.login('tecnico@bulldogtech.bo', 'mal_pass'),
      expect: () => [
        const AuthLoading(),
        const AuthError('Credenciales inválidas'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emite [AuthLoading, AuthError] con cuenta desactivada (CA-3)',
      build: () {
        when(() => mockLogin(any(), any()))
            .thenThrow(const CuentaDesactivadaException());
        return _buildCubit(
          login: mockLogin,
          logout: mockLogout,
          getActivo: mockGetActivo,
          connectivity: mockConnectivity,
        );
      },
      act: (cubit) => cubit.login('tecnico@bulldogtech.bo', 'pass123'),
      expect: () => [
        const AuthLoading(),
        const AuthError('Cuenta desactivada. Contacte al administrador.'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emite [AuthSinConexion] sin llamar al backend cuando no hay red (CA-5)',
      build: () {
        when(() => mockConnectivity.estaConectado())
            .thenAnswer((_) async => false);
        return _buildCubit(
          login: mockLogin,
          logout: mockLogout,
          getActivo: mockGetActivo,
          connectivity: mockConnectivity,
        );
      },
      act: (cubit) => cubit.login('tecnico@bulldogtech.bo', 'pass123'),
      expect: () => [const AuthSinConexion()],
      verify: (_) => verifyNever(() => mockLogin(any(), any())),
    );

    blocTest<AuthCubit, AuthState>(
      'emite [AuthLoading, AuthError] ante excepción inesperada',
      build: () {
        when(() => mockLogin(any(), any()))
            .thenThrow(Exception('fallo de red'));
        return _buildCubit(
          login: mockLogin,
          logout: mockLogout,
          getActivo: mockGetActivo,
          connectivity: mockConnectivity,
        );
      },
      act: (cubit) => cubit.login('tecnico@bulldogtech.bo', 'pass'),
      expect: () => [
        const AuthLoading(),
        const AuthError('Error al iniciar sesión. Intente nuevamente.'),
      ],
    );
  });

  // ── logout ───────────────────────────────────────────────────────────────
  group('logout', () {
    blocTest<AuthCubit, AuthState>(
      'emite [AuthLoading, AuthUnauthenticated] al cerrar sesión (CA-4)',
      build: () {
        when(() => mockLogout()).thenAnswer((_) async {});
        return _buildCubit(
          login: mockLogin,
          logout: mockLogout,
          getActivo: mockGetActivo,
          connectivity: mockConnectivity,
        );
      },
      act: (cubit) => cubit.logout(),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
    );
  });

  // ── resetearParaReintentar ────────────────────────────────────────────────
  group('resetearParaReintentar', () {
    blocTest<AuthCubit, AuthState>(
      'emite [AuthUnauthenticated] al reintentar desde estado sin conexión',
      build: () => _buildCubit(
        login: mockLogin,
        logout: mockLogout,
        getActivo: mockGetActivo,
        connectivity: mockConnectivity,
      ),
      seed: () => const AuthSinConexion(),
      act: (cubit) => cubit.resetearParaReintentar(),
      expect: () => [const AuthUnauthenticated()],
    );
  });
}
