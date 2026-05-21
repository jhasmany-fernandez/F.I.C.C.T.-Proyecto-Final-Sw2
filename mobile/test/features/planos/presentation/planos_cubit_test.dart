import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatmapper/features/planos/domain/entities/plano.dart';
import 'package:heatmapper/features/planos/domain/repositories/plano_repository.dart';
import 'package:heatmapper/features/planos/domain/usecases/plano_usecases.dart';
import 'package:heatmapper/features/planos/presentation/cubit/planos_cubit.dart';
import 'package:heatmapper/features/planos/presentation/cubit/planos_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PlanoRepository {}

Plano _planoFake({int id = 1, bool calibrado = false}) {
  return Plano(
    id: id,
    proyectoId: 10,
    nombre: 'Plano $id',
    formato: FormatoPlano.png,
    anchoPx: 1000,
    altoPx: 800,
    tamanoBytes: 1024,
    urlFirmada: '/planos/archivo/x.png?exp=1&sig=a',
    calibrado: calibrado,
    escalaMPorPx: calibrado ? 0.05 : null,
    distanciaRealM: calibrado ? 5.0 : null,
    calibracionX1: calibrado ? 0.0 : null,
    calibracionY1: calibrado ? 0.0 : null,
    calibracionX2: calibrado ? 100.0 : null,
    calibracionY2: calibrado ? 0.0 : null,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

void main() {
  late _MockRepo repo;
  late PlanosCubit cubit;

  setUp(() {
    repo = _MockRepo();
    cubit = PlanosCubit(
      listar: ListarPlanosUseCase(repo),
      importar: ImportarPlanoUseCase(repo),
      calibrar: CalibrarPlanoUseCase(repo),
      eliminar: EliminarPlanoUseCase(repo),
    );
  });

  tearDown(() => cubit.close());

  group('cargarPlanos', () {
    blocTest<PlanosCubit, PlanosState>(
      'emite Loading + ListaExitosa cuando el repo responde OK',
      build: () {
        when(() => repo.listar(10))
            .thenAnswer((_) async => [_planoFake(id: 1)]);
        return cubit;
      },
      act: (c) => c.cargarPlanos(10),
      expect: () => [
        isA<PlanosLoading>(),
        isA<PlanosListaExitosa>().having(
          (s) => s.planos.length,
          'planos.length',
          1,
        ),
      ],
    );

    blocTest<PlanosCubit, PlanosState>(
      'emite Error si el repo lanza',
      build: () {
        when(() => repo.listar(10)).thenThrow(Exception('boom'));
        return cubit;
      },
      act: (c) => c.cargarPlanos(10),
      expect: () => [
        isA<PlanosLoading>(),
        isA<PlanosError>(),
      ],
    );
  });

  group('calibrarPlano', () {
    blocTest<PlanosCubit, PlanosState>(
      'mapea PlanoDistanciaInvalidaException a PlanosError',
      build: () {
        when(() => repo.calibrar(
              planoId: any(named: 'planoId'),
              x1: any(named: 'x1'),
              y1: any(named: 'y1'),
              x2: any(named: 'x2'),
              y2: any(named: 'y2'),
              distanciaRealM: any(named: 'distanciaRealM'),
            )).thenThrow(const PlanoDistanciaInvalidaException());
        return cubit;
      },
      seed: () => PlanosListaExitosa([_planoFake(id: 5)]),
      act: (c) => c.calibrarPlano(
        planoId: 5,
        x1: 0, y1: 0,
        x2: 100, y2: 0,
        distanciaRealM: 0.5,
      ),
      expect: () => [
        isA<PlanosLoading>(),
        isA<PlanosError>().having(
          (e) => e.mensaje.toLowerCase(),
          'mensaje',
          contains('1 metro'),
        ),
      ],
    );

    blocTest<PlanosCubit, PlanosState>(
      'mapea PlanoPuntosInvalidosException a PlanosError',
      build: () {
        when(() => repo.calibrar(
              planoId: any(named: 'planoId'),
              x1: any(named: 'x1'),
              y1: any(named: 'y1'),
              x2: any(named: 'x2'),
              y2: any(named: 'y2'),
              distanciaRealM: any(named: 'distanciaRealM'),
            )).thenThrow(const PlanoPuntosInvalidosException());
        return cubit;
      },
      seed: () => PlanosListaExitosa([_planoFake(id: 5)]),
      act: (c) => c.calibrarPlano(
        planoId: 5,
        x1: 50, y1: 50,
        x2: 50, y2: 50,
        distanciaRealM: 5,
      ),
      expect: () => [
        isA<PlanosLoading>(),
        isA<PlanosError>(),
      ],
    );
  });
}
