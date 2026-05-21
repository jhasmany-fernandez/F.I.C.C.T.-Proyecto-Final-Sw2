import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'app.dart';
import 'core/network/connectivity_monitor.dart';
import 'core/network/dio_client.dart';
import 'core/navigation/app_router.dart';

// PB-09: Autenticación
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/datasources/session_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/logout_usecase.dart';
import 'features/auth/domain/usecases/get_usuario_activo_usecase.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';

// PB-01: Gestión de proyectos
import 'features/proyectos/data/datasources/proyecto_remote_datasource.dart';
import 'features/proyectos/data/repositories/proyecto_repository_impl.dart';
import 'features/proyectos/domain/repositories/proyecto_repository.dart';
import 'features/proyectos/domain/usecases/obtener_proyectos_activos_usecase.dart';
import 'features/proyectos/domain/usecases/crear_proyecto_usecase.dart';
import 'features/proyectos/domain/usecases/actualizar_proyecto_usecase.dart';
import 'features/proyectos/domain/usecases/archivar_proyecto_usecase.dart';
import 'features/proyectos/domain/usecases/eliminar_proyecto_usecase.dart';
import 'features/proyectos/presentation/bloc/proyecto_cubit.dart';

// PB-19: Selector de clientes
import 'features/clientes/data/datasources/cliente_remote_datasource.dart';

// Sprint 2 — PB-02 / PB-11: Planos y calibración
import 'features/planos/data/datasources/plano_remote_datasource.dart';

// Sprint 3 — PB-03 / PB-04: Captura WiFi y mediciones
import 'core/wifi/throttling_manager.dart';
import 'core/wifi/wifi_scanner.dart';
import 'features/captura/data/datasources/medicion_remote_datasource.dart';
import 'features/captura/data/repositories/captura_repository_impl.dart';
import 'features/captura/domain/repositories/captura_repository.dart';
import 'features/captura/presentation/cubit/captura_cubit.dart';
import 'features/planos/data/repositories/plano_repository_impl.dart';
import 'features/planos/domain/repositories/plano_repository.dart';
import 'features/planos/domain/usecases/plano_usecases.dart';
import 'features/planos/presentation/cubit/planos_cubit.dart';

final GetIt sl = GetIt.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _initDependencias();

  // Sp1-19: cuando el AuthInterceptor detecta que la sesión expiró,
  // redirige al usuario a la pantalla de login.
  DioClient.onSessionExpired = () {
    AppRouter.router.go('/login');
  };

  runApp(const HeatmapperApp());
}

void _initDependencias() {
  // Core: cliente HTTP y sesión ──────────────────────────────────────────────
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  sl.registerLazySingleton<DioClient>(
    () => DioClient(sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton<Dio>(
    () => sl<DioClient>().dio,
  );
  sl.registerLazySingleton<Connectivity>(() => Connectivity());
  sl.registerLazySingleton<ConnectivityMonitor>(
    () => ConnectivityMonitor(sl<Connectivity>()),
  );

  // PB-09: Autenticación ─────────────────────────────────────────────────────
  sl.registerLazySingleton<SessionDatasource>(
    () => SessionDatasource(sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasource(sl<Dio>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDatasource: sl<AuthRemoteDatasource>(),
      sessionDatasource: sl<SessionDatasource>(),
    ),
  );
  sl.registerFactory<LoginUseCase>(
    () => LoginUseCase(sl<AuthRepository>()),
  );
  sl.registerFactory<LogoutUseCase>(
    () => LogoutUseCase(sl<AuthRepository>()),
  );
  sl.registerFactory<GetUsuarioActivoUseCase>(
    () => GetUsuarioActivoUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton<AuthCubit>(
    () => AuthCubit(
      loginUseCase: sl<LoginUseCase>(),
      logoutUseCase: sl<LogoutUseCase>(),
      getUsuarioActivoUseCase: sl<GetUsuarioActivoUseCase>(),
      connectivityMonitor: sl<ConnectivityMonitor>(),
    ),
  );

  // PB-01: Gestión de proyectos ──────────────────────────────────────────────
  sl.registerLazySingleton<ProyectoRemoteDatasource>(
    () => ProyectoRemoteDatasource(sl<Dio>()),
  );
  sl.registerLazySingleton<ProyectoRepository>(
    () => ProyectoRepositoryImpl(sl<ProyectoRemoteDatasource>()),
  );
  sl.registerFactory<ObtenerProyectosActivosUseCase>(
    () => ObtenerProyectosActivosUseCase(sl<ProyectoRepository>()),
  );
  sl.registerFactory<CrearProyectoUseCase>(
    () => CrearProyectoUseCase(sl<ProyectoRepository>()),
  );
  sl.registerFactory<ActualizarProyectoUseCase>(
    () => ActualizarProyectoUseCase(sl<ProyectoRepository>()),
  );
  sl.registerFactory<ArchivarProyectoUseCase>(
    () => ArchivarProyectoUseCase(sl<ProyectoRepository>()),
  );
  sl.registerFactory<EliminarProyectoUseCase>(
    () => EliminarProyectoUseCase(sl<ProyectoRepository>()),
  );
  sl.registerFactory<ProyectoCubit>(
    () => ProyectoCubit(
      obtenerActivos: sl<ObtenerProyectosActivosUseCase>(),
      crear: sl<CrearProyectoUseCase>(),
      actualizar: sl<ActualizarProyectoUseCase>(),
      archivar: sl<ArchivarProyectoUseCase>(),
      eliminar: sl<EliminarProyectoUseCase>(),
    ),
  );

  // PB-19: Selector de clientes ──────────────────────────────────────────────
  sl.registerLazySingleton<ClienteRemoteDatasource>(
    () => ClienteRemoteDatasource(sl<Dio>()),
  );

  // Sprint 2 — PB-02 / PB-11: Planos y calibración ─────────────────────────
  sl.registerLazySingleton<PlanoRemoteDatasource>(
    () => PlanoRemoteDatasource(sl<Dio>()),
  );
  sl.registerLazySingleton<PlanoRepository>(
    () => PlanoRepositoryImpl(sl<PlanoRemoteDatasource>()),
  );
  sl.registerFactory<ListarPlanosUseCase>(
    () => ListarPlanosUseCase(sl<PlanoRepository>()),
  );
  sl.registerFactory<ImportarPlanoUseCase>(
    () => ImportarPlanoUseCase(sl<PlanoRepository>()),
  );
  sl.registerFactory<CalibrarPlanoUseCase>(
    () => CalibrarPlanoUseCase(sl<PlanoRepository>()),
  );
  sl.registerFactory<EliminarPlanoUseCase>(
    () => EliminarPlanoUseCase(sl<PlanoRepository>()),
  );
  sl.registerFactory<RenovarUrlFirmadaUseCase>(
    () => RenovarUrlFirmadaUseCase(sl<PlanoRepository>()),
  );
  sl.registerFactory<PlanosCubit>(
    () => PlanosCubit(
      listar: sl<ListarPlanosUseCase>(),
      importar: sl<ImportarPlanoUseCase>(),
      calibrar: sl<CalibrarPlanoUseCase>(),
      eliminar: sl<EliminarPlanoUseCase>(),
    ),
  );

  // Sprint 3 — PB-03 / PB-04: Captura WiFi y mediciones ─────────────────────
  sl.registerLazySingleton<WifiScanner>(() => const WifiScanner());
  sl.registerLazySingleton<ThrottlingManager>(() => ThrottlingManager());
  sl.registerLazySingleton<MedicionRemoteDatasource>(
    () => MedicionRemoteDatasource(sl<Dio>()),
  );
  sl.registerLazySingleton<CapturaRepository>(
    () => CapturaRepositoryImpl(sl<MedicionRemoteDatasource>()),
  );
  sl.registerFactory<CapturaCubit>(
    () => CapturaCubit(
      repo: sl<CapturaRepository>(),
      scanner: sl<WifiScanner>(),
      throttling: sl<ThrottlingManager>(),
      connectivity: sl<ConnectivityMonitor>(),
    ),
  );
}
