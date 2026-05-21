import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/captura/presentation/cubit/captura_cubit.dart';
import '../../features/captura/presentation/pages/captura_page.dart';
import '../../features/planos/domain/entities/plano.dart';
import '../../features/planos/presentation/cubit/planos_cubit.dart';
import '../../features/planos/presentation/pages/plano_editor_page.dart';
import '../../features/planos/presentation/pages/planos_list_page.dart';
import '../../features/proyectos/presentation/bloc/proyecto_cubit.dart';
import '../../features/proyectos/presentation/pages/proyectos_page.dart';
import '../../features/proyectos/presentation/pages/proyecto_form_page.dart';
import '../../main.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, routerState) async {
      // CA-3: si ya hay sesión activa, redirigir a /proyectos desde /login.
      // Se evalúa sólo en AuthAuthenticated para evitar loops.
      final authCubit = sl<AuthCubit>();
      if (authCubit.state is AuthAuthenticated &&
          routerState.matchedLocation == '/login') {
        return '/proyectos';
      }
      return null;
    },
    routes: [
      // Splash: muestra branding mientras se valida sesión persistida (CA-3).
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) {
          return BlocProvider<AuthCubit>.value(
            value: sl<AuthCubit>(),
            child: const SplashPage(),
          );
        },
      ),
      // Sprint 1: PB-09 — Autenticar Usuario (Sp-05)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) {
          return BlocProvider<AuthCubit>.value(
            value: sl<AuthCubit>(),
            child: const LoginPage(),
          );
        },
      ),
      // Sprint 1: PB-01 / PB-10 — Gestionar y Ver Proyectos (Sp-13)
      GoRoute(
        path: '/proyectos',
        name: 'proyectos',
        builder: (context, state) {
          return BlocProvider<ProyectoCubit>(
            create: (_) => sl<ProyectoCubit>(),
            child: const ProyectosPage(),
          );
        },
        routes: [
          // Crear nuevo proyecto (Sp-13)
          GoRoute(
            path: 'nuevo',
            name: 'proyecto-nuevo',
            builder: (context, state) {
              final cubit = state.extra as ProyectoCubit;
              return BlocProvider<ProyectoCubit>.value(
                value: cubit,
                child: const ProyectoFormPage(),
              );
            },
          ),
          // Editar proyecto existente (Sp-13)
          GoRoute(
            path: ':id/editar',
            name: 'proyecto-editar',
            builder: (context, routeState) {
              // extra: Map con 'cubit' y 'proyecto'.
              final extra = routeState.extra as Map<String, dynamic>;
              final cubit = extra['cubit'] as ProyectoCubit;
              return BlocProvider<ProyectoCubit>.value(
                value: cubit,
                child: ProyectoFormPage(
                  proyectoExistente: extra['proyecto'] as dynamic,
                ),
              );
            },
          ),
          // Sprint 2: PB-02 — Importar Planos. Lista de planos del proyecto.
          GoRoute(
            path: ':id',
            name: 'proyecto-detalle',
            builder: (context, routeState) {
              final id =
                  int.tryParse(routeState.pathParameters['id'] ?? '') ?? 0;
              final extra = routeState.extra;
              String? nombre;
              if (extra is Map) {
                nombre = extra['proyectoNombre'] as String?;
              }
              return BlocProvider<PlanosCubit>(
                create: (_) => sl<PlanosCubit>(),
                child: PlanosListPage(
                  proyectoId: id,
                  proyectoNombre: nombre,
                ),
              );
            },
            routes: [
              // Sprint 2: PB-11 — Editor / Calibrar Escala.
              GoRoute(
                path: 'planos/:planoId',
                name: 'plano-editor',
                builder: (context, routeState) {
                  final extra = routeState.extra as Map<String, dynamic>;
                  final cubit = extra['cubit'] as PlanosCubit;
                  final plano = extra['plano'] as Plano;
                  return BlocProvider<PlanosCubit>.value(
                    value: cubit,
                    child: PlanoEditorPage(plano: plano),
                  );
                },
                routes: [
                  // Sprint 3: PB-03 / PB-04 — Captura WiFi sobre plano.
                  GoRoute(
                    path: 'captura',
                    name: 'captura',
                    builder: (context, routeState) {
                      final extra = routeState.extra as Map<String, dynamic>;
                      return BlocProvider<CapturaCubit>(
                        create: (_) => sl<CapturaCubit>(),
                        child: CapturaPage(
                          planoId: extra['planoId'] as int,
                          imagenUrl: extra['imagenUrl'] as String,
                          anchoPlanoPx:
                              (extra['anchoPlanoPx'] as num).toDouble(),
                          altoPlanoPx: (extra['altoPlanoPx'] as num).toDouble(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
