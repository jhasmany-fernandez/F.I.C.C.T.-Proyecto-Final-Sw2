import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:heatmapper/features/auth/domain/entities/usuario.dart';
import 'package:heatmapper/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:heatmapper/features/auth/presentation/bloc/auth_state.dart';
import 'package:heatmapper/features/auth/presentation/pages/login_page.dart';

// Mock ───────────────────────────────────────────────────────────────────────
class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

// Helpers ────────────────────────────────────────────────────────────────────
const _usuario = Usuario(
  id: 1,
  nombre: 'Técnico Prueba',
  email: 'tecnico@bulldogtech.bo',
);

Widget _buildSujeto(MockAuthCubit cubit) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => BlocProvider<AuthCubit>.value(
            value: cubit,
            child: const LoginPage(),
          ),
        ),
        GoRoute(
          path: '/proyectos',
          builder: (_, __) => const Scaffold(body: Text('Mis Proyectos')),
        ),
      ],
    ),
  );
}

void main() {
  late MockAuthCubit mockCubit;

  setUp(() {
    mockCubit = MockAuthCubit();
    // Estado por defecto: no autenticado, métodos stub vacíos
    when(() => mockCubit.state).thenReturn(const AuthUnauthenticated());
    when(() => mockCubit.login(any(), any())).thenAnswer((_) async {});
    when(() => mockCubit.resetearParaReintentar()).thenReturn(null);
    when(() => mockCubit.checkSesionActiva()).thenAnswer((_) async {});
  });

  // ── Renderizado inicial ──────────────────────────────────────────────────
  testWidgets('muestra campos correo, contraseña y botón Iniciar sesión',
      (tester) async {
    await tester.pumpWidget(_buildSujeto(mockCubit));

    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.byType(FormBuilderTextField), findsNWidgets(2));
  });

  // ── Estado AuthLoading ───────────────────────────────────────────────────
  testWidgets(
      'muestra indicador de carga y deshabilita el botón en AuthLoading',
      (tester) async {
    when(() => mockCubit.state).thenReturn(const AuthLoading());

    await tester.pumpWidget(_buildSujeto(mockCubit));

    // El botón FilledButton existe pero está deshabilitado (onPressed == null)
    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);
    // Muestra indicador circular
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── Estado AuthSinConexion ───────────────────────────────────────────────
  testWidgets(
      'muestra banner de sin conexión y botón Reintentar en AuthSinConexion (CA-5)',
      (tester) async {
    when(() => mockCubit.state).thenReturn(const AuthSinConexion());

    await tester.pumpWidget(_buildSujeto(mockCubit));

    expect(find.text('Sin conexión. Verifique su conexión a internet.'),
        findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    // El botón de login no aparece en este estado
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets(
      'botón Reintentar llama a resetearParaReintentar en AuthSinConexion',
      (tester) async {
    when(() => mockCubit.state).thenReturn(const AuthSinConexion());

    await tester.pumpWidget(_buildSujeto(mockCubit));
    await tester.tap(find.text('Reintentar'));

    verify(() => mockCubit.resetearParaReintentar()).called(1);
  });

  // ── Estado AuthError ─────────────────────────────────────────────────────
  testWidgets('muestra SnackBar con mensaje de error en AuthError (CA-2)',
      (tester) async {
    whenListen(
      mockCubit,
      Stream.value(const AuthError('Credenciales inválidas')),
      initialState: const AuthUnauthenticated(),
    );

    await tester.pumpWidget(_buildSujeto(mockCubit));
    await tester.pumpAndSettle();

    expect(find.text('Credenciales inválidas'), findsOneWidget);
  });

  // ── Estado AuthAuthenticated ─────────────────────────────────────────────
  testWidgets('navega a /proyectos al autenticar correctamente (CA-1)',
      (tester) async {
    whenListen(
      mockCubit,
      Stream.value(const AuthAuthenticated(_usuario)),
      initialState: const AuthUnauthenticated(),
    );

    await tester.pumpWidget(_buildSujeto(mockCubit));
    await tester.pumpAndSettle();

    expect(find.text('Mis Proyectos'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  // ── Validación del formulario ─────────────────────────────────────────────
  testWidgets('muestra errores de validación si el formulario está vacío',
      (tester) async {
    await tester.pumpWidget(_buildSujeto(mockCubit));

    // Pulsar el botón sin completar los campos
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Ingrese su correo electrónico'), findsOneWidget);
    expect(find.text('Ingrese su contraseña'), findsOneWidget);
    // No se llama a login si la validación falla
    verifyNever(() => mockCubit.login(any(), any()));
  });

  testWidgets('muestra error de validación para correo inválido',
      (tester) async {
    await tester.pumpWidget(_buildSujeto(mockCubit));

    await tester.enterText(
        find.byType(FormBuilderTextField).first, 'no_es_correo');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Ingrese un correo electrónico válido'), findsOneWidget);
  });

  testWidgets('llama a login con credenciales al enviar el formulario válido',
      (tester) async {
    await tester.pumpWidget(_buildSujeto(mockCubit));

    final campos = find.byType(FormBuilderTextField);
    await tester.enterText(campos.first, 'tecnico@bulldogtech.bo');
    await tester.enterText(campos.last, 'pass1234');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    verify(() => mockCubit.login('tecnico@bulldogtech.bo', 'pass1234'))
        .called(1);
  });
}
