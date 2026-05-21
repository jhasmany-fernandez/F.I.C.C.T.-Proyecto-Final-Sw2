import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatmapper/core/network/connectivity_monitor.dart';
import 'package:heatmapper/core/wifi/throttling_manager.dart';
import 'package:heatmapper/core/wifi/wifi_scanner.dart';
import 'package:heatmapper/features/captura/domain/entities/nivel_senal.dart';
import 'package:heatmapper/features/captura/domain/entities/punto_medicion.dart';
import 'package:heatmapper/features/captura/domain/entities/resultado_escaneo.dart';
import 'package:heatmapper/features/captura/domain/repositories/captura_repository.dart';
import 'package:heatmapper/features/captura/presentation/cubit/captura_cubit.dart';
import 'package:heatmapper/features/captura/presentation/cubit/captura_state.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockRepo extends Mock implements CapturaRepository {}

class _MockScanner extends Mock implements WifiScanner {}

class _MockThrottling extends Mock implements ThrottlingManager {}

class _MockConnectivity extends Mock implements ConnectivityMonitor {}

// ── Helpers ───────────────────────────────────────────────────────────────────

PuntoMedicion _puntoFake({int id = 1}) => PuntoMedicion(
      id: id,
      planoId: 10,
      posX: 100,
      posY: 200,
      nivel: NivelSenal.verde,
      mediciones: const [],
    );

ResultadoEscaneo _escaneoFake() => const ResultadoEscaneo(
      ssid: 'Red-Test',
      bssid: 'aa:bb:cc:dd:ee:ff',
      rssi: -65,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockRepo repo;
  late _MockScanner scanner;
  late _MockThrottling throttling;
  late _MockConnectivity connectivity;
  late CapturaCubit cubit;

  setUp(() {
    repo = _MockRepo();
    scanner = _MockScanner();
    throttling = _MockThrottling();
    connectivity = _MockConnectivity();
    cubit = CapturaCubit(
      repo: repo,
      scanner: scanner,
      throttling: throttling,
      connectivity: connectivity,
    );
  });

  tearDown(() => cubit.close());

  // ── iniciarSesion ──────────────────────────────────────────────────────────

  group('iniciarSesion', () {
    blocTest<CapturaCubit, CapturaState>(
      'emite CapturaLoading + CapturaActiva con puntos cargados',
      build: () {
        when(() => repo.listarPuntos(10))
            .thenAnswer((_) async => [_puntoFake()]);
        return cubit;
      },
      act: (c) => c.iniciarSesion(10),
      expect: () => [
        isA<CapturaLoading>(),
        isA<CapturaActiva>()
            .having((s) => s.planoId, 'planoId', 10)
            .having((s) => s.puntos.length, 'puntos.length', 1),
      ],
    );

    blocTest<CapturaCubit, CapturaState>(
      'emite CapturaActiva vacía si el repo lanza excepción',
      build: () {
        when(() => repo.listarPuntos(10)).thenThrow(Exception('error'));
        return cubit;
      },
      act: (c) => c.iniciarSesion(10),
      expect: () => [
        isA<CapturaLoading>(),
        isA<CapturaActiva>().having((s) => s.puntos, 'puntos', isEmpty),
      ],
    );
  });

  // ── marcarPunto ────────────────────────────────────────────────────────────

  group('marcarPunto', () {
    setUp(() async {
      when(() => repo.listarPuntos(10)).thenAnswer((_) async => []);
      await cubit.iniciarSesion(10);
    });

    blocTest<CapturaCubit, CapturaState>(
      'flujo exitoso: emite CapturaEnviando → CapturaActiva con nuevo punto',
      build: () => cubit,
      setUp: () {
        when(() => connectivity.estaConectado()).thenAnswer((_) async => true);
        when(() => throttling.puedeEscanear).thenReturn(true);
        when(() => scanner.escanear())
            .thenAnswer((_) async => [_escaneoFake()]);
        when(() => throttling.registrarEscaneo()).thenReturn(null);
        when(() => repo.enviarLote(
              planoId: 10,
              posX: any(named: 'posX'),
              posY: any(named: 'posY'),
              escaneos: any(named: 'escaneos'),
            )).thenAnswer((_) async => _puntoFake(id: 2));
      },
      act: (c) => c.marcarPunto(posX: 100, posY: 200),
      expect: () => [
        isA<CapturaEnviando>(),
        isA<CapturaActiva>()
            .having((s) => s.puntos.length, 'puntos.length', 1)
            .having((s) => s.puntos.first.id, 'punto.id', 2),
      ],
    );

    blocTest<CapturaCubit, CapturaState>(
      'emite CapturaPausada si no hay conectividad',
      build: () => cubit,
      setUp: () {
        when(() => connectivity.estaConectado()).thenAnswer((_) async => false);
      },
      act: (c) => c.marcarPunto(posX: 50, posY: 50),
      expect: () => [isA<CapturaPausada>()],
    );

    blocTest<CapturaCubit, CapturaState>(
      'emite CapturaThrottling si se alcanzó el límite de escaneos',
      build: () => cubit,
      setUp: () {
        when(() => connectivity.estaConectado()).thenAnswer((_) async => true);
        when(() => throttling.puedeEscanear).thenReturn(false);
        when(() => throttling.segundosHastaProximo).thenReturn(45);
      },
      act: (c) => c.marcarPunto(posX: 50, posY: 50),
      expect: () => [
        isA<CapturaThrottling>()
            .having((s) => s.segundosRestantes, 'segundos', 45),
      ],
    );

    blocTest<CapturaCubit, CapturaState>(
      'emite CapturaError si el escaneo WiFi está vacío',
      build: () => cubit,
      setUp: () {
        when(() => connectivity.estaConectado()).thenAnswer((_) async => true);
        when(() => throttling.puedeEscanear).thenReturn(true);
        when(() => scanner.escanear()).thenAnswer((_) async => []);
      },
      act: (c) => c.marcarPunto(posX: 50, posY: 50),
      expect: () => [
        isA<CapturaEnviando>(),
        isA<CapturaError>(),
      ],
    );

    blocTest<CapturaCubit, CapturaState>(
      'emite CapturaError si el backend lanza CapturaApiException',
      build: () => cubit,
      setUp: () {
        when(() => connectivity.estaConectado()).thenAnswer((_) async => true);
        when(() => throttling.puedeEscanear).thenReturn(true);
        when(() => scanner.escanear())
            .thenAnswer((_) async => [_escaneoFake()]);
        when(() => throttling.registrarEscaneo()).thenReturn(null);
        when(() => repo.enviarLote(
              planoId: any(named: 'planoId'),
              posX: any(named: 'posX'),
              posY: any(named: 'posY'),
              escaneos: any(named: 'escaneos'),
            )).thenThrow(
          const CapturaApiException('El plano no está calibrado'),
        );
      },
      act: (c) => c.marcarPunto(posX: 50, posY: 50),
      expect: () => [
        isA<CapturaEnviando>(),
        isA<CapturaError>().having(
          (s) => s.mensaje,
          'mensaje',
          contains('calibrado'),
        ),
      ],
    );
  });

  // ── eliminarPunto ──────────────────────────────────────────────────────────

  group('eliminarPunto', () {
    setUp(() async {
      when(() => repo.listarPuntos(10))
          .thenAnswer((_) async => [_puntoFake(id: 1), _puntoFake(id: 2)]);
      await cubit.iniciarSesion(10);
    });

    blocTest<CapturaCubit, CapturaState>(
      'elimina punto exitosamente y actualiza la lista',
      build: () => cubit,
      setUp: () {
        when(() => repo.eliminarPunto(1)).thenAnswer((_) async {});
      },
      act: (c) => c.eliminarPunto(1),
      expect: () => [
        isA<CapturaActiva>()
            .having((s) => s.puntos.length, 'puntos.length', 1)
            .having((s) => s.puntos.first.id, 'primer punto id', 2),
      ],
    );

    blocTest<CapturaCubit, CapturaState>(
      'emite CapturaError si el backend falla al eliminar',
      build: () => cubit,
      setUp: () {
        when(() => repo.eliminarPunto(99)).thenThrow(
          const CapturaApiException('No encontrado'),
        );
      },
      act: (c) => c.eliminarPunto(99),
      expect: () => [isA<CapturaError>()],
    );
  });

  // ── detenerSesion ──────────────────────────────────────────────────────────

  blocTest<CapturaCubit, CapturaState>(
    'detenerSesion emite CapturaInactiva',
    build: () {
      when(() => repo.listarPuntos(any())).thenAnswer((_) async => []);
      return cubit;
    },
    act: (c) async {
      await c.iniciarSesion(5);
      c.detenerSesion();
    },
    expect: () => [
      isA<CapturaLoading>(),
      isA<CapturaActiva>(),
      isA<CapturaInactiva>(),
    ],
  );

  // ── ThrottlingManager (unit tests) ────────────────────────────────────────

  group('ThrottlingManager', () {
    test('permite escanear cuando no hay registros', () {
      final mgr = ThrottlingManager();
      expect(mgr.puedeEscanear, isTrue);
      expect(mgr.segundosHastaProximo, 0);
    });

    test('bloquea al registrar 4 escaneos', () {
      final mgr = ThrottlingManager();
      for (int i = 0; i < 4; i++) {
        mgr.registrarEscaneo();
      }
      expect(mgr.puedeEscanear, isFalse);
      expect(mgr.segundosHastaProximo, greaterThan(0));
    });
  });
}
