import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:heatmapper/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:heatmapper/features/auth/data/datasources/session_datasource.dart';
import 'package:heatmapper/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:heatmapper/features/auth/data/models/usuario_model.dart';
import 'package:heatmapper/features/auth/data/models/login_response_model.dart';
import 'package:heatmapper/features/auth/domain/entities/usuario.dart';
import 'package:heatmapper/features/auth/domain/repositories/auth_repository.dart';

// Mocks ─────────────────────────────────────────────────────────────────────
class MockAuthRemoteDatasource extends Mock implements AuthRemoteDatasource {}

class MockSessionDatasource extends Mock implements SessionDatasource {}

// Helpers ────────────────────────────────────────────────────────────────────
const _usuarioModel = UsuarioModel(
  id: 1,
  nombre: 'Técnico Prueba',
  email: 'tecnico@bulldogtech.bo',
);

const _loginResponse = LoginResponseModel(
  accessToken: 'token_prueba',
  refreshToken: 'refresh_token_prueba',
  tokenType: 'bearer',
  usuario: _usuarioModel,
);

void main() {
  late AuthRepositoryImpl repositorio;
  late MockAuthRemoteDatasource mockRemote;
  late MockSessionDatasource mockSession;

  setUpAll(() {
    registerFallbackValue(const Usuario(id: 0, nombre: '', email: ''));
  });

  setUp(() {
    mockRemote = MockAuthRemoteDatasource();
    mockSession = MockSessionDatasource();
    repositorio = AuthRepositoryImpl(
      remoteDatasource: mockRemote,
      sessionDatasource: mockSession,
    );
  });

  // ── login ──────────────────────────────────────────────────────────────────
  group('login', () {
    test('retorna Usuario cuando las credenciales son correctas', () async {
      when(() => mockRemote.login(any(), any()))
          .thenAnswer((_) async => _loginResponse);
      when(() => mockSession.guardarSesion(any(), any(), any()))
          .thenAnswer((_) async {});

      final usuario = await repositorio.login(
        'tecnico@bulldogtech.bo',
        'contraseña123',
      );

      expect(usuario.id, 1);
      expect(usuario.email, 'tecnico@bulldogtech.bo');
      verify(() => mockSession.guardarSesion(
          'token_prueba', 'refresh_token_prueba', any())).called(1);
    });

    test(
        'lanza CredencialesInvalidasException cuando las credenciales son incorrectas',
        () async {
      when(() => mockRemote.login(any(), any()))
          .thenThrow(const CredencialesInvalidasException());

      expect(
        () => repositorio.login('tecnico@bulldogtech.bo', 'mal_password'),
        throwsA(isA<CredencialesInvalidasException>()),
      );
      verifyNever(() => mockSession.guardarSesion(any(), any(), any()));
    });

    test(
        'lanza AuthStorageException cuando el datasource lanza una excepción inesperada',
        () async {
      when(() => mockRemote.login(any(), any()))
          .thenThrow(Exception('fallo de red'));

      expect(
        () => repositorio.login('tecnico@bulldogtech.bo', 'pass'),
        throwsA(isA<AuthStorageException>()),
      );
    });
  });

  // ── logout ─────────────────────────────────────────────────────────────────
  group('logout', () {
    test('limpia la sesión correctamente', () async {
      when(() => mockSession.limpiarSesion()).thenAnswer((_) async {});

      await repositorio.logout();

      verify(() => mockSession.limpiarSesion()).called(1);
    });
  });

  // ── getUsuarioActivo ────────────────────────────────────────────────────────
  group('getUsuarioActivo', () {
    test('retorna Usuario cuando hay sesión persistida', () async {
      when(() => mockSession.obtenerToken())
          .thenAnswer((_) async => 'token_prueba');
      when(() => mockSession.obtenerUsuario())
          .thenAnswer((_) async => _usuarioModel.toDomain());

      final usuario = await repositorio.getUsuarioActivo();

      expect(usuario, isNotNull);
      expect(usuario!.id, 1);
    });

    test('retorna null cuando no hay sesión', () async {
      when(() => mockSession.obtenerUsuario()).thenAnswer((_) async => null);

      final usuario = await repositorio.getUsuarioActivo();

      expect(usuario, isNull);
    });
  });
}
